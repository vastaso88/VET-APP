"""GET /events?abroad=true (collaudo F42): the position comes from the signed-in owner's own row."""

from collections.abc import Iterator
from datetime import date, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.geo.models import Coordinates, UserLocation
from packages.infrastructure.persistence.in_memory_event_catalog import (
    InMemoryEventCatalogRepository,
)

BORDER = Coordinates(latitude=45.83, longitude=9.03)


def _event(event_id: str, **values: object) -> dict[str, Any]:
    day = (date.today() + timedelta(days=10)).isoformat()
    return {
        "id": event_id,
        "title": "Fiera",
        "country": "CH",
        "level": "regional",
        "starts_on": day,
        "ends_on": day,
        **values,
    }


@pytest.fixture
def catalogue(monkeypatch: pytest.MonkeyPatch) -> Iterator[InMemoryEventCatalogRepository]:
    repository = InMemoryEventCatalogRepository()
    repository.add(_event("near", latitude=BORDER.latitude, longitude=BORDER.longitude))
    repository.add(_event("world", country="FR", level="international"))
    monkeypatch.setattr(get_container(), "_event_catalog_repository", repository)
    yield repository


def _ask(**params: str) -> dict[str, Any]:
    response = TestClient(app).get(
        "/events",
        params={
            "country": "IT",
            "from": date.today().isoformat(),
            "to": (date.today() + timedelta(days=30)).isoformat(),
            **params,
        },
    )
    assert response.status_code == 200
    body: dict[str, Any] = response.json()
    return body


def _save_home(owner_id: str, home: Coordinates | None) -> None:
    get_container().user_location_repository.save(
        UserLocation(owner_id=owner_id, mode="home_residence", home=home)
    )


@pytest.fixture
def me() -> Iterator[str]:
    owner_id = get_container().auth_provider.get_current_user().id
    yield owner_id
    _save_home(owner_id, None)


def test_the_saved_localita_decides_and_nothing_of_it_is_in_the_answer(
    catalogue: InMemoryEventCatalogRepository, me: str
) -> None:
    _save_home(me, BORDER)

    body = _ask(abroad="true")

    assert [event["id"] for event in body["events"]] == ["near", "world"]
    assert body["abroad_radius_km"] == 30
    assert str(BORDER.latitude) not in str(body)
    assert str(BORDER.longitude) not in str(body)


def test_a_position_in_the_request_is_ignored(
    catalogue: InMemoryEventCatalogRepository, me: str
) -> None:
    body = _ask(abroad="true", latitude="45.83", longitude="9.03")

    assert [event["id"] for event in body["events"]] == ["world"]


def test_the_localita_of_user_b_changes_nothing_for_user_a(
    catalogue: InMemoryEventCatalogRepository, me: str
) -> None:
    _save_home("user-b", BORDER)
    try:
        body = _ask(abroad="true", owner_id="user-b", abroad_for_owner="user-b")
    finally:
        _save_home("user-b", None)

    assert [event["id"] for event in body["events"]] == ["world"]


def test_an_app_that_does_not_ask_gets_the_country_and_the_answer_of_before(
    catalogue: InMemoryEventCatalogRepository, me: str
) -> None:
    _save_home(me, BORDER)

    assert _ask() == {"events": [], "country_has_events": False}
