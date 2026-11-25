"""Collaudo F42: an empty list said nothing, so someone outside Italy thought the app was broken.
The answer says whether the country has any event at all; the app writes its own words."""

from datetime import date

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.application.services.get_user_location import GetUserLocationService
from packages.core.application.services.list_events import (
    ListEventsInput,
    ListEventsOutput,
    ListEventsService,
)
from packages.infrastructure.persistence.in_memory_event_catalog import (
    InMemoryEventCatalogRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryUserLocationRepository,
)


def _event(**values: object) -> dict[str, object]:
    return {
        "id": "ev-1",
        "title": "Giornata del cane",
        "country": "IT",
        "starts_on": "2026-12-05",
        "ends_on": "2026-12-05",
        **values,
    }


def _ask(
    repository: InMemoryEventCatalogRepository, country: str = "IT", year: int = 2026
) -> ListEventsOutput:
    locations = GetUserLocationService(InMemoryUserLocationRepository())
    return ListEventsService(repository, locations).execute(
        ListEventsInput(country=country, from_day=date(year, 12, 1), to_day=date(year, 12, 31))
    )


def test_a_country_with_no_events_at_all_is_told_apart_from_an_empty_month() -> None:
    repository = InMemoryEventCatalogRepository()
    repository.add(_event())

    abroad = _ask(repository, "FR")
    quiet_month = _ask(repository, "IT", year=2027)

    assert (abroad.events, abroad.country_has_events) == ([], False)
    assert (quiet_month.events, quiet_month.country_has_events) == ([], True)
    assert _ask(repository).country_has_events is True


def test_only_the_events_anybody_can_see_count() -> None:
    repository = InMemoryEventCatalogRepository()
    repository.add(_event(id="a", country="DE", status="draft"))
    repository.add(_event(id="b", country="ES", audience="professional"))
    repository.add(_event(id="c", country="at", status="cancelled"))

    assert _ask(repository, "DE").country_has_events is False
    assert _ask(repository, "ES").country_has_events is False
    assert _ask(repository, "AT").country_has_events is True


def test_the_route_says_it() -> None:
    response = TestClient(app).get(
        "/events", params={"country": "zz", "from": "2026-12-01", "to": "2026-12-31"}
    )

    assert response.status_code == 200
    assert response.json() == {"events": [], "country_has_events": False}
