from __future__ import annotations

import logging
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from concurrent.futures import ThreadPoolExecutor
from urllib.error import URLError

from packages.core.application.ports.pet_news import PetNewsUnavailableError
from packages.core.domain.pet_news.models import RawNewsEntry
from packages.infrastructure.news.feeds import FEEDS_BY_AUDIENCE, NewsFeed
from packages.infrastructure.news.rss import MAX_FEED_BYTES, FeedError, parse_feed

logger = logging.getLogger(__name__)

# Identifies us to the publishers so they can tell what is reading their feed.
USER_AGENT = "VetApp-NewsReader/1.0 (+headlines and links only; https://vet-app.vercel.app)"
_TIMEOUT_SECONDS = 6
_MAX_ENTRIES_PER_FEED = 40

FetchBytes = Callable[[str], bytes]


def fetch_bytes(url: str) -> bytes:
    request = urllib.request.Request(  # noqa: S310 - fixed https feed addresses
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/rss+xml, text/xml, */*"}
    )
    with urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS) as response:  # noqa: S310
        body: bytes = response.read(MAX_FEED_BYTES + 1)
    return body


class HttpPetNewsFeedReader:
    """Reads the registered feeds in parallel (a cold serverless call has a
    few seconds). One broken feed never hides the others."""

    def __init__(
        self,
        *,
        fetch: FetchBytes = fetch_bytes,
        disabled_feed_keys: frozenset[str] = frozenset(),
        feeds_by_audience: Mapping[str, Sequence[NewsFeed]] | None = None,
    ) -> None:
        self._fetch = fetch
        self._disabled = disabled_feed_keys
        self._feeds_by_audience = feeds_by_audience or FEEDS_BY_AUDIENCE

    def read_all(self, key: str) -> list[RawNewsEntry]:
        feeds = [f for f in self._feeds_by_audience.get(key, ()) if f.key not in self._disabled]
        if not feeds:
            raise PetNewsUnavailableError(f"nessun feed attivo per '{key}'")
        with ThreadPoolExecutor(max_workers=min(8, len(feeds))) as pool:
            results = list(pool.map(self._read_one, feeds))
        if all(result is None for result in results):
            raise PetNewsUnavailableError("nessun feed ha risposto")
        return [entry for result in results if result for entry in result]

    def _read_one(self, feed: NewsFeed) -> list[RawNewsEntry] | None:
        try:
            parsed = parse_feed(self._fetch(feed.url))
        except (OSError, URLError, FeedError, ValueError) as exc:
            logger.warning("pet_news feed %s non leggibile: %s", feed.key, exc)
            return None
        return [
            RawNewsEntry(
                title=entry.title,
                summary=entry.summary,
                source=feed.name,
                url=entry.url,
                published_at=entry.published_at,
            )
            for entry in parsed[:_MAX_ENTRIES_PER_FEED]
        ]
