"""Read-only account checks for support; never infer receipts from plan selection."""

from collections import Counter
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import APIRouter, HTTPException, Path, Query
from pydantic import BaseModel
from typing import Literal

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _admin_client, _list_auth_users, _parse_datetime, _require_admin
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.admin.user_reports import countries, moderation

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
    try:
        client.rpc("admin_change_user_plan", {
            "p_owner_id": owner_id,
            "p_admin_id": admin.id,
            "p_plan": request.plan,
        }).execute()
    except Exception:
        raise HTTPException(status_code=503, detail="Plan update unavailable; check database migration") from None
    return {"owner_id": owner_id, "plan": request.plan}
