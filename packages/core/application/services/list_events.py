from datetime import date, timedelta
from typing import Any

from pydantic import BaseModel

from packages.core.application.ports.event_catalog_repository import EventCatalogRepository
from packages.shared.errors.base import ValidationError

# The app asks for a month at a time; a year is the most it ever needs.
MAX_WINDOW = timedelta(days=400)


class ListEventsInput(BaseModel):
    country: str
    from_day: date
    to_day: date


class ListEventsOutput(BaseModel):
    events: list[dict[str, Any]]


class ListEventsService:
    """The events catalogue through the backend, so the plan check does not
    depend on the app (the table used to be read straight from the app with
    the public key)."""

    def __init__(self, repository: EventCatalogRepository) -> None:
        self._repository = repository

    def execute(self, data: ListEventsInput) -> ListEventsOutput:
        country = data.country.strip().upper()
        if len(country) != 2 or not country.isalpha():
            raise ValidationError("country must be a two-letter code")
        if data.to_day < data.from_day:
            raise ValidationError("the end of the window is before its start")
        if data.to_day - data.from_day > MAX_WINDOW:
            raise ValidationError("the window is too wide")
        return ListEventsOutput(
            events=self._repository.list_public(
                country=country, from_day=data.from_day, to_day=data.to_day
            )
        )
