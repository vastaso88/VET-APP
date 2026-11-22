"""TEMPORARY (QK-07): the admin users / pets directories as they worked before the
database functions of supabase/migrations/20261122100000_admin_directories.sql.

Used only while those functions do not exist in the database (the API notices the
"function not found" answer once and remembers it for the life of the process, see
packages/infrastructure/admin/user_reports.py). It reads everything and filters in
Python, so it keeps the old limits: the pets read stops at the provider window (1000
rows). DELETE THIS FILE, and the `fallback` arguments of `users_directory` /
`pets_directory`, once the migration is applied in production.

Both functions return exactly what the database functions return, so the routes do not
care which path answered."""

from collections import Counter
from datetime import UTC, datetime
from typing import Any

from apps.api.routes.admin_common import _list_auth_users, _parse_datetime
from packages.core.domain.pet_profile.directory_traits import with_directory_fields
from packages.infrastructure.admin.user_reports import countries


def legacy_users_directory(
    client: Any, *, q: str, country: str, page: int, page_size: int
) -> dict[str, Any]:
    users = _list_auth_users(client)
    locations = countries(client)

    def bucket(user: Any) -> str:
        return str(locations.get(str(user.id), {}).get("country_code") or "unknown")

    needle = q.strip().casefold()
    if needle:
        users = [
            user
            for user in users
            if needle in str(getattr(user, "email", "") or "").casefold()
            or needle in str(user.id).casefold()
        ]
    country_counts = Counter(bucket(user) for user in users)
    if country:
        users = [user for user in users if bucket(user) == country]
    users.sort(
        key=lambda user: (
            _parse_datetime(getattr(user, "created_at", None)) or datetime.min.replace(tzinfo=UTC),
            str(user.id),
        ),
        reverse=True,
    )
    total = len(users)
    page = min(page, max(1, (total + page_size - 1) // page_size))
    rows = []
    for user in users[(page - 1) * page_size : page * page_size]:
        place = locations.get(str(user.id)) or {}
        rows.append(
            {
                "id": str(user.id),
                "email": getattr(user, "email", None),
                "created_at": getattr(user, "created_at", None),
                "last_sign_in_at": getattr(user, "last_sign_in_at", None),
                "email_confirmed_at": getattr(user, "email_confirmed_at", None),
                "banned_until": getattr(user, "banned_until", None),
                "home_country_code": place.get("country_code"),
                "home_city": place.get("city"),
                "home_saved_at": place.get("updated_at"),
            }
        )
    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "countries": dict(country_counts),
        "rows": rows,
    }


def legacy_pets_directory(
    client: Any,
    *,
    q: str,
    species: str,
    status: str,
    country: str,
    region: str,
    page: int,
    page_size: int,
) -> dict[str, Any]:
    # Fetch only administrative directory fields, never medical notes or records.
    response = (
        client.table("pet_profiles").select("id,owner_id,name,species,breed,is_memorial").execute()
    )
    # QK-07d: group, exotic and active are derived from species / is_memorial (the
    # columns of the same names are never written).
    rows = [with_directory_fields(row) for row in (getattr(response, "data", None) or [])]
    # UserLocation stores country and city, but has no region field.
    owner_ids = sorted({str(row["owner_id"]) for row in rows if row.get("owner_id")})
    locations: dict[str, dict[str, Any]] = {}
    for start in range(0, len(owner_ids), 100):
        result = (
            client.table("user_locations")
            .select("owner_id,home_country_code,home_city")
            .in_("owner_id", owner_ids[start : start + 100])
            .execute()
        )
        for location in getattr(result, "data", None) or []:
            locations[str(location["owner_id"])] = location
    for row in rows:
        location = locations.get(str(row.get("owner_id")), {})
        row["country"] = location.get("home_country_code")
        row["region"] = None  # No administrative region persisted for users.
        row["city"] = location.get("home_city")
    needle = q.strip().casefold()
    if needle:
        rows = [
            row
            for row in rows
            if any(
                needle in str(row.get(field) or "").casefold()
                for field in ("name", "id", "owner_id", "breed")
            )
        ]
    if country:
        rows = [row for row in rows if (row.get("country") or "").upper() == country.upper()]
    if region:
        rows = [row for row in rows if region.casefold() in (row.get("city") or "").casefold()]
    if species:
        rows = [row for row in rows if row["species_group"] == species]
    if status:
        flag = {
            "active": "is_active",
            "inactive": "is_active",
            "exotic": "is_exotic",
            "memorial": "is_memorial",
        }[status]
        expected = status != "inactive"
        rows = [row for row in rows if row.get(flag) is expected]
    rows.sort(key=lambda row: (str(row.get("name") or "").casefold(), str(row.get("id") or "")))
    total = len(rows)
    page = min(page, max(1, (total + page_size - 1) // page_size))
    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "rows": rows[(page - 1) * page_size : page * page_size],
    }
