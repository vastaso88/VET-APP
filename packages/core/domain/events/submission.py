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
from packages.core.domain.events.regions import COUNTRIES, DEFAULT_COUNTRY, regions_of
from packages.core.domain.events.rules import (
    EVENT_TYPES,
    contains_personal_data,
    is_valid_subdivision,
)
from packages.core.domain.localized_errors import LocalizedValidationError, TextKey

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
    country: str = DEFAULT_COUNTRY
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
    """[label] is the key of the field's name in the text catalogue (event_label_*): the refusals
    are written in the language of whoever asked (LocalizedValidationError)."""
    text = " ".join((value or "").split())
    if not text:
        if required:
            raise LocalizedValidationError("event_field_required", label=TextKey(label))
        return None
    if len(text) > max_length:
        raise LocalizedValidationError("event_field_too_long", label=TextKey(label), max=max_length)
    if contains_personal_data(text):
        raise LocalizedValidationError("event_field_personal", label=TextKey(label))
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
    country: str | None = None,
    province_code: str | None = None,
    region: str | None = None,
    venue_name: str | None = None,
    today: date | None = None,
) -> EventSubmission:
    """Checks a suggestion and returns it as a pending submission, or raises
    `ValidationError` with a message that can be shown to the user. Without a
    country (an app that does not ask for it yet) the event is Italian."""
    reference_day = today or utc_now().date()

    clean_title = _clean(
        title, label="event_label_title", max_length=MAX_TITLE_LENGTH, required=True
    )
    clean_city = _clean(city, label="event_label_city", max_length=MAX_PLACE_LENGTH, required=True)
    clean_venue = _clean(venue_name, label="event_label_venue", max_length=MAX_PLACE_LENGTH)
    assert clean_title is not None and clean_city is not None
    if len(clean_title) < MIN_TITLE_LENGTH:
        raise LocalizedValidationError("event_title_short")
    if event_type not in EVENT_TYPES:
        raise LocalizedValidationError("event_type_invalid")

    if ends_on < starts_on:
        raise LocalizedValidationError("event_end_before_start")
    if ends_on < reference_day:
        raise LocalizedValidationError("event_already_over")
    if starts_on > reference_day + timedelta(days=MAX_DAYS_AHEAD):
        raise LocalizedValidationError("event_start_too_far")
    if (ends_on - starts_on).days > MAX_DURATION_DAYS:
        raise LocalizedValidationError("event_duration_too_long")

    clean_country = (country or DEFAULT_COUNTRY).strip().upper()
    if clean_country not in COUNTRIES:
        raise LocalizedValidationError("event_country_invalid")
    province = (province_code or "").strip().upper() or None
    if province is not None and not is_valid_subdivision(clean_country, province):
        raise LocalizedValidationError("event_province_invalid")
    clean_region = (region or "").strip() or None
    if clean_region is not None and clean_region not in regions_of(clean_country):
        raise LocalizedValidationError("event_region_invalid")

    link = (source_url or "").strip()
    parsed = urlparse(link)
    if (
        not link
        or len(link) > MAX_URL_LENGTH
        or parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or "." not in parsed.hostname
    ):
        raise LocalizedValidationError("event_link_invalid")

    return EventSubmission(
        id=new_id(),
        submitted_by=owner_id,
        title=clean_title,
        event_type=event_type,
        starts_on=starts_on,
        ends_on=ends_on,
        country=clean_country,
        city=clean_city,
        province_code=province,
        region=clean_region,
        venue_name=clean_venue,
        source_url=link,
        created_at=utc_now(),
    )
