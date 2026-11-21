"""Read-only account checks for support; never infer receipts from plan selection."""

import base64
import hashlib
import hmac
import json
from collections import Counter
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

import httpx
from fastapi import APIRouter, HTTPException, Path, Query
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _admin_client, _list_auth_users, _parse_datetime, _require_admin
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.admin.user_reports import countries, moderation
from packages.shared.auth_context import get_access_token

router = APIRouter(prefix="/admin/users", tags=["admin"])


def _account(user: Any, row: dict[str, Any] | None, now: datetime) -> dict[str, Any]:
    container = get_container()
    email = str(getattr(user, "email", "") or "")
    developer = email.strip().lower() in container.developer_emails
    subscription = Subscription.model_validate(row) if row else None
    stored_plan = subscription.plan if subscription else None
    test_plan = container.subscription_test_plan
    banned_until = _parse_datetime(getattr(user, "banned_until", None))
    if developer:
        access = "developer"
    elif test_plan:
        access = "test"
    elif subscription is None:
        access = "not_started"
    elif stored_plan:
        access = "plan"
    elif subscription.is_trial_active(now=now):
        access = "trial"
    else:
        access = "expired"
    return {
        "id": str(user.id),
        "email": email or None,
        "created_at": getattr(user, "created_at", None),
        "last_sign_in_at": getattr(user, "last_sign_in_at", None),
        "email_verified": getattr(user, "email_confirmed_at", None) is not None,
        "banned_until": banned_until if banned_until and banned_until > now else None,
        "stored_plan": stored_plan,
        "effective_plan": test_plan or stored_plan,
        "access": access,
        "trial_ends_at": subscription.trial_ends_at if subscription else None,
        "subscription_created_at": subscription.created_at if subscription else None,
        # No payment ledger/provider exists in the current subscription model.
        "total_paid_minor": None,
        "currency": None,
        "last_payment_at": None,
        "location": None,
    }


@router.get("")
def list_users(
    q: str = Query(default="", max_length=200),
    page: int = Query(default=1, ge=1, le=2000),
    page_size: int = Query(default=50, ge=1, le=100),
    country: str = Query(default="", pattern=r"^(|unknown|[A-Z]{2})$"),
) -> dict[str, Any]:
    _require_admin()
    try:
        client = _admin_client()
        users = _list_auth_users(client)
        locations = countries(client)
        needle = q.strip().casefold()
        if needle:
            users = [
                user
                for user in users
                if needle in str(getattr(user, "email", "") or "").casefold()
                or needle in str(user.id).casefold()
            ]
        country_counts = Counter(
            locations.get(str(user.id), {}).get("country_code") or "unknown" for user in users
        )
        if country:
            users = [
                user
                for user in users
                if (locations.get(str(user.id), {}).get("country_code") or "unknown") == country
            ]
        users.sort(
            key=lambda user: (
                _parse_datetime(getattr(user, "created_at", None))
                or datetime.min.replace(tzinfo=UTC),
                str(user.id),
            ),
            reverse=True,
        )
        total = len(users)
        page = min(page, max(1, (total + page_size - 1) // page_size))
        selected = users[(page - 1) * page_size : page * page_size]
        subscriptions = {}
        if selected:
            response = (
                client.table("subscriptions")
                .select("owner_id,plan,trial_ends_at,created_at")
                .in_("owner_id", [str(user.id) for user in selected])
                .execute()
            )
            subscriptions = {str(row["owner_id"]): row for row in response.data}
        now = datetime.now(UTC)
        return {
            "users": [
                {
                    **_account(user, subscriptions.get(str(user.id)), now),
                    "location": locations.get(str(user.id)),
                }
                for user in selected
            ],
            "total": total,
            "page": page,
            "page_size": page_size,
            "test_plan": get_container().subscription_test_plan,
            "payments_available": False,
            "countries": dict(sorted(country_counts.items())),
        }
    except HTTPException:
        raise
    except Exception:
        # Provider exceptions can contain personal data or connection details.
        raise HTTPException(status_code=503, detail="User data is not available") from None


def auth_user(client: Any, owner_id: str) -> Any:
    try:
        response = client.auth.admin.get_user_by_id(owner_id)
    except Exception as exc:
        if getattr(exc, "status", None) == 404:
            raise HTTPException(status_code=404, detail="Account not found") from None
        raise
    user = getattr(response, "user", None)
    if user is None or str(user.id) != owner_id:
        raise HTTPException(status_code=404, detail="Account not found")
    return user


@router.get("/{owner_id}")
def user_detail(
    owner_id: str = Path(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$"),
) -> dict[str, Any]:
    _require_admin()
    try:
        client = _admin_client()
        user = auth_user(client, owner_id)
        subscription = (
            client.table("subscriptions")
            .select("owner_id,plan,trial_ends_at,created_at")
            .eq("owner_id", owner_id)
            .limit(1)
            .execute()
            .data
            or []
        )
        now = datetime.now(UTC)
        result: dict[str, Any] = {
            "user": _account(user, subscription[0] if subscription else None, now)
        }
        # Independent sections fail visibly; a missing ledger must never read as zero usage.
        sections = {
            "usage": lambda: (
                client.rpc("admin_user_usage", {"p_owner_id": owner_id}).execute().data
            ),
            "devices": lambda: (
                client.table("user_devices")
                .select("device_id,first_seen_at,last_seen_at,revoked_at")
                .eq("owner_id", owner_id)
                .order("last_seen_at", desc=True)
                .limit(100)
                .execute()
                .data
            ),
            "logins": lambda: (
                client.table("user_login_events")
                .select("occurred_at")
                .eq("owner_id", owner_id)
                .gte("occurred_at", (now - timedelta(days=90)).isoformat())
                .order("occurred_at", desc=True)
                .limit(100)
                .execute()
                .data
            ),
            "actions": lambda: (
                client.table("admin_user_actions")
                .select(
                    "id,admin_id,action,reason,note,case_queue,case_id,expires_at,changed,created_at"
                )
                .eq("owner_id", owner_id)
                .gte("created_at", (now - timedelta(days=365)).isoformat())
                .order("created_at", desc=True)
                .limit(100)
                .execute()
                .data
            ),
            "moderation": lambda: moderation(client, owner_id),
            "location": lambda: (
                client.table("user_locations")
                .select(
                    "home_country_code,home_city,home_saved_at,current_source,current_captured_at"
                )
                .eq("owner_id", owner_id)
                .limit(1)
                .execute()
                .data
            ),
            "restriction": lambda: (
                client.table("marketplace_user_restrictions")
                .select(
                    "reason,note,created_at,expires_at,lifted_at,created_by_admin_id,lifted_by_admin_id"
                )
                .eq("owner_id", owner_id)
                .limit(1)
                .execute()
                .data
            ),
        }
        unavailable = []
        for key, read in sections.items():
            try:
                result[key] = read()
            except Exception:
                result[key] = None
                unavailable.append(key)
        result["unavailable"] = unavailable
        return result
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=503, detail="User data is not available") from None


class PlanChangeRequest(BaseModel):
    plan: Literal["plus", "pro", "ultra"] | None
    totp_code: str = Field(min_length=6, max_length=6, pattern=r"^[0-9]{6}$")


def _verify_plan_totp(admin_id: str, code: str) -> str:
    """Step-up via Supabase Auth: require a VERIFIED TOTP factor for this admin.

    Each invocation creates and verifies a fresh challenge. The upgraded JWT is
    inspected only after it comes from Supabase over TLS. It is never persisted.
    Return a keyed HMAC, not the TOTP code, for replay protection in Postgres.
    """
    token = get_access_token()
    settings = get_container().settings
    if not token:
        raise HTTPException(status_code=401, detail="Admin session required")
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise HTTPException(status_code=503, detail="MFA provider unavailable")

    base = settings.supabase_url.rstrip("/") + "/auth/v1"
    headers = {
        "apikey": settings.supabase_anon_key,
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    try:
        with httpx.Client(timeout=8.0) as session:
            # MFA listFactors() uses GET /user, which includes enrolled factors.
            # /factors only supports enrollment (POST), not listing via GET.
            user_response = session.get(base + "/user", headers=headers)
            if user_response.status_code in (401, 403):
                raise HTTPException(status_code=401, detail="Admin session expired")
            if user_response.status_code != 200:
                raise HTTPException(status_code=503, detail="MFA provider unavailable")
            user_data = user_response.json()
            if user_data.get("id") != admin_id:
                raise HTTPException(status_code=403, detail="MFA identity mismatch")
            factors = user_data.get("factors") or []
            if not isinstance(factors, list):
                raise HTTPException(status_code=503, detail="Invalid MFA provider response")
            verified = next(
                (
                    item for item in factors
                    if isinstance(item, dict)
                    and (item.get("factor_type") or item.get("type")) == "totp"
                    and item.get("status") == "verified"
                ),
                None,
            )
            if verified is None:
                raise HTTPException(
                    status_code=428,
                    detail="Configure and activate an authenticator before changing plans",
                )
            factor_id = verified.get("id")
            if not isinstance(factor_id, str):
                raise HTTPException(status_code=503, detail="MFA provider unavailable")

            challenge = session.post(
                f"{base}/factors/{factor_id}/challenge", headers=headers, json={}
            )
            if challenge.status_code != 200:
                raise HTTPException(status_code=503, detail="MFA challenge unavailable")
            challenge_id = challenge.json().get("id")
            if not isinstance(challenge_id, str):
                raise HTTPException(status_code=503, detail="MFA challenge unavailable")

            verification = session.post(
                f"{base}/factors/{factor_id}/verify",
                headers=headers,
                json={"challenge_id": challenge_id, "code": code},
            )
            if verification.status_code == 429:
                raise HTTPException(status_code=429, detail="Too many TOTP attempts")
            if verification.status_code in (400, 401, 403, 422):
                raise HTTPException(status_code=400, detail="Invalid TOTP code")
            if verification.status_code != 200:
                raise HTTPException(status_code=503, detail="MFA verification unavailable")

            upgraded_token = verification.json().get("access_token")
            if not isinstance(upgraded_token, str):
                raise HTTPException(status_code=503, detail="MFA verification unavailable")
            # Check that Supabase issued an AAL2 token for the *same* admin.
            segment = upgraded_token.split(".")[1]
            claims = json.loads(
                base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))
            )
            if claims.get("sub") != admin_id or claims.get("aal") != "aal2":
                raise HTTPException(status_code=403, detail="MFA identity mismatch")
    except httpx.RequestError:
        raise HTTPException(status_code=503, detail="MFA provider unavailable") from None
    except (ValueError, TypeError, KeyError, IndexError):
        raise HTTPException(status_code=503, detail="Invalid MFA provider response") from None

    return hmac.new(
        settings.reporter_pseudonym_secret().encode(),
        f"admin-plan-totp:{admin_id}:{code}".encode(),
        hashlib.sha256,
    ).hexdigest()


@router.post("/{owner_id}/plan")
def change_user_plan(
    request: PlanChangeRequest,
    owner_id: str = Path(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_-]+$"),
) -> dict[str, Any]:
    admin = _require_admin()
    client = _admin_client()
    user = auth_user(client, owner_id)
    from apps.api.routes.admin_user_actions import _protected

    if _protected(user, admin.id):
        raise HTTPException(status_code=403, detail="Protected team account")
    # Shared per-admin throttle: effective across multiple serverless instances.
    try:
        allowed = client.rpc(
            "admin_plan_totp_register_attempt", {"p_admin_id": admin.id}
        ).execute().data
    except Exception:
        raise HTTPException(status_code=503, detail="MFA rate limit unavailable") from None
    if allowed is not True:
        raise HTTPException(status_code=429, detail="Too many attempts; try again later")

    proof = _verify_plan_totp(admin.id, request.totp_code)
    try:
        client.rpc(
            "admin_change_user_plan_totp",
            {
                "p_owner_id": owner_id,
                "p_admin_id": admin.id,
                "p_plan": request.plan,
                "p_code_digest": proof,
            },
        ).execute()
    except Exception:
        raise HTTPException(
            status_code=409, detail="Plan change failed or TOTP code already used"
        ) from None
    return {"owner_id": owner_id, "plan": request.plan}
