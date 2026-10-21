"""A suggestion of a user for the "Eventi" section ("Segnala un evento").

It is a proposal, not an event: it waits in a moderation queue until the team
has checked the date and the link on the organizer's page, and only then does
it become a row of the public `events` table (scripts/events/moderate_submissions.py).
The author is kept only to limit abuse and is never shown; the form takes facts
about the event, not about people, and refuses emails and phone numbers.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Literal
from urllib.parse import urlparse

from pydantic import BaseModel

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.events.rules import EVENT_TYPES, REGIONS, contains_personal_data
from packages.shared.errors.base import ValidationError

SubmissionStatus = Literal["pending", "approved", "rejected"]

MAX_SUBMISSIONS_PER_DAY = 3
MIN_TITLE_LENGTH = 4
MAX_TITLE_LENGTH = 120
MAX_PLACE_LENGTH = 80
MAX_URL_LENGTH = 300
# Far enough to cover next year's editions, near enough to catch typos.
MAX_DAYS_AHEAD = 730
MAX_DURATION_DAYS = 31


class EventSubmission(BaseModel):
    id: str
    submitted_by: str
    title: str
    event_type: str
    starts_on: date
    ends_on: date
    city: str
    province_code: str | None = None
    region: str | None = None
    venue_name: str | None = None
    source_url: str
    status: SubmissionStatus = "pending"
    review_note: str | None = None
    event_slug: str | None = None
    created_at: datetime
    reviewed_at: datetime | None = None


def _clean(value: str | None, *, label: str, max_length: int, required: bool = False) -> str | None:
    text = " ".join((value or "").split())
    if not text:
        if required:
            raise ValidationError(f"{label}: campo obbligatorio")
        return None
    if len(text) > max_length:
        raise ValidationError(f"{label}: massimo {max_length} caratteri")
    if contains_personal_data(text):
        raise ValidationError(
            f"{label}: non inserire email o numeri di telefono, solo informazioni sull'evento"
        )
    return text


def build_submission(
    *,
    owner_id: str,
    title: str,
    event_type: str,
    starts_on: date,
    ends_on: date,
    city: str,
    source_url: str,
    province_code: str | None = None,
    region: str | None = None,
    venue_name: str | None = None,
    today: date | None = None,
) -> EventSubmission:
    """Checks a suggestion and returns it as a pending submission, or raises
    `ValidationError` with a message that can be shown to the user."""
    reference_day = today or utc_now().date()

    clean_title = _clean(title, label="Titolo", max_length=MAX_TITLE_LENGTH, required=True)
    clean_city = _clean(city, label="Città", max_length=MAX_PLACE_LENGTH, required=True)
    clean_venue = _clean(venue_name, label="Luogo", max_length=MAX_PLACE_LENGTH)
    assert clean_title is not None and clean_city is not None
    if len(clean_title) < MIN_TITLE_LENGTH:
        raise ValidationError("Titolo: troppo corto")
    if event_type not in EVENT_TYPES:
        raise ValidationError("Tipo di evento non valido")

    if ends_on < starts_on:
        raise ValidationError("La data di fine precede quella di inizio")
    if ends_on < reference_day:
        raise ValidationError("L'evento è già concluso")
    if starts_on > reference_day + timedelta(days=MAX_DAYS_AHEAD):
        raise ValidationError("La data di inizio è troppo lontana")
    if (ends_on - starts_on).days > MAX_DURATION_DAYS:
        raise ValidationError("Un evento dura al massimo 31 giorni")

    province = (province_code or "").strip().upper() or None
    if province is not None and not (len(province) == 2 and province.isalpha()):
        raise ValidationError("Provincia: usa la sigla di due lettere (es. MO)")
    clean_region = (region or "").strip() or None
    if clean_region is not None and clean_region not in REGIONS:
        raise ValidationError("Regione non riconosciuta")

    link = (source_url or "").strip()
    parsed = urlparse(link)
    if (
        not link
        or len(link) > MAX_URL_LENGTH
        or parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or "." not in parsed.hostname
    ):
        raise ValidationError("Link: serve l'indirizzo (http/https) della pagina dell'evento")

    return EventSubmission(
        id=new_id(),
        submitted_by=owner_id,
        title=clean_title,
        event_type=event_type,
        starts_on=starts_on,
        ends_on=ends_on,
        city=clean_city,
        province_code=province,
        region=clean_region,
        venue_name=clean_venue,
        source_url=link,
        created_at=utc_now(),
    )
