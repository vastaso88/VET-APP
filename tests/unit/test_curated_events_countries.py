from datetime import date
from pathlib import Path
from typing import Any

import pytest

from packages.infrastructure.events.curated_events import (
    CuratedEventError,
    curated_event_to_row,
    load_curated_events,
    validate_curated_event,
)
from packages.infrastructure.events.event_regions import COUNTRIES, REGIONS_BY_COUNTRY

TODAY = date(2026, 10, 14)
EXAMPLES = Path(__file__).resolve().parents[2] / "scripts" / "events" / "examples"


def _raw(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "slug": "example-gb-fair",
        "title": "Example fair",
        "event_type": "pet_fair",
        "level": "regional",
        "level_basis": "curated",
        "country": "GB",
        "starts_on": "2026-11-14",
        "ends_on": "2026-11-15",
        "region": "England",
        "city": "Exampleton",
        "source_url": "https://www.example.org/fair",
        "verified_on": "2026-10-14",
    }
    base.update(overrides)
    return base


def test_an_event_without_country_is_italian() -> None:
    raw = _raw(region="Lombardia", city="Cremona", province_code="CR")
    del raw["country"]

    event = validate_curated_event(raw, today=TODAY)

    assert event.country == "IT"
    assert curated_event_to_row(event, now_iso="2026-10-14T00:00:00+00:00")["country"] == "IT"


def test_the_country_is_normalised_and_written_to_the_row() -> None:
    event = validate_curated_event(_raw(country="gb"), today=TODAY)

    assert event.country == "GB"
    assert curated_event_to_row(event, now_iso="2026-10-14T00:00:00+00:00")["country"] == "GB"


def test_an_unhandled_country_is_refused() -> None:
    with pytest.raises(CuratedEventError, match="country"):
        validate_curated_event(_raw(country="ZZ"), today=TODAY)


def test_every_variant_country_has_regions() -> None:
    assert {"IT", "GB", "US", "AU", "DE", "FR", "ES"} <= COUNTRIES
    for country in COUNTRIES:
        assert REGIONS_BY_COUNTRY[country], country


@pytest.mark.parametrize(
    ("country", "region"),
    [
        ("GB", "Scotland"),
        ("US", "California"),
        ("AU", "Queensland"),
        ("DE", "Nordrhein-Westfalen"),
        ("FR", "Occitanie"),
        ("ES", "Andalucía"),
        ("IT", "Veneto"),
    ],
)
def test_a_region_of_the_right_country_is_accepted(country: str, region: str) -> None:
    event = validate_curated_event(_raw(country=country, region=region), today=TODAY)

    assert event.region == region


@pytest.mark.parametrize(
    ("country", "region"),
    [
        ("GB", "Lombardia"),
        ("IT", "Bayern"),
        ("DE", "California"),
        ("FR", "England"),
        ("ES", "Occitanie"),
        ("US", "Queensland"),
    ],
)
def test_a_region_of_another_country_is_refused(country: str, region: str) -> None:
    with pytest.raises(CuratedEventError, match="region"):
        validate_curated_event(_raw(country=country, region=region), today=TODAY)


@pytest.mark.parametrize(
    ("country", "code", "ok"),
    [
        ("IT", "MI", True),
        ("IT", "Milano", False),
        ("IT", "75", False),
        ("US", "CA", True),
        ("AU", "NSW", True),
        ("FR", "75", True),
        ("FR", "2A", True),
        ("ES", "M", True),
        ("DE", "Bayern", False),
        ("GB", "ab", False),
    ],
)
def test_subdivision_codes_follow_the_country(country: str, code: str, ok: bool) -> None:
    raw = _raw(country=country, region=None, province_code=code)
    if ok:
        assert validate_curated_event(raw, today=TODAY).province_code == code
    else:
        with pytest.raises(CuratedEventError, match="province_code"):
            validate_curated_event(raw, today=TODAY)


def test_every_variant_country_has_a_fictional_seed_that_validates() -> None:
    events, problems = load_curated_events(EXAMPLES, today=TODAY)

    assert problems == []
    assert {event.country for event in events} >= {"IT", "GB", "US", "AU", "DE", "FR", "ES"}
    per_country = {country: [e for e in events if e.country == country] for country in COUNTRIES}
    assert all(per_country[country] for country in ("IT", "GB", "US", "AU", "DE", "FR", "ES"))


def test_the_seeds_are_clearly_fictional_and_hold_no_real_person_or_site() -> None:
    events, _ = load_curated_events(EXAMPLES, today=TODAY)

    assert events
    for event in events:
        assert event.slug.startswith("example-"), event.slug
        assert event.source_url.startswith("https://www.example.org/"), event.source_url
        assert event.description, event.slug  # the description says the event does not exist
        assert "@" not in (event.organizer_name or "")


def test_the_seed_file_of_a_country_only_holds_events_of_that_country() -> None:
    for path in sorted(EXAMPLES.glob("*.json")):
        events, problems = load_curated_events(path.parent, today=TODAY)
        assert problems == []
        for event in events:
            if event.slug.startswith(f"example-{path.stem.lower()}-"):
                assert event.country == path.stem, (path.name, event.slug)
