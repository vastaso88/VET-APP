from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.event_catalog_repository import EventCatalogRepository

if TYPE_CHECKING:
    from supabase import Client

# The columns the app shows; the bookkeeping ones (slug, source, license,
# verification, species...) stay on the server.
_COLUMNS = (
    "id,title,description,event_type,level,country,starts_on,ends_on,city,"
    "province_code,region,venue_name,organizer_name,source_url,status,last_verified_at"
)


class SupabaseEventCatalogRepository(EventCatalogRepository):
    """`events`, read with the service role. The table is written only by the
    curation scripts; until scripts/setup/events_read_via_backend.sql has run
    its public-read policy still lets the app read it directly."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "events"

    def list_public(self, *, country: str, from_day: date, to_day: date) -> list[dict[str, Any]]:
        response = (
            self._client.table(self._table)
            .select(_COLUMNS)
            .in_("status", ["published", "cancelled", "postponed"])
            .eq("audience", "public")
            .eq("country", country)
            .gte("ends_on", from_day.isoformat())
            .lte("starts_on", to_day.isoformat())
            .order("starts_on")
            .execute()
        )
        return [dict(row) for row in response.data or [] if isinstance(row, dict)]
