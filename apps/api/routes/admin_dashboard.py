"""Admin dashboard: who am I, overview numbers, geographic map data, billing."""

import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from functools import lru_cache
from typing import Any, Literal

from fastapi import APIRouter, HTTPException
from postgrest.types import CountMethod
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.routes.admin_common import (
    _admin_client,
    _count_rows,
    _list_auth_users,
    _parse_datetime,
    _require_admin,
)
from packages.core.domain.pet_profile.directory_traits import pet_overview

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/me")
def admin_me() -> dict[str, str]:
    user = _require_admin()
    return {"id": user.id, "email": user.email}


@router.get("/overview")
def admin_overview() -> dict[str, object]:
    _require_admin()
    return _cached_admin_overview(int(time.monotonic() // 120))


@lru_cache(maxsize=2)
def _cached_admin_overview(_bucket: int) -> dict[str, object]:
    """Cache expensive aggregate dashboard queries for up to 120 seconds."""
    client = _admin_client()

    auth_users = _list_auth_users(client)
    users = len(auth_users)
    auth_ids = {str(getattr(user, "id", "")) for user in auth_users if getattr(user, "id", None)}
    now = datetime.now(UTC)

    owner_profiles_response = (
        client.table("owner_profiles")
        .select("owner_id,city,latitude,longitude,created_at")
        .execute()
    )
    owner_profiles = [
        row
        for row in (getattr(owner_profiles_response, "data", None) or [])
        if str(row.get("owner_id")) in auth_ids
    ]

    pet_profiles_response = (
        client.table("pet_profiles").select("id,owner_id,species,is_memorial").execute()
    )
    pet_rows = list(getattr(pet_profiles_response, "data", None) or [])
    pet_owner_ids = {str(row.get("owner_id")) for row in pet_rows if row.get("owner_id")}

    new_7d = 0
    new_30d = 0
    for user in auth_users:
        created_at = _parse_datetime(getattr(user, "created_at", None))
        if created_at is None:
            continue
        if created_at >= now - timedelta(days=7):
            new_7d += 1
        if created_at >= now - timedelta(days=30):
            new_30d += 1

    # Independent aggregate reads run concurrently instead of serial network round trips.
    def count_table(
        table: str, *, field: str | None = None, values: list[str] | None = None
    ) -> int:
        query = _admin_client().table(table).select("id", count=CountMethod.exact)
        if field and values:
            query = query.eq(field, values[0]) if len(values) == 1 else query.in_(field, values)
        return _count_rows(query)

    def optional_message_reports() -> int:
        try:
            return count_table("marketplace_conversation_reports", field="status", values=["open"])
        except Exception:
            return 0

    def optional_listing_reviews() -> int:
        try:
            return count_table("marketplace_listing_reviews", field="status", values=["open"])
        except Exception:
            return 0

    def load_sources() -> Any:
        return (
            _admin_client()
            .table("data_sources")
            .select("source,release,place_count,imported_at")
            .order("source")
            .execute()
        )

    def load_runs() -> Any:
        return (
            _admin_client()
            .table("scrape_runs")
            .select(
                "id,engine,status,coverage_key,source_names,place_count,error_message,"
                "requested_at,started_at,finished_at"
            )
            .order("created_at", desc=True)
            .limit(5)
            .execute()
        )

    with ThreadPoolExecutor(max_workers=10) as pool:
        tasks = {
            "conversations": pool.submit(count_table, "conversations"),
            "radar_osm": pool.submit(count_table, "radar_places_osm"),
            "radar_open": pool.submit(count_table, "radar_places_open"),
            "radar_reports": pool.submit(
                count_table, "radar_user_reports", field="status", values=["pending"]
            ),
            "chat_reports": pool.submit(
                count_table,
                "chat_response_reports",
                field="status",
                values=["reported", "under_review"],
            ),
            "marketplace_reports": pool.submit(
                count_table, "marketplace_listing_reports", field="status", values=["open"]
            ),
            "marketplace_message_reports": pool.submit(optional_message_reports),
            "listing_reviews": pool.submit(optional_listing_reviews),
            "scrape_runs": pool.submit(count_table, "scrape_runs"),
            "sources_response": pool.submit(load_sources),
            "recent_runs_response": pool.submit(load_runs),
        }
        results = {name: future.result() for name, future in tasks.items()}
    conversations = results["conversations"]
    radar_osm = results["radar_osm"]
    radar_open = results["radar_open"]
    radar_reports = results["radar_reports"]
    chat_reports = results["chat_reports"]
    marketplace_reports = results["marketplace_reports"]
    marketplace_message_reports = results["marketplace_message_reports"]
    listing_reviews = results["listing_reviews"]
    scrape_runs = results["scrape_runs"]
    sources_response = results["sources_response"]
    recent_runs_response = results["recent_runs_response"]

    return {
        "metrics": {
            "users": users,
            "pets": len(pet_rows),
            "conversations": conversations,
            "radar_places": radar_osm + radar_open,
            "radar_osm": radar_osm,
            "radar_open": radar_open,
            "open_moderation": (
                radar_reports
                + chat_reports
                + marketplace_reports
                + marketplace_message_reports
                + listing_reviews
            ),
            "scrape_runs": scrape_runs,
        },
        "user_details": {
            "auth_accounts": users,
            "profiles": len(owner_profiles),
            "geolocated": sum(
                1
                for row in owner_profiles
                if row.get("latitude") is not None and row.get("longitude") is not None
            ),
            "with_pets": len(auth_ids & pet_owner_ids),
            "new_7d": new_7d,
            "new_30d": new_30d,
        },
        # QK-07d: derived from the species and is_memorial (the three columns the panel
        # used to read are never written), see directory_traits.py.
        "pet_details": pet_overview(pet_rows),
        "moderation": {
            "radar_reports": radar_reports,
            "chat_reports": chat_reports,
            "marketplace_reports": marketplace_reports,
            "marketplace_message_reports": marketplace_message_reports,
            "listing_reviews": listing_reviews,
        },
        "data_sources": getattr(sources_response, "data", None) or [],
        "recent_runs": getattr(recent_runs_response, "data", None) or [],
    }


@router.get("/geographic")
def admin_geographic() -> dict[str, object]:
    _require_admin()
    client = _admin_client()

    sources_response = (
        client.table("data_sources")
        .select(
            "source,release,license,attribution,url,place_count,imported_at,"
            "min_latitude,max_latitude,min_longitude,max_longitude"
        )
        .order("source")
        .execute()
    )
    coverage_response = (
        client.table("radar_coverage_cells")
        .select(
            "coverage_key,center_latitude,center_longitude,radius_km,source_name,"
            "place_count,refreshed_at,expires_at"
        )
        .order("refreshed_at", desc=True)
        .limit(500)
        .execute()
    )

    auth_users = _list_auth_users(client)
    auth_by_id = {
        str(user.id): getattr(user, "email", None)
        for user in auth_users
        if getattr(user, "id", None)
    }
    users_response = (
        client.table("owner_profiles")
        .select("owner_id,city,address_label,latitude,longitude,created_at")
        .limit(500)
        .execute()
    )
    users = []
    for row in getattr(users_response, "data", None) or []:
        owner_id = str(row.get("owner_id"))
        if owner_id not in auth_by_id:
            continue
        if row.get("latitude") is None or row.get("longitude") is None:
            continue
        users.append({**row, "email": auth_by_id[owner_id]})

    return {
        "counts": {
            "osm": _count_rows(
                client.table("radar_places_osm").select("id", count=CountMethod.exact)
            ),
            "open": _count_rows(
                client.table("radar_places_open").select("id", count=CountMethod.exact)
            ),
            "cache": _count_rows(
                client.table("radar_places_cache").select("id", count=CountMethod.exact)
            ),
        },
        "sources": getattr(sources_response, "data", None) or [],
        "coverage": getattr(coverage_response, "data", None) or [],
        "users": users,
    }


# --- Billing (App Store / Google Play) ---------------------------------------

# Indicative Italian list prices (docs/marketing/03_prezzi_per_paese.md), used
# only for an ESTIMATE: actual proceeds come from the store reports.
_LIST_PRICE_EUR = {
    ("plus", "monthly"): 4.59,
    ("plus", "yearly"): 45.99,
    ("pro", "monthly"): 8.59,
    ("pro", "yearly"): 85.99,
    ("ultra", "monthly"): 15.59,
    ("ultra", "yearly"): 155.99,
}


@router.get("/billing/overview")
def admin_billing_overview() -> dict[str, object]:
    _require_admin()
    container = get_container()
    from packages.core.domain.common.entity import utc_now

    now = utc_now()
    tolerance = timedelta(hours=container.settings.billing_verification_tolerance_hours)
    entitlements = container.store_entitlement_repository.list_all()
    active = [e for e in entitlements if e.grants_access(now=now, tolerance=tolerance)]
    by_plan: Counter[str] = Counter(e.plan for e in active)
    by_store: Counter[str] = Counter(str(e.store) for e in active)
    by_state: Counter[str] = Counter(str(e.state) for e in entitlements)
    week = now + timedelta(days=7)
    without_plan = container.subscription_repository.list_without_plan()
    monthly_estimate = sum(
        _LIST_PRICE_EUR.get((e.plan, str(e.period)), 0.0) / (12 if e.period == "yearly" else 1)
        for e in active
        if e.store != "admin_test"
    )
    return {
        "active_subscriptions": len(active),
        "active_by_plan": dict(by_plan),
        "active_by_store": dict(by_store),
        "states": dict(by_state),
        "expiring_7d": sum(1 for e in active if e.expires_at and e.expires_at < week),
        "not_renewing": sum(1 for e in active if not e.auto_renew),
        "anomalies": sum(1 for e in entitlements if e.anomaly and e.store != "admin_test"),
        "trials_active": sum(1 for s in without_plan if s.is_trial_active(now=now)),
        "trials_ending_7d": sum(
            1 for s in without_plan if s.is_trial_active(now=now) and s.trial_ends_at < week
        ),
        "trials_expired_without_plan": sum(
            1 for s in without_plan if not s.is_trial_active(now=now)
        ),
        "revenue": {
            "kind": "estimate_gross_list_price",
            "monthly_recurring_eur_estimate": round(monthly_estimate, 2),
            "note": (
                "Stima lorda a prezzo di listino italiano, IVA e commissioni store incluse. "
                "Non è un incasso: i ricavi effettivi si riconciliano con i report di "
                "App Store Connect e Google Play Console."
            ),
            "reconciled_eur": None,
        },
    }


@router.get("/billing/users/{owner_id}")
def admin_billing_user(owner_id: str) -> dict[str, object]:
    _require_admin()
    if len(owner_id) > 100:
        raise HTTPException(status_code=404, detail="Not found")
    container = get_container()
    subscription = container.subscription_repository.get(owner_id)
    entitlements = container.store_entitlement_repository.list_for_owner(owner_id)
    tolerance = timedelta(hours=container.settings.billing_verification_tolerance_hours)
    return {
        "owner_id": owner_id,
        "plan": subscription.plan if subscription else None,
        "trial_ends_at": subscription.trial_ends_at if subscription else None,
        "subscriptions": [
            {
                "store": e.store,
                "product_id": e.product_id,
                "plan": e.plan,
                "period": e.period,
                "state": e.state,
                "expires_at": e.expires_at,
                "auto_renew": e.auto_renew,
                "grace_expires_at": e.grace_expires_at,
                "revoked_at": e.revoked_at,
                "environment": e.environment,
                "last_verified_at": e.last_verified_at,
                "verification_error_at": e.verification_error_at,
                "anomaly": e.anomaly,
                "grants_access": e.grants_access(tolerance=tolerance),
            }
            for e in entitlements
        ],
    }


class AdminTestGrantBody(BaseModel):
    owner_id: str = Field(min_length=1, max_length=100)
    plan: Literal["plus", "pro", "ultra"]
    days: int = Field(default=7, ge=1, le=31)


@router.post("/billing/test-grant")
def admin_billing_test_grant(body: AdminTestGrantBody) -> dict[str, object]:
    """Team-only test plan, separate from every public flow. Refused in
    production and unless BILLING_ADMIN_TEST_GRANTS=true."""
    _require_admin()
    container = get_container()
    settings = container.settings
    if settings.environment == "production" or not settings.billing_admin_test_grants:
        raise HTTPException(status_code=403, detail="Test grants are disabled")
    service = container.store_billing_service()
    if service is None:
        raise HTTPException(status_code=503, detail="billing_not_configured")
    entitlement = service.grant_admin_test(body.owner_id, body.plan, body.days)
    return {"plan": entitlement.plan, "expires_at": entitlement.expires_at}
