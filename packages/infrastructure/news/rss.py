"""A small, defensive RSS 2.0 / Atom reader.

Feeds are third-party input: they are size-capped before parsing and refused
when they declare a DTD or entities (the usual XML bomb vector), so the
standard library parser is safe to use on them.
"""

from __future__ import annotations

import html
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from email.utils import parsedate_to_datetime
from xml.etree import ElementTree

MAX_FEED_BYTES = 2_000_000
_TAG = re.compile(r"<[^>]+>")
_ATOM = "{http://www.w3.org/2005/Atom}"
_MAX_SUMMARY = 400


class FeedError(ValueError):
    """The document is not a feed we are willing to read."""


@dataclass(frozen=True)
class FeedEntry:
    title: str
    summary: str
    url: str
    published_at: datetime | None


def _text(element: ElementTree.Element | None) -> str:
    if element is None or element.text is None:
        return ""
    return element.text.strip()


def strip_markup(value: str) -> str:
    return " ".join(html.unescape(_TAG.sub(" ", value)).split())


def parse_feed_date(raw: str) -> datetime | None:
    value = raw.strip()
    if not value:
        return None
    try:
        parsed = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=UTC)


def parse_feed(payload: bytes) -> list[FeedEntry]:
    """Entries of an RSS or Atom document, in feed order."""
    if len(payload) > MAX_FEED_BYTES:
        raise FeedError("feed troppo grande")
    head = payload[:4096].lower()
    if b"<!doctype" in head or b"<!entity" in payload[:65536].lower():
        raise FeedError("feed con DTD o entità: rifiutato")
    try:
        root = ElementTree.fromstring(payload)  # noqa: S314 - DTD/entities refused above
    except ElementTree.ParseError as exc:
        raise FeedError(f"XML non valido: {exc}") from exc

    entries: list[FeedEntry] = []
    for item in root.iter("item"):
        entries.append(
            _entry(
                title=_text(item.find("title")),
                summary=_text(item.find("description")),
                url=_text(item.find("link")),
                date=_text(item.find("pubDate"))
                or _text(item.find("{http://purl.org/dc/elements/1.1/}date")),
            )
        )
    for item in root.iter(f"{_ATOM}entry"):
        link = ""
        for candidate in item.findall(f"{_ATOM}link"):
            if candidate.get("rel", "alternate") == "alternate":
                link = candidate.get("href", "")
                break
        entries.append(
            _entry(
                title=_text(item.find(f"{_ATOM}title")),
                summary=_text(item.find(f"{_ATOM}summary")),
                url=link,
                date=_text(item.find(f"{_ATOM}published")) or _text(item.find(f"{_ATOM}updated")),
            )
        )
    return [entry for entry in entries if entry.title and entry.url]


def _entry(*, title: str, summary: str, url: str, date: str) -> FeedEntry:
    return FeedEntry(
        title=strip_markup(title),
        summary=strip_markup(summary)[:_MAX_SUMMARY],
        url=url.strip(),
        published_at=parse_feed_date(date),
    )
