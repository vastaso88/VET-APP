"""The feeds behind "Curiosità per i tuoi animali".

Only feeds that the publisher itself offers for syndication (a public RSS
address, not blocked by its robots.txt) are listed, and only the headline,
the publisher's name, the link and the date are used: no article text, no
pictures. Each source is documented in docs/features/news_and_events_sources.md
(terms, check date, frequency). Google News is deliberately absent: its
robots.txt disallows `/rss` and its Terms of Service forbid automated access
that goes against it (checked 2026-10-21).
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass


@dataclass(frozen=True)
class NewsFeed:
    key: str
    name: str  # shown as the headline's source
    url: str
    # When a feed is mostly about something else, only entries that pass the
    # pet relevance rules are kept anyway; this is documentation for people.
    topic: str
    # ISO 3166-1 alpha-2: only the owners of this country read it.
    country: str


FEEDS: tuple[NewsFeed, ...] = (
    NewsFeed("petsblog", "Petsblog", "https://www.petsblog.it/feed", "cani e gatti", "IT"),
    NewsFeed(
        "amoreaquattrozampe",
        "Amoreaquattrozampe",
        "https://www.amoreaquattrozampe.it/feed/",
        "animali domestici",
        "IT",
    ),
    NewsFeed(
        "veterinari-it", "Veterinari.it", "https://www.veterinari.it/feed", "veterinaria", "IT"
    ),
    NewsFeed("dogalize", "Dogalize", "https://www.dogalize.com/feed/", "cani", "IT"),
    NewsFeed(
        "fnovi", "FNOVI", "https://www.fnovi.it/rss.xml", "federazione ordini veterinari", "IT"
    ),
    NewsFeed(
        "izsve", "IZS delle Venezie", "https://www.izsvenezie.it/feed/", "sanità animale", "IT"
    ),
    NewsFeed(
        "oipa", "OIPA Italia", "https://www.oipa.org/italia/feed/", "protezione animali", "IT"
    ),
)


def feeds_of(country: str, feeds: Sequence[NewsFeed] = FEEDS) -> tuple[NewsFeed, ...]:
    return tuple(feed for feed in feeds if feed.country == country)
