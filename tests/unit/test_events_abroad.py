"""Collaudo F42: which events of another country an owner sees. International ones always; every
other one only within 30 km of the owner's saved Località; never without a Località or without
the coordinates of the event. The position stays on the server."""

import logging
from datetime import date
from typing import Any

import pytest

from packages.core.application.services.get_user_location import GetUserLocationService
from packages.core.application.services.list_events import ListEventsInput, ListEventsService
from packages.core.domain.events.abroad import ABROAD_RADIUS_KM, is_shown_abroad
from packages.core.domain.events.submission import EventSubmission
from packages.core.domain.geo.models import (
    EARTH_RADIUS_KM,
    Coordinates,
    LocationMode,
    UserLocation,
)
from packages.infrastructure.persistence.in_memory_event_catalog import (
    InMemoryEventCatalogRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryUserLocationRepository,
)
from packages.infrastructure.persistence.supabase.supabase_event_catalog import (
    SupabaseEventCatalogRepository,
)
from packages.infrastructure.persistence.supabase.supabase_event_submissions import (
    SupabaseEventSubmissionRepository,
)

OWNER = "owner-a"
STRANGER = "owner-b"
HOME = Coordinates(latitude=45.8, longitude=9.08)
_DEGREE_KM = EARTH_RADIUS_KM * 3.141592653589793 / 180


def _north_of_home(km: float) -> dict[str, float]:
    return {"latitude": HOME.latitude + km / _DEGREE_KM, "longitude": HOME.longitude}


def _event(event_id: str, country: str, **values: object) -> dict[str, Any]:
    return {
        "id": event_id,
        "title": "Fiera",
        "country": country,
        "level": "national",
        "starts_on": "2026-12-05",
        "ends_on": "2026-12-05",
        **values,
    }


def _list(
    *events: dict[str, Any],
    home: Coordinates | None = HOME,
    mode: LocationMode = "home_residence",
    current: Coordinates | None = None,
    asking: str | None = OWNER,
) -> list[dict[str, Any]]:
    catalogue = InMemoryEventCatalogRepository()
    for event in events:
        catalogue.add(event)
    locations = InMemoryUserLocationRepository()
    locations.save(UserLocation(owner_id=OWNER, mode=mode, home=home, current=current))
    return (
        ListEventsService(catalogue, GetUserLocationService(locations))
        .execute(
            ListEventsInput(
                country="it",
                from_day=date(2026, 12, 1),
                to_day=date(2026, 12, 31),
                abroad_for_owner=asking,
            )
        )
        .events
    )


def _ids(events: list[dict[str, Any]]) -> list[str]:
    return [str(event["id"]) for event in events]


def test_the_rule_in_one_place() -> None:
    near, far = Coordinates(**_north_of_home(29.9)), Coordinates(**_north_of_home(30.1))

    assert ABROAD_RADIUS_KM == 30
    for level in ("national", "regional", "provincial", "local", None):
        assert is_shown_abroad(level=level, place=near, owner=HOME)
        assert not is_shown_abroad(level=level, place=far, owner=HOME)
        assert not is_shown_abroad(level=level, place=None, owner=HOME)
        assert not is_shown_abroad(level=level, place=near, owner=None)
    assert is_shown_abroad(level="international", place=None, owner=None)


def test_without_asking_for_more_the_list_is_the_one_of_the_country() -> None:
    events = [
        _event("it", "IT"),
        _event("world", "FR", level="international"),
        _event("near", "CH", **_north_of_home(5)),
    ]

    assert _ids(_list(*events, asking=None)) == ["it"]


def test_own_country_international_and_just_over_the_border() -> None:
    shown = _list(
        _event("it", "IT"),
        _event("world", "FR", level="international"),
        _event("near", "CH", **_north_of_home(29)),
        _event("far", "CH", **_north_of_home(31)),
        _event("somewhere", "CH"),
    )

    assert _ids(shown) == ["it", "world", "near"]
    assert {event["id"]: event.get("near_border") for event in shown} == {
        "it": None,
        "world": False,
        "near": True,
    }


def test_neither_the_coordinates_nor_a_distance_leave_the_server() -> None:
    (event,) = _list(_event("near", "CH", **_north_of_home(10)))

    assert not {"latitude", "longitude", "distance_km"} & set(event)
    assert str(HOME.latitude) not in str(event)


def test_without_a_localita_only_the_international_ones_are_added() -> None:
    shown = _list(
        _event("near", "CH", **_north_of_home(1)),
        _event("world", "FR", level="international"),
        home=None,
    )

    assert _ids(shown) == ["world"]


def test_the_localita_is_the_one_the_owner_chose() -> None:
    milan = Coordinates(latitude=45.46, longitude=9.19)
    near_home = _event("near", "CH", **_north_of_home(29))

    chose_home = _list(near_home, current=milan)
    chose_position = _list(near_home, mode="current_position", current=milan)

    assert (_ids(chose_home), _ids(chose_position)) == (["near"], [])


def test_another_owners_localita_never_counts() -> None:
    near = _event("near", "CH", **_north_of_home(1))

    assert _ids(_list(near)) == ["near"]
    assert _list(near, asking=STRANGER) == []


def test_drafts_professional_events_and_other_periods_stay_out() -> None:
    far_away = {"level": "international"}

    assert (
        _list(
            _event("draft", "FR", status="draft", **far_away),
            _event("trade", "FR", audience="professional", **far_away),
            _event("late", "FR", starts_on="2027-02-01", ends_on="2027-02-01", **far_away),
        )
        == []
    )


def test_the_events_stay_in_order_of_date() -> None:
    shown = _list(
        _event("second", "IT", starts_on="2026-12-06", ends_on="2026-12-06"),
        _event("first", "FR", level="international"),
    )

    assert _ids(shown) == ["first", "second"]


def test_an_unreadable_localita_hides_nothing_else_and_is_not_logged(
    caplog: pytest.LogCaptureFixture,
) -> None:
    class _Broken:
        def get(self, owner_id: str) -> UserLocation | None:
            raise ValueError("home_latitude 45.8 is not valid")

        def save(self, user_location: UserLocation) -> UserLocation:
            return user_location

    catalogue = InMemoryEventCatalogRepository()
    catalogue.add(_event("it", "IT"))
    catalogue.add(_event("near", "CH", **_north_of_home(1)))

    with caplog.at_level(logging.DEBUG):
        shown = (
            ListEventsService(catalogue, GetUserLocationService(_Broken()))
            .execute(
                ListEventsInput(
                    country="IT",
                    from_day=date(2026, 12, 1),
                    to_day=date(2026, 12, 31),
                    abroad_for_owner=OWNER,
                )
            )
            .events
        )

    assert _ids(shown) == ["it"]
    assert "ValueError" in caplog.text
    assert "45.8" not in caplog.text


# --- before the SQL has run ----------------------------------------------------------


class _Query:
    """Records one PostgREST query and answers with [rows]."""

    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows
        self.selected = ""
        self.written: dict[str, Any] = {}

    def table(self, _name: str) -> "_Query":
        return self

    def select(self, columns: str) -> "_Query":
        self.selected = columns
        return self

    def insert(self, row: dict[str, Any]) -> "_Query":
        self.written = row
        return self

    upsert = insert

    def __getattr__(self, _name: str) -> Any:
        return lambda *_args, **_kwargs: self

    @property
    def data(self) -> list[dict[str, Any]]:
        return self.rows


def test_a_database_without_the_coordinates_is_not_asked_for_them() -> None:
    query = _Query([{**_event("world", "FR", level="international"), "slug": "internal"}])
    repository = SupabaseEventCatalogRepository(query)  # type: ignore[arg-type]

    (row,) = repository.list_public_abroad(
        country="IT", from_day=date(2026, 12, 1), to_day=date(2026, 12, 31)
    )

    assert query.selected == "*"
    assert (row["latitude"], row["longitude"]) == (None, None)
    assert "slug" not in row  # bookkeeping stays on the server


@pytest.mark.parametrize(("country", "written"), [("IT", None), ("FR", "FR")])
def test_an_italian_suggestion_is_stored_without_the_new_column(
    country: str, written: str | None
) -> None:
    query = _Query([])
    submission = EventSubmission(
        id="s",
        submitted_by=OWNER,
        title="Fiera",
        event_type="pet_fair",
        starts_on=date(2026, 12, 5),
        ends_on=date(2026, 12, 5),
        country=country,
        city="Nice",
        source_url="https://www.example.org/x",
        created_at="2026-11-25T10:00:00+00:00",  # type: ignore[arg-type]
    )

    SupabaseEventSubmissionRepository(query).add(submission)  # type: ignore[arg-type]
    assert query.written.get("country") == written

    SupabaseEventSubmissionRepository(query).save(submission)  # type: ignore[arg-type]
    assert query.written.get("country") == written
