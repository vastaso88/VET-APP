"""The "Curiosità per i tuoi animali" headlines: what the app shows and how
a raw feed entry becomes one of them.

Only the headline, the name of the publisher, the link and the date are kept:
the text of an article and its pictures stay on the publisher's site.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta
from urllib.parse import urlparse

from pydantic import BaseModel

# Every category the app ever asks for (the owned-species labels plus the
# cross-species catch-alls). The values are technical keys shared with the
# Flutter client (`allPetNewsCategories`), not display text.
NEWS_CATEGORIES: tuple[str, ...] = (
    "Cane",
    "Gatto",
    "Piccoli mammiferi",
    "Uccello",
    "Rettili e anfibi",
    "Pesce",
    "Altro",
    "Generale",
)

# Headlines older than this are dropped when a snapshot is rebuilt: the
# section is "curiosità", not an archive.
MAX_ITEM_AGE = timedelta(days=21)
MAX_ITEMS_PER_CATEGORY = 30
# One prolific publisher must not fill a whole section.
MAX_ITEMS_PER_SOURCE_PER_CATEGORY = 8

_MAX_TITLE_LENGTH = 220
_MAX_SOURCE_LENGTH = 80

# Any run of non-letters/digits: titles are compared with these removed so
# "Cane, salvato!" and "cane salvato" count as the same headline.
_NON_ALNUM = re.compile(r"[\W_]+", re.UNICODE)


class RawNewsEntry(BaseModel):
    """A feed entry before classification."""

    title: str
    summary: str = ""
    source: str
    url: str
    published_at: datetime | None = None


class PetNewsEntry(BaseModel):
    """One headline as the app shows it."""

    category: str
    title: str
    source: str
    url: str
    published_at: datetime | None = None

    @property
    def dedup_key(self) -> str:
        return _NON_ALNUM.sub("", self.title.casefold())

    def is_expired(self, now: datetime) -> bool:
        return self.published_at is not None and now - self.published_at > MAX_ITEM_AGE


class PetNewsSnapshot(BaseModel):
    """Everything the section shows, for one audience (`key`, today "it").

    A snapshot is rebuilt as a whole from the feeds and kept in the shared
    cache; `fetched_at` is when the feeds were last read successfully.
    """

    key: str
    fetched_at: datetime
    items: list[PetNewsEntry]

    def for_category(self, category: str, limit: int) -> list[PetNewsEntry]:
        return [item for item in self.items if item.category == category][:limit]


def clean_title(raw: str) -> str:
    """Single-spaced, bounded headline text."""
    text = " ".join(raw.split())
    return text[:_MAX_TITLE_LENGTH].rstrip()


def clean_source(raw: str) -> str:
    return " ".join(raw.split())[:_MAX_SOURCE_LENGTH]


def is_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in ("http", "https") and bool(parsed.hostname)


def merge_entries(
    fresh: list[PetNewsEntry], previous: list[PetNewsEntry], *, now: datetime
) -> list[PetNewsEntry]:
    """Newest first, one entry per headline per category, expired ones gone,
    at most [MAX_ITEMS_PER_CATEGORY] per category. `previous` keeps a category
    that the latest read of the feeds did not mention from emptying out."""
    seen: set[tuple[str, str]] = set()
    kept: list[PetNewsEntry] = []
    # Undated entries sort as the oldest, as the app already did.
    oldest = datetime.min.replace(tzinfo=now.tzinfo)
    ordered = sorted(
        [*fresh, *previous], key=lambda item: item.published_at or oldest, reverse=True
    )
    per_category: dict[str, int] = {}
    per_source: dict[tuple[str, str], int] = {}
    for item in ordered:
        if item.is_expired(now):
            continue
        marker = (item.category, item.dedup_key)
        source_marker = (item.category, item.source)
        if (
            marker in seen
            or per_category.get(item.category, 0) >= MAX_ITEMS_PER_CATEGORY
            or per_source.get(source_marker, 0) >= MAX_ITEMS_PER_SOURCE_PER_CATEGORY
        ):
            continue
        seen.add(marker)
        per_source[source_marker] = per_source.get(source_marker, 0) + 1
        per_category[item.category] = per_category.get(item.category, 0) + 1
        kept.append(item)
    return kept
