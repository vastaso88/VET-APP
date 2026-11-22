"""Support projections. Never load conversation text to calculate usage."""

import logging
from collections.abc import Callable
from typing import Any

logger = logging.getLogger(__name__)


def all_rows(query: Callable[[], Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for offset in range(0, 100_000, 1000):
        batch = list(query().range(offset, offset + 999).execute().data or [])
        rows.extend(batch)
        if len(batch) < 1000:
            return rows
    raise RuntimeError("Result exceeds the support listing limit")


# TEMPORARY (QK-07): functions the database has been seen NOT to have, for the life of
# this process, so a missing migration is not retried on every request. Remove together
# with the `fallback` arguments below once migration 20261122100000 is applied in production.
_MISSING_FUNCTIONS: set[str] = set()
_MISSING_CODES = {
    "PGRST202",
    "42883",
}  # PostgREST "function not in schema cache" / undefined_function


def _function_is_missing(error: Exception) -> bool:
    """True only for "that database function does not exist" (PostgREST PGRST202, or the
    Postgres code 42883, or a plain HTTP 404 from the rpc endpoint): any other failure is a
    real failure and must stay one."""
    if str(getattr(error, "code", "") or "") in _MISSING_CODES:
        return True
    status = getattr(error, "status", None) or getattr(error, "status_code", None)
    return status == 404


def _directory_page(
    client: Any,
    function: str,
    params: dict[str, Any],
    fallback: Callable[[], dict[str, Any]],
) -> dict[str, Any]:
    """One database call: the function (supabase/migrations/20261122100000_admin_directories.sql)
    filters, orders and pages inside Postgres. A reply that is not a page is an error,
    never an empty list: an unavailable directory must not read as "no accounts".
    TEMPORARY: while the function does not exist yet, `fallback` (the old read-everything
    logic) answers; every other error propagates."""
    if function not in _MISSING_FUNCTIONS:
        try:
            data = client.rpc(function, params).execute().data
        except Exception as error:
            if not _function_is_missing(error):
                raise
            _MISSING_FUNCTIONS.add(function)
            # No personal data here: only the name of the missing function.
            logger.warning(
                "Admin directory function %s is missing in the database: using the old, slower "
                "path. Apply supabase/migrations/20261122100000_admin_directories.sql.",
                function,
            )
        else:
            if not isinstance(data, dict) or not isinstance(data.get("rows"), list):
                raise RuntimeError("Directory function returned an unexpected reply")
            return data
    return fallback()


def users_directory(
    client: Any,
    *,
    q: str,
    country: str,
    page: int,
    page_size: int,
    fallback: Callable[[], dict[str, Any]],
) -> dict[str, Any]:
    """{total, page, page_size, countries, rows}: one page of accounts. `countries` counts
    the accounts matching `q` per country WITHOUT the country filter, so the portal can
    show the other countries while one is picked; 'unknown' = no residence country."""
    return _directory_page(
        client,
        "admin_users_directory",
        {"p_q": q.strip(), "p_country": country, "p_page": page, "p_page_size": page_size},
        fallback,
    )


def pets_directory(
    client: Any,
    *,
    q: str,
    species: str,
    status: str,
    country: str,
    region: str,
    page: int,
    page_size: int,
    fallback: Callable[[], dict[str, Any]],
) -> dict[str, Any]:
    """{total, page, page_size, rows}: one page of pets (directory fields only)."""
    return _directory_page(
        client,
        "admin_pets_directory",
        {
            "p_q": q.strip(),
            "p_species": species,
            "p_status": status,
            "p_country": country,
            "p_region": region,
            "p_page": page,
            "p_page_size": page_size,
        },
        fallback,
    )


def countries(client: Any) -> dict[str, dict[str, Any]]:
    return {
        str(row["owner_id"]): {
            "country_code": row.get("home_country_code"),
            "city": row.get("home_city"),
            "source": "residence" if row.get("home_country_code") else None,
            "updated_at": row.get("home_saved_at"),
        }
        for row in all_rows(
            lambda: (
                client.table("user_locations")
                .select("owner_id,home_country_code,home_city,home_saved_at")
                .order("owner_id")
            )
        )
    }


def moderation(client: Any, owner_id: str) -> dict[str, Any]:
    """No reporter identities or message text. Received and filed stay distinct.

    Marketplace conversations have an explicit reporter; the other participant is
    the subject. Chat/Radar contributions remain pseudonymous and are not reversed
    to name a reporter in a case. The user's own listing reports can be counted.
    """
    events: list[dict[str, Any]] = []
    truncated = False

    def rows(query: Any) -> list[dict[str, Any]]:
        nonlocal truncated
        result = list(query.limit(101).execute().data or [])
        truncated = truncated or len(result) > 100
        return result[:100]

    listing_ids = [
        str(row["id"])
        for row in all_rows(
            lambda: (
                client.table("marketplace_listings")
                .select("id")
                .eq("owner_id", owner_id)
                .order("id")
            )
        )
    ]
    columns = "id,reason,status,created_at,resolved_at,resolution_action,resolved_by_admin_id"
    received: list[dict[str, Any]] = []
    # Batch the IN clause; a prolific seller must not exceed PostgREST URL limits.
    for start in range(0, len(listing_ids), 100):
        received.extend(
            rows(
                client.table("marketplace_listing_reports")
                .select(columns)
                .in_("listing_id", listing_ids[start : start + 100])
                .order("created_at", desc=True)
            )
        )
    filed = rows(
        client.table("marketplace_listing_reports")
        .select(columns)
        .eq("reporter_owner_id", owner_id)
        .order("created_at", desc=True)
    )
    for direction, reports in (("received", received), ("filed", filed)):
        for report in reports:
            events.append({**report, "queue": "marketplace", "direction": direction})

    conversations: dict[str, dict[str, Any]] = {}
    for column in ("buyer_id", "seller_id"):

        def participant_rows(column: str = column) -> Any:
            return (
                client.table("marketplace_conversations")
                .select("id,buyer_id,seller_id")
                .eq(column, owner_id)
                .order("id")
            )

        for conversation in all_rows(participant_rows):
            conversations[str(conversation["id"])] = conversation
    ids = list(conversations)
    for start in range(0, len(ids), 100):
        reports = rows(
            client.table("marketplace_conversation_reports")
            .select(f"{columns},conversation_id,reporter_id")
            .in_("conversation_id", ids[start : start + 100])
            .order("created_at", desc=True)
        )
        for report in reports:
            direction = "filed" if report.get("reporter_id") == owner_id else "received"
            events.append(
                {
                    key: value
                    for key, value in report.items()
                    if key not in {"reporter_id", "conversation_id"}
                }
                | {"queue": "marketplace_messages", "direction": direction}
            )
    events.sort(key=lambda event: str(event.get("created_at") or ""), reverse=True)
    return {
        "events": events[:200],
        "truncated": truncated or len(events) > 200,
        "received": sum(event["direction"] == "received" for event in events[:200]),
        "filed": sum(event["direction"] == "filed" for event in events[:200]),
    }


def case_is_about(client: Any, owner_id: str, queue: str, case_id: str) -> bool:
    if queue == "marketplace":
        reports = (
            client.table("marketplace_listing_reports")
            .select("listing_id")
            .eq("id", case_id)
            .limit(1)
            .execute()
            .data
            or []
        )
        if not reports:
            return False
        return bool(
            client.table("marketplace_listings")
            .select("id")
            .eq("id", reports[0]["listing_id"])
            .eq("owner_id", owner_id)
            .limit(1)
            .execute()
            .data
        )
    reports = (
        client.table("marketplace_conversation_reports")
        .select("conversation_id,reporter_id")
        .eq("id", case_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    if not reports or reports[0]["reporter_id"] == owner_id:
        return False
    conversations = (
        client.table("marketplace_conversations")
        .select("buyer_id,seller_id")
        .eq("id", reports[0]["conversation_id"])
        .limit(1)
        .execute()
        .data
        or []
    )
    return bool(
        conversations and owner_id in {conversations[0]["buyer_id"], conversations[0]["seller_id"]}
    )
