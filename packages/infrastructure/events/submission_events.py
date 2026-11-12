"""From a user's suggestion to a public event, once the team has checked it."""

from __future__ import annotations

import re
import unicodedata
from datetime import UTC, date, datetime
from typing import Any

from packages.core.domain.events.submission import EventSubmission
from packages.infrastructure.events.curated_events import CuratedEvent, validate_curated_event

SUBMISSION_SOURCE_KEY = "user_submission"
SUBMISSION_LICENSE = (
    "segnalazione di un utente, verificata dal team sulla pagina dell'organizzatore"
)


def slugify(text: str) -> str:
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "-", folded.lower()).strip("-")


def submission_slug(submission: EventSubmission) -> str:
    parts = [slugify(submission.title), slugify(submission.city), str(submission.starts_on.year)]
    slug = "-".join(part for part in parts if part)
    # Keeps the slug readable and unique-enough: two editions of one event in
    # the same year and place would have been one suggestion anyway.
    return slug[:90].rstrip("-")


def submission_to_curated(
    submission: EventSubmission,
    *,
    today: date | None = None,
    source_url: str | None = None,
    slug: str | None = None,
) -> CuratedEvent:
    """The submission as a validated event. Raises `CuratedEventError` when
    the project's rules refuse it (typically a social network as the link:
    pass the organizer's own page as `source_url`). New events from users are
    always `local`/`default`: reach is decided by the team with a document,
    never by a suggestion."""
    checked_on = today or datetime.now(UTC).date()
    raw: dict[str, Any] = {
        "slug": slug or submission_slug(submission),
        "title": submission.title,
        "event_type": submission.event_type,
        "level": "local",
        "level_basis": "default",
        "starts_on": submission.starts_on.isoformat(),
        "ends_on": submission.ends_on.isoformat(),
        "city": submission.city,
        "province_code": submission.province_code,
        "region": submission.region,
        "venue_name": submission.venue_name,
        "source_url": source_url or submission.source_url,
        "verified_on": checked_on.isoformat(),
        "status": "published",
    }
    return validate_curated_event(raw, today=checked_on)
