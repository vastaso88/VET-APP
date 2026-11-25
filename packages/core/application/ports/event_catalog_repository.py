from datetime import date
from typing import Any, Protocol


class EventCatalogRepository(Protocol):
    def list_public(self, *, country: str, from_day: date, to_day: date) -> list[dict[str, Any]]:
        """The public events of [country] that touch the window
        [from_day]..[to_day] (ends included), oldest start first. Published,
        cancelled and postponed events only, `audience = 'public'`."""
        ...

    def list_public_abroad(
        self, *, country: str, from_day: date, to_day: date
    ) -> list[dict[str, Any]]:
        """Like [list_public], but the events of every OTHER country, with their `latitude` and
        `longitude` when they have them. Nobody sees this list as it is: the service keeps the
        ones the rule of `core/domain/events/abroad.py` allows."""
        ...

    def has_public_events(self, country: str) -> bool:
        """Whether the country has at least one event [list_public] can return, in any period."""
        ...
