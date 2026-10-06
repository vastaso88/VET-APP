from typing import Any

from fastapi import APIRouter, HTTPException, status

from apps.api.dependencies.container import get_container
from packages.infrastructure.persistence.supabase.client import build_supabase_client

router = APIRouter(prefix="/admin", tags=["admin"])


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
    if not user.email or user.email.strip().lower() not in emails:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _count_rows(query: Any) -> int:
    response = query.range(0, 0).execute()
    count = getattr(response, "count", None)
    return int(count or 0)


def _count_auth_users(client: Any) -> int:
    total = 0
    page = 1
    per_page = 1000

    while page <= 100:
        response = client.auth.admin.list_users(page=page, per_page=per_page)
        if isinstance(response, list):
            users = response
        else:
            users = getattr(response, "users", None) or []
        total += len(users)
        if len(users) < per_page:
            break
        page += 1

    return total


@router.get("/me")
def admin_me() -> dict[str, str]:
    user = _require_admin()
    return {"id": user.id, "email": user.email}


@router.get("/overview")
def admin_overview() -> dict[str, object]:
    _require_admin()
    container = get_container()
    settings = container.settings

    if settings.persistence_backend != "supabase":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin overview requires PERSISTENCE_BACKEND=supabase",
        )

    client = build_supabase_client(settings)

    users = _count_auth_users(client)
    pets = _count_rows(client.table("pet_profiles").select("id", count="exact"))
    conversations = _count_rows(client.table("conversations").select("id", count="exact"))
    radar_osm = _count_rows(client.table("radar_places_osm").select("id", count="exact"))
    radar_open = _count_rows(client.table("radar_places_open").select("id", count="exact"))
    radar_reports = _count_rows(
        client.table("radar_user_reports").select("id", count="exact").eq("status", "pending")
    )
    chat_reports = _count_rows(
        client.table("chat_response_reports")
        .select("id", count="exact")
        .eq("status", "reported")
    )
    marketplace_reports = _count_rows(
        client.table("marketplace_listing_reports").select("id", count="exact")
    )
    scrape_runs = _count_rows(client.table("scrape_runs").select("id", count="exact"))

    sources_response = (
        client.table("data_sources")
        .select("source,release,place_count,imported_at")
        .order("source")
        .execute()
    )
    recent_runs_response = (
        client.table("scrape_runs")
        .select(
            "id,engine,status,coverage_key,source_names,place_count,error_message,"
            "requested_at,started_at,finished_at"
        )
        .order("created_at", desc=True)
        .limit(5)
        .execute()
    )

    return {
        "metrics": {
            "users": users,
            "pets": pets,
            "conversations": conversations,
            "radar_places": radar_osm + radar_open,
            "radar_osm": radar_osm,
            "radar_open": radar_open,
            "open_moderation": radar_reports + chat_reports + marketplace_reports,
            "scrape_runs": scrape_runs,
        },
        "moderation": {
            "radar_reports": radar_reports,
            "chat_reports": chat_reports,
            "marketplace_reports": marketplace_reports,
        },
        "data_sources": getattr(sources_response, "data", None) or [],
        "recent_runs": getattr(recent_runs_response, "data", None) or [],
    }
