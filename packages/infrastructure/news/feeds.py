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

from dataclasses import dataclass


@dataclass(frozen=True)
class NewsFeed:
    key: str
    name: str  # shown as the headline's source
    url: str
    # When a feed is mostly about something else, only entries that pass the
    # pet relevance rules are kept anyway; this is documentation for people.
    topic: str


ITALIAN_FEEDS: tuple[NewsFeed, ...] = (
    NewsFeed("petsblog", "Petsblog", "https://www.petsblog.it/feed", "cani e gatti"),
    NewsFeed(
        "amoreaquattrozampe",
        "Amoreaquattrozampe",
        "https://www.amoreaquattrozampe.it/feed/",
        "animali domestici",
    ),
    NewsFeed("veterinari-it", "Veterinari.it", "https://www.veterinari.it/feed", "veterinaria"),
    NewsFeed("dogalize", "Dogalize", "https://www.dogalize.com/feed/", "cani"),
    NewsFeed("fnovi", "FNOVI", "https://www.fnovi.it/rss.xml", "federazione ordini veterinari"),
    NewsFeed("izsve", "IZS delle Venezie", "https://www.izsvenezie.it/feed/", "sanità animale"),
    NewsFeed("oipa", "OIPA Italia", "https://www.oipa.org/italia/feed/", "protezione animali"),
)

FEEDS_BY_AUDIENCE: dict[str, tuple[NewsFeed, ...]] = {"it": ITALIAN_FEEDS}
