from __future__ import annotations

import logging
import threading
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta

from packages.core.application.ports.pet_news import (
    PetNewsCacheRepository,
    PetNewsFeedReader,
    PetNewsUnavailableError,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.pet_news.models import (
    NEWS_CATEGORIES,
    PetNewsEntry,
    PetNewsSnapshot,
    RawNewsEntry,
    clean_source,
    clean_title,
    is_http_url,
    merge_entries,
)
from packages.core.domain.pet_news.relevance import categories_for

logger = logging.getLogger(__name__)

DEFAULT_COUNTRY = "IT"
# After a failed read of the feeds, do not try again for this long: a dead
# source must not make every request wait for its timeout.
_RETRY_AFTER_FAILURE = timedelta(minutes=5)
# With no copy at all to serve (the first request after a cold start, or after the
# cache was emptied) a failed read is repeated much sooner: five minutes of empty
# answers is five minutes of an empty "Curiosità" section on the Home.
_RETRY_AFTER_FAILURE_NO_COPY = timedelta(seconds=20)


@dataclass(frozen=True)
class PetNewsResult:
    categories: dict[str, list[PetNewsEntry]]
    updated_at: datetime | None
    # True when the feeds could not be read and an older copy is served.
    stale: bool
    # False: there is no feed of that country. The news of another one are never a fallback.
    country_has_news: bool = True


def classify_entries(raw_entries: list[RawNewsEntry]) -> list[PetNewsEntry]:
    """Raw feed entries -> headlines, one per category they belong to.
    Off-topic, recipe-like and link-less entries disappear here."""
    classified: list[PetNewsEntry] = []
    for raw in raw_entries:
        title = clean_title(raw.title)
        if not title or not is_http_url(raw.url):
            continue
        for category in categories_for(title, raw.summary):
            classified.append(
                PetNewsEntry(
                    category=category,
                    title=title,
                    source=clean_source(raw.source),
                    url=raw.url,
                    published_at=raw.published_at,
                )
            )
    return classified


class GetPetNewsService:
    """Serves the headlines of one country from a shared cache, refreshing it
    from the feeds when it is older than `ttl`. If the feeds do not answer, the
    last good snapshot keeps being served."""

    def __init__(
        self,
        cache: PetNewsCacheRepository,
        reader: PetNewsFeedReader,
        *,
        ttl: timedelta,
        clock: Callable[[], datetime] = utc_now,
    ) -> None:
        self._cache = cache
        self._reader = reader
        self._ttl = ttl
        self._clock = clock
        self._lock = threading.Lock()
        self._last_failure: dict[str, datetime] = {}

    def get(
        self,
        *,
        categories: list[str] | None = None,
        limit: int = 12,
        country: str = DEFAULT_COUNTRY,
    ) -> PetNewsResult:
        country = country.strip().upper()
        if not self._reader.has_feeds(country):
            return PetNewsResult(
                categories={}, updated_at=None, stale=False, country_has_news=False
            )
        wanted = [c for c in (categories or NEWS_CATEGORIES) if c in NEWS_CATEGORIES]
        snapshot, stale = self._current(country)
        return PetNewsResult(
            categories={c: snapshot.for_category(c, limit) for c in wanted} if snapshot else {},
            updated_at=snapshot.fetched_at if snapshot else None,
            stale=stale,
        )

    def _current(self, country: str) -> tuple[PetNewsSnapshot | None, bool]:
        now = self._clock()
        key = country.lower()  # of the snapshot ("it" since before there were countries)
        snapshot = self._load(key)
        if snapshot is not None and now - snapshot.fetched_at < self._ttl:
            return snapshot, False
        failed_at = self._last_failure.get(key)
        pause = _RETRY_AFTER_FAILURE if snapshot is not None else _RETRY_AFTER_FAILURE_NO_COPY
        if failed_at is not None and now - failed_at < pause:
            return snapshot, snapshot is not None

        with self._lock:
            # Another request may have refreshed it while this one waited.
            snapshot = self._load(key) or snapshot
            if snapshot is not None and now - snapshot.fetched_at < self._ttl:
                return snapshot, False
            try:
                fresh = classify_entries(self._reader.read_all(country))
                if not fresh:
                    raise PetNewsUnavailableError("i feed non hanno restituito notizie utili")
            except PetNewsUnavailableError as exc:
                logger.warning("pet_news refresh failed (%s): serving the last snapshot", exc)
                self._last_failure[key] = now
                return snapshot, snapshot is not None
            self._last_failure.pop(key, None)
            rebuilt = PetNewsSnapshot(
                key=key,
                fetched_at=now,
                items=merge_entries(fresh, snapshot.items if snapshot else [], now=now),
            )
            try:
                self._cache.put(rebuilt)
            except Exception:  # noqa: BLE001 - a cache outage must not hide good headlines
                logger.exception("pet_news snapshot could not be saved")
            return rebuilt, False

    def _load(self, key: str) -> PetNewsSnapshot | None:
        try:
            return self._cache.get(key)
        except Exception:  # noqa: BLE001 - treat an unreadable cache as an empty one
            logger.exception("pet_news snapshot could not be read")
            return None
