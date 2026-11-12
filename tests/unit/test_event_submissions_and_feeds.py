from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.services.submit_event import (
    SubmissionLimitReachedError,
    SubmitEventInput,
    SubmitEventService,
)
from packages.core.domain.events.submission import build_submission
from packages.infrastructure.events.curated_events import (
    CuratedEventError,
    curated_event_to_row,
)
from packages.infrastructure.events.ical_source import (
    FeedSource,
    ical_event_to_raw,
    is_current,
    matches_keywords,
    parse_ical,
)
from packages.infrastructure.events.submission_events import (
    SUBMISSION_LICENSE,
    SUBMISSION_SOURCE_KEY,
    submission_to_curated,
)
from packages.infrastructure.persistence.in_memory_event_submissions import (
    InMemoryEventSubmissionRepository,
)
from packages.shared.errors.base import ValidationError

TODAY = date(2026, 10, 21)


def _fields(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "owner_id": "user-1",
        "title": "Giornata dell'adozione",
        "event_type": "adoption_day",
        "starts_on": date(2026, 11, 14),
        "ends_on": date(2026, 11, 14),
        "city": "Modena",
        "province_code": "mo",
        "region": "Emilia-Romagna",
        "venue_name": "Parco Ferrari",
        "source_url": "https://www.example.org/adozioni",
    }
    base.update(overrides)
    return base


def test_a_valid_suggestion_becomes_a_pending_submission() -> None:
    submission = build_submission(**_fields(), today=TODAY)

    assert submission.status == "pending"
    assert submission.province_code == "MO"
    assert submission.submitted_by == "user-1"


@pytest.mark.parametrize(
    "overrides",
    [
        {"title": ""},
        {"title": "Chiamami al 333 1234567"},
        {"venue_name": "scrivi a mario@example.org"},
        {"event_type": "rave_party"},
        {"ends_on": date(2026, 11, 1)},
        {"starts_on": date(2026, 1, 1), "ends_on": date(2026, 1, 2)},
        {"starts_on": date(2030, 1, 1), "ends_on": date(2030, 1, 2)},
        {"ends_on": date(2026, 12, 31)},
        {"province_code": "MOD"},
        {"region": "Atlantide"},
        {"source_url": "ftp://example.org/x"},
        {"source_url": ""},
        {"city": ""},
    ],
)
def test_invalid_suggestions_are_refused(overrides: dict[str, Any]) -> None:
    with pytest.raises(ValidationError):
        build_submission(**_fields(**overrides), today=TODAY)


def test_daily_limit_per_owner() -> None:
    repository = InMemoryEventSubmissionRepository()
    service = SubmitEventService(repository)
    payload = {k: v for k, v in _fields().items()}
    payload["starts_on"] = date.today() + timedelta(days=30)
    payload["ends_on"] = date.today() + timedelta(days=30)

    for _ in range(3):
        service.execute(SubmitEventInput(**payload))
    with pytest.raises(SubmissionLimitReachedError):
        service.execute(SubmitEventInput(**payload))

    other = dict(payload, owner_id="user-2")
    service.execute(SubmitEventInput(**other))
    assert len(repository.list_pending()) == 4


def test_approved_submission_is_a_local_event_with_its_own_source() -> None:
    submission = build_submission(**_fields(), today=TODAY)

    event = submission_to_curated(submission, today=TODAY)
    row = curated_event_to_row(
        event,
        now_iso="2026-10-21T00:00:00+00:00",
        source=SUBMISSION_SOURCE_KEY,
        license_text=SUBMISSION_LICENSE,
    )

    assert event.slug == "giornata-dell-adozione-modena-2026"
    assert (row["level"], row["level_basis"]) == ("local", "default")
    assert row["source"] == "user_submission"
    assert "user-1" not in str(row.values())


def test_social_links_cannot_be_published_without_the_organizers_page() -> None:
    submission = build_submission(
        **_fields(source_url="https://www.facebook.com/events/123"),
        today=TODAY,
    )

    with pytest.raises(CuratedEventError):
        submission_to_curated(submission, today=TODAY)
    event = submission_to_curated(
        submission, today=TODAY, source_url="https://www.example.org/ufficiale"
    )
    assert event.source_url == "https://www.example.org/ufficiale"


ICS = """BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:abc-1@example.org
SUMMARY:Raduno cani\\, razze da pastore
DTSTART;VALUE=DATE:20261128
DTEND;VALUE=DATE:20261130
LOCATION:Parco della Resistenza
URL:https://www.example.org/raduno
DESCRIPTION:Una giornata
  per i cani
END:VEVENT
BEGIN:VEVENT
UID:abc-2@example.org
SUMMARY:Concerto di Natale
DTSTART:20261220T210000Z
END:VEVENT
BEGIN:VEVENT
UID:old
SUMMARY:Gatti in mostra
DTSTART:20250101T100000Z
END:VEVENT
END:VCALENDAR
"""

SOURCE = FeedSource(
    key="comune-esempio",
    name="Comune di Esempio",
    url="https://www.example.org/eventi.ics",
    license="CC BY 4.0",
    terms_url="https://www.example.org/termini",
    checked_on="2026-10-21",
    keywords=("cani", "gatti"),
    defaults={"event_type": "dog_show", "city": "Esempio", "region": "Lombardia"},
    enabled=True,
)


def test_parse_ical_handles_folding_escapes_and_all_day_ends() -> None:
    events = parse_ical(ICS)

    assert [e.summary for e in events] == [
        "Raduno cani, razze da pastore",
        "Concerto di Natale",
        "Gatti in mostra",
    ]
    assert events[0].ends_on == date(2026, 11, 29)  # all-day DTEND is exclusive
    assert events[0].description == "Una giornata per i cani"
    assert events[1].ends_on == events[1].starts_on


def test_feed_events_are_filtered_and_converted() -> None:
    from packages.infrastructure.events.curated_events import validate_curated_event

    current = [e for e in parse_ical(ICS) if is_current(e, today=TODAY)]
    kept = [e for e in current if matches_keywords(e, SOURCE.keywords)]

    assert [e.uid for e in kept] == ["abc-1@example.org"]
    raw = ical_event_to_raw(kept[0], SOURCE, today=TODAY)
    event = validate_curated_event(raw, today=TODAY)
    assert event.level == "local" and event.region == "Lombardia"
    assert event.source_url == "https://www.example.org/raduno"
    assert datetime(2026, 10, 21, tzinfo=UTC).date() == TODAY
