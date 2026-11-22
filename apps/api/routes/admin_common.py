"""Helpers shared by every admin router (access check, Supabase client, paging)."""

import hashlib
import hmac
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, status

from apps.api.dependencies.container import get_container


def _configured_admin_emails() -> frozenset[str]:
    settings = get_container().settings
    configured = settings.admin_emails or settings.developer_emails
    return frozenset(email.strip().lower() for email in configured if email.strip())


def _require_admin() -> Any:
    emails = _configured_admin_emails()
    if not emails:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin access is not configured",
        )

    user = get_container().auth_provider.get_current_user()
    if not user.email or not user.email_verified or user.email.strip().lower() not in emails:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _admin_client() -> Any:
    container = get_container()
    if container.settings.persistence_backend != "supabase":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin operations require PERSISTENCE_BACKEND=supabase",
        )

    # Lazy import keeps the API bootstrap usable in the in-memory runtime.
    from packages.infrastructure.persistence.supabase.client import build_supabase_client

    return build_supabase_client(container.settings)


def _count_rows(query: Any) -> int:
    response = query.range(0, 0).execute()
    count = getattr(response, "count", None)
    return int(count or 0)


def _list_auth_users(client: Any) -> list[Any]:
    all_users: list[Any] = []
    page = 1
    per_page = 1000

    while page <= 100:
        response = client.auth.admin.list_users(page=page, per_page=per_page)
        if isinstance(response, list):
            users = response
        else:
            users = getattr(response, "users", None) or []
        all_users.extend(users)
        if len(users) < per_page:
            break
        page += 1

    return all_users


def _parse_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=UTC)
    if value is None:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def _require_scheduler_token(value: str | None) -> None:
    settings = get_container().settings
    # Preferred: a dedicated secret (ADMIN_SCHEDULER_SECRET), rotatable on
    # its own. Fallback for deployments that have not set it yet: the
    # legacy digest of the service-role key.
    dedicated = settings.admin_scheduler_secret.strip()
    if dedicated:
        expected = dedicated
    else:
        service_key = settings.supabase_service_role_key
        if not service_key:
            raise HTTPException(status_code=503, detail="Scheduler is not configured")
        expected = hashlib.sha256(f"vetapp-admin-scheduler:{service_key}".encode()).hexdigest()
    if not value or not hmac.compare_digest(value, expected):
        raise HTTPException(status_code=403, detail="Invalid scheduler token")
