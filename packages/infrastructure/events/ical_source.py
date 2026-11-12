"""Events from a public iCalendar (.ics) feed published by an organizer, a
fair body or a municipality.

Each feed is described in `scripts/events/sources.json` (address, licence,
terms, the keywords an event must contain, the defaults for what the feed does
not say). Only facts are copied - title, dates, place, link; the feed's own
description text is not stored. Every event goes through the same validation
as the hand-curated ones (`validate_curated_event`), so a feed can never put
into the app what a person could not.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path
from typing import Any


class SourceConfigError(ValueError):
    """`sources.json` does not describe a usable source."""


@dataclass(frozen=True)
class IcalEvent:
    uid: str
    summary: str
    description: str
    location: str
    url: str
    starts_on: date
    ends_on: date


@dataclass(frozen=True)
class FeedSource:
    key: str
    name: str
    url: str
    license: str
    terms_url: str
    checked_on: str
    # An event is taken only if title or description contains one of these.
    # Empty means "every event of the feed" (for feeds that are all about pets).
    keywords: tuple[str, ...] = ()
    # What the feed does not say: at least `city` or `region`; `event_type`,
    # `page_url` (link used when an event has none of its own).
    defaults: dict[str, str] = field(default_factory=dict)
    enabled: bool = False


def load_sources(path: Path) -> list[FeedSource]:
    document = json.loads(path.read_text(encoding="utf-8"))
    sources: list[FeedSource] = []
    for raw in document.get("sources", []):
        try:
            sources.append(
                FeedSource(
                    key=raw["key"],
                    name=raw["name"],
                    url=raw["url"],
                    license=raw["license"],
                    terms_url=raw["terms_url"],
                    checked_on=raw["checked_on"],
                    keywords=tuple(k.casefold() for k in raw.get("keywords", [])),
                    defaults=dict(raw.get("defaults", {})),
                    enabled=bool(raw.get("enabled", False)),
                )
            )
        except KeyError as exc:
            raise SourceConfigError(f"fonte senza il campo {exc}: {raw.get('key', raw)}") from exc
    return sources


def _unfold(text: str) -> list[str]:
    lines: list[str] = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line[:1] in (" ", "\t") and lines:
            lines[-1] += line[1:]
        else:
            lines.append(line)
    return lines


def _unescape(value: str) -> str:
    return (
        value.replace("\\n", " ")
        .replace("\\N", " ")
        .replace("\\,", ",")
        .replace("\\;", ";")
        .replace("\\\\", "\\")
    )


_DATE = re.compile(r"^(\d{4})(\d{2})(\d{2})")


def _to_date(value: str) -> date | None:
    match = _DATE.match(value.strip())
    if match is None:
        return None
    try:
        return date(int(match[1]), int(match[2]), int(match[3]))
    except ValueError:
        return None


def parse_ical(text: str) -> list[IcalEvent]:
    """The VEVENTs of an iCalendar document that have a title and a start."""
    events: list[IcalEvent] = []
    current: dict[str, tuple[str, str]] | None = None
    for line in _unfold(text):
        if line == "BEGIN:VEVENT":
            current = {}
        elif line == "END:VEVENT" and current is not None:
            event = _build(current)
            if event is not None:
                events.append(event)
            current = None
        elif current is not None and ":" in line:
            head, _, value = line.partition(":")
            name, _, params = head.partition(";")
            current.setdefault(name.upper(), (params.upper(), value))
    return events


def _build(fields: dict[str, tuple[str, str]]) -> IcalEvent | None:
    summary = _unescape(fields.get("SUMMARY", ("", ""))[1]).strip()
    start_params, start_value = fields.get("DTSTART", ("", ""))
    starts_on = _to_date(start_value)
    if not summary or starts_on is None:
        return None

    ends_on = starts_on
    if "DTEND" in fields:
        end_params, end_value = fields["DTEND"]
        parsed_end = _to_date(end_value)
        if parsed_end is not None:
            # An all-day DTEND is exclusive: the event ends the day before.
            all_day = "VALUE=DATE" in end_params and "T" not in end_value
            ends_on = parsed_end - timedelta(days=1) if all_day else parsed_end
    ends_on = max(ends_on, starts_on)

    uid = fields.get("UID", ("", ""))[1].strip() or f"{summary}-{starts_on.isoformat()}"
    return IcalEvent(
        uid=uid,
        summary=summary,
        description=_unescape(fields.get("DESCRIPTION", ("", ""))[1]).strip(),
        location=_unescape(fields.get("LOCATION", ("", ""))[1]).strip(),
        url=fields.get("URL", ("", ""))[1].strip(),
        starts_on=starts_on,
        ends_on=ends_on,
    )


def matches_keywords(event: IcalEvent, keywords: tuple[str, ...]) -> bool:
    if not keywords:
        return True
    text = f"{event.summary} {event.description}".casefold()
    return any(keyword in text for keyword in keywords)


def ical_event_to_raw(event: IcalEvent, source: FeedSource, *, today: date) -> dict[str, Any]:
    """The event as the dict `validate_curated_event` expects. Level is always
    `local`/`default`: a feed cannot vouch for an event's reach."""
    digest = hashlib.sha1(event.uid.encode("utf-8")).hexdigest()[:10]  # noqa: S324 - not security
    raw: dict[str, Any] = {
        "slug": f"{source.key}-{digest}",
        "title": event.summary,
        "event_type": source.defaults.get("event_type", "other"),
        "level": "local",
        "level_basis": "default",
        "starts_on": event.starts_on.isoformat(),
        "ends_on": event.ends_on.isoformat(),
        "source_url": event.url or source.defaults.get("page_url"),
        "verified_on": today.isoformat(),
        "status": "published",
        "organizer_name": source.defaults.get("organizer_name"),
        "city": source.defaults.get("city"),
        "province_code": source.defaults.get("province_code"),
        "region": source.defaults.get("region"),
        "venue_name": event.location or None,
    }
    return raw


def is_current(event: IcalEvent, *, today: date) -> bool:
    return event.ends_on >= today and event.starts_on <= today + timedelta(days=548)
