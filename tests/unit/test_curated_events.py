import json
from datetime import date
from pathlib import Path
from typing import Any

import pytest

from packages.infrastructure.events.curated_events import (
    DEFAULT_LICENSE,
    CuratedEventError,
    curated_event_to_row,
    load_curated_events,
    validate_curated_event,
)

TODAY = date(2026, 10, 4)


def _raw(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "slug": "esempio-fiera-2026",
        "title": "Fiera di esempio",
        "event_type": "pet_fair",
        "level": "national",
        "level_basis": "official_qualification",
        "starts_on": "2026-10-17",
        "ends_on": "2026-10-18",
        "region": "Lombardia",
        "city": "Cremona",
        "province_code": "CR",
        "organizer_name": "Ente Fiera Esempio",
        "source_url": "https://www.example.org/fiera",
        "verified_on": "2026-10-04",
    }
    base.update(overrides)
    return base


def test_a_complete_event_is_accepted() -> None:
    event = validate_curated_event(_raw(), today=TODAY)

    assert event.slug == "esempio-fiera-2026"
    assert event.starts_on == date(2026, 10, 17)
    assert event.status == "published"


@pytest.mark.parametrize(
    "field",
    [
        "slug",
        "title",
        "event_type",
        "level",
        "level_basis",
        "starts_on",
        "ends_on",
        "source_url",
        "verified_on",
    ],
)
def test_every_required_field_is_enforced(field: str) -> None:
    raw = _raw()
    del raw[field]

    with pytest.raises(CuratedEventError, match=field):
        validate_curated_event(raw, today=TODAY)


@pytest.mark.parametrize("blank", ["", "   ", None])
def test_a_blank_source_url_is_rejected_so_no_link_is_invented(blank: str | None) -> None:
    with pytest.raises(CuratedEventError, match="source_url"):
        validate_curated_event(_raw(source_url=blank), today=TODAY)


@pytest.mark.parametrize(
    "url",
    [
        "https://www.facebook.com/events/123",
        "https://m.facebook.com/x",
        "https://www.instagram.com/p/abc",
        "https://www.eventbrite.it/e/123",
        "https://www.meetup.com/group",
        "javascript:alert(1)",
        "ftp://example.org/file",
        "solo testo",
    ],
)
def test_social_networks_and_non_http_links_are_not_accepted_sources(url: str) -> None:
    with pytest.raises(CuratedEventError, match="source_url"):
        validate_curated_event(_raw(source_url=url), today=TODAY)


def test_level_without_a_document_cannot_exceed_the_cap() -> None:
    with pytest.raises(CuratedEventError, match="organizer_claim"):
        validate_curated_event(
            _raw(level="international", level_basis="organizer_claim"), today=TODAY
        )
    with pytest.raises(CuratedEventError, match="default"):
        validate_curated_event(_raw(level="regional", level_basis="default"), today=TODAY)

    allowed = validate_curated_event(
        _raw(level="regional", level_basis="organizer_claim"), today=TODAY
    )
    assert allowed.level == "regional"


def test_a_documented_basis_allows_national_and_international() -> None:
    for basis in ("official_qualification", "federation_title", "declared_metrics", "curated"):
        event = validate_curated_event(_raw(level="international", level_basis=basis), today=TODAY)
        assert event.level == "international"


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"slug": "Maiuscole E Spazi"}, "slug"),
        ({"event_type": "rave"}, "event_type"),
        ({"level": "galactic"}, "level"),
        ({"level_basis": "vibes"}, "level_basis"),
        ({"status": "maybe"}, "status"),
        ({"region": "Atlantide"}, "region"),
        ({"province_code": "cremona"}, "province_code"),
        ({"starts_on": "17/10/2026"}, "starts_on"),
        ({"ends_on": "2026-10-16"}, "ends_on"),
        ({"verified_on": "2026-12-01"}, "futuro"),
    ],
)
def test_malformed_values_are_rejected(overrides: dict[str, Any], message: str) -> None:
    with pytest.raises(CuratedEventError, match=message):
        validate_curated_event(_raw(**overrides), today=TODAY)


def test_an_event_needs_a_place_to_show() -> None:
    with pytest.raises(CuratedEventError, match="city o region"):
        validate_curated_event(_raw(city=None, region=None, province_code=None), today=TODAY)

    only_region = validate_curated_event(_raw(city=None, province_code=None), today=TODAY)
    assert only_region.region == "Lombardia"


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("organizer_name", "Mario Rossi 333 123 4567"),
        ("organizer_name", "info@fiera.example"),
        ("description", "Chiama il 02 1234 5678 per informazioni"),
        ("venue_name", "scrivi a segreteria@example.org"),
    ],
)
def test_contacts_never_enter_the_public_repository(field: str, value: str) -> None:
    with pytest.raises(CuratedEventError, match="telefono|email"):
        validate_curated_event(_raw(**{field: value}), today=TODAY)


def test_dates_and_years_in_text_are_not_mistaken_for_phone_numbers() -> None:
    event = validate_curated_event(_raw(description="Edizione 2026, 17-18 ottobre"), today=TODAY)

    assert event.description == "Edizione 2026, 17-18 ottobre"


def test_row_carries_the_curators_verification_day_not_the_import_day() -> None:
    event = validate_curated_event(_raw(verified_on="2026-10-03"), today=TODAY)

    row = curated_event_to_row(event, now_iso="2026-10-04T10:00:00+00:00")

    assert row["last_verified_at"].startswith("2026-10-03")
    assert row["updated_at"] == "2026-10-04T10:00:00+00:00"
    assert row["verification_status"] == "verified"
    assert row["audience"] == "public"
    assert row["source"] == "curated"
    assert row["license"] == DEFAULT_LICENSE
    assert row["source_url"] == "https://www.example.org/fiera"
    assert "phone" not in row
    assert "email" not in row


def _write(directory: Path, name: str, document: object) -> None:
    (directory / name).write_text(json.dumps(document), encoding="utf-8")


def test_loading_keeps_good_events_and_reports_each_bad_one(tmp_path: Path) -> None:
    _write(tmp_path, "a.json", {"events": [_raw(), _raw(slug="altro", level="galactic")]})
    _write(tmp_path, "b.json", [_raw(slug="terzo")])

    events, problems = load_curated_events(tmp_path, today=TODAY)

    assert {event.slug for event in events} == {"esempio-fiera-2026", "terzo"}
    assert len(problems) == 1
    assert "a.json #2" in problems[0]
    assert "level" in problems[0]


def test_a_slug_repeated_across_files_is_reported(tmp_path: Path) -> None:
    _write(tmp_path, "a.json", {"events": [_raw()]})
    _write(tmp_path, "b.json", {"events": [_raw()]})

    events, problems = load_curated_events(tmp_path, today=TODAY)

    assert len(events) == 1
    assert any("duplicato" in problem and "b.json" in problem for problem in problems)


def test_unreadable_or_misshapen_files_are_reported_not_fatal(tmp_path: Path) -> None:
    (tmp_path / "broken.json").write_text("{ not json", encoding="utf-8")
    _write(tmp_path, "shape.json", {"events": "nope"})
    _write(tmp_path, "ok.json", {"events": [_raw()]})

    events, problems = load_curated_events(tmp_path, today=TODAY)

    assert len(events) == 1
    assert len(problems) == 2


def test_an_empty_directory_is_valid_and_yields_nothing(tmp_path: Path) -> None:
    events, problems = load_curated_events(tmp_path, today=TODAY)

    assert events == []
    assert problems == []


def test_a_non_object_entry_is_reported(tmp_path: Path) -> None:
    _write(tmp_path, "a.json", {"events": ["una stringa", 3, None]})

    events, problems = load_curated_events(tmp_path, today=TODAY)

    assert events == []
    assert len(problems) == 3
