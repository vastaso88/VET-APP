from datetime import date
from typing import Any

from packages.core.application.ports.event_catalog_repository import EventCatalogRepository


class InMemoryEventCatalogRepository(EventCatalogRepository):
    """No events of its own: the catalogue is real data curated by hand
    (project rule: never invented examples). Tests put rows in with [add]."""

    def __init__(self) -> None:
        self._rows: list[dict[str, Any]] = []

    def add(self, row: dict[str, Any]) -> None:
        self._rows.append(row)

    def has_public_events(self, country: str) -> bool:
        return any(
            _country(row) == country
            and row.get("audience", "public") == "public"
            and row.get("status", "published") in ("published", "cancelled", "postponed")
            for row in self._rows
        )

    def list_public(self, *, country: str, from_day: date, to_day: date) -> list[dict[str, Any]]:
        return [row for row in self._in_window(from_day, to_day) if _country(row) == country]

    def list_public_abroad(
        self, *, country: str, from_day: date, to_day: date
    ) -> list[dict[str, Any]]:
        return [dict(row) for row in self._in_window(from_day, to_day) if _country(row) != country]

    def _in_window(self, from_day: date, to_day: date) -> list[dict[str, Any]]:
        def keep(row: dict[str, Any]) -> bool:
            return (
                row.get("audience", "public") == "public"
                and row.get("status", "published") in ("published", "cancelled", "postponed")
                and date.fromisoformat(str(row["ends_on"])) >= from_day
                and date.fromisoformat(str(row["starts_on"])) <= to_day
            )

        return sorted((row for row in self._rows if keep(row)), key=lambda r: str(r["starts_on"]))


def _country(row: dict[str, Any]) -> str:
    return str(row.get("country", "IT")).upper()
