"""Read-only account checks for support; never infer receipts from plan selection."""

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, HTTPException, Query

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _admin_client, _list_auth_users, _parse_datetime, _require_admin
from packages.core.domain.subscription.models import Subscription

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
    }


@router.get("")
def list_users(
    q: str = Query(default="", max_length=200),
    page: int = Query(default=1, ge=1, le=2000),
    page_size: int = Query(default=50, ge=1, le=100),
) -> dict[str, Any]:
    _require_admin()
    try:
        client = _admin_client()
        users = _list_auth_users(client)
        needle = q.strip().casefold()
        if needle:
            users = [
                user
                for user in users
                if needle in str(getattr(user, "email", "") or "").casefold()
                or needle in str(user.id).casefold()
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
            "users": [_account(user, subscriptions.get(str(user.id)), now) for user in selected],
            "total": total,
            "page": page,
            "page_size": page_size,
            "test_plan": get_container().subscription_test_plan,
            "payments_available": False,
        }
    except HTTPException:
        raise
    except Exception:
        # Provider exceptions can contain personal data or connection details.
        raise HTTPException(status_code=503, detail="User data is not available") from None
