import logging
from datetime import date, timedelta
from typing import Any

from pydantic import BaseModel

from packages.core.application.ports.event_catalog_repository import EventCatalogRepository
from packages.core.application.services.get_user_location import (
    GetUserLocationInput,
    GetUserLocationService,
)
from packages.core.domain.events.abroad import is_near_border, is_shown_abroad
from packages.core.domain.geo.models import Coordinates
from packages.shared.errors.base import ValidationError

logger = logging.getLogger(__name__)

# The app asks for a month at a time; a year is the most it ever needs.
MAX_WINDOW = timedelta(days=400)


class ListEventsInput(BaseModel):
    country: str
    from_day: date
    to_day: date
    # The signed-in owner, to add the events of other countries they may see; None: only the
    # events of `country`.
    abroad_for_owner: str | None = None


class ListEventsOutput(BaseModel):
    events: list[dict[str, Any]]
    # Collaudo F42: an empty list of a country the catalogue does not cover (false) is not
    # "nothing in this period" (true).
    country_has_events: bool


class ListEventsService:
    """The events catalogue through the backend, so the plan check does not
    depend on the app (the table used to be read straight from the app with
    the public key)."""

    def __init__(
        self, repository: EventCatalogRepository, locations: GetUserLocationService
    ) -> None:
        self._repository = repository
        self._locations = locations

    def execute(self, data: ListEventsInput) -> ListEventsOutput:
        country = data.country.strip().upper()
        if len(country) != 2 or not country.isalpha():
            raise ValidationError("country must be a two-letter code")
        if data.to_day < data.from_day:
            raise ValidationError("the end of the window is before its start")
        if data.to_day - data.from_day > MAX_WINDOW:
            raise ValidationError("the window is too wide")
        own = self._repository.list_public(
            country=country, from_day=data.from_day, to_day=data.to_day
        )
        abroad = self._abroad(data, country, data.abroad_for_owner) if data.abroad_for_owner else []
        return ListEventsOutput(
            events=sorted([*own, *abroad], key=lambda event: str(event["starts_on"])),
            country_has_events=bool(own) or self._repository.has_public_events(country),
        )

    def _abroad(self, data: ListEventsInput, country: str, owner_id: str) -> list[dict[str, Any]]:
        """The events of other countries the owner may see. `near_border` says which are there
        for their distance; the coordinates stay here."""
        rows = self._repository.list_public_abroad(
            country=country, from_day=data.from_day, to_day=data.to_day
        )
        if not rows:
            return []
        owner = self._owner_position(owner_id)
        shown = []
        for row in rows:
            place = _take_place(row)
            if is_shown_abroad(level=row.get("level"), place=place, owner=owner):
                shown.append({**row, "near_border": is_near_border(place=place, owner=owner)})
        return shown

    def _owner_position(self, owner_id: str) -> Coordinates | None:
        try:
            location = self._locations.execute(GetUserLocationInput(owner_id=owner_id))
        except Exception as exc:  # noqa: BLE001 - the list must not fail for it
            # Only the kind of error: the text of an invalid row holds the position.
            logger.warning("events: Località not readable (%s)", type(exc).__name__)
            return None
        return location.user_location.reference


def _take_place(row: dict[str, Any]) -> Coordinates | None:
    """The coordinates of the event, taken out of [row]."""
    latitude, longitude = row.pop("latitude", None), row.pop("longitude", None)
    if latitude is None or longitude is None:
        return None
    return Coordinates(latitude=latitude, longitude=longitude)
