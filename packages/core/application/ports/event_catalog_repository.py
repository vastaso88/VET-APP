from datetime import date
from typing import Any, Protocol


class EventCatalogRepository(Protocol):
    def list_public(self, *, country: str, from_day: date, to_day: date) -> list[dict[str, Any]]:
        """The public events of [country] that touch the window
        [from_day]..[to_day] (ends included), oldest start first. Published,
        cancelled and postponed events only, `audience = 'public'`."""
        ...
