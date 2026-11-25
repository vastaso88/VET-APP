from typing import Protocol

from packages.core.domain.pet_news.models import PetNewsSnapshot, RawNewsEntry


class PetNewsCacheRepository(Protocol):
    """Where the latest snapshot of the headlines is kept between requests.
    On a serverless host an instance can vanish at any time, so the shared
    copy lives in the database."""

    def get(self, key: str) -> PetNewsSnapshot | None: ...

    def put(self, snapshot: PetNewsSnapshot) -> None: ...


class PetNewsFeedReader(Protocol):
    """Reads every enabled feed of a country (ISO 3166-1 alpha-2) and returns their
    entries. Raises `PetNewsUnavailableError` when not a single feed could be read."""

    def has_feeds(self, country: str) -> bool:
        """Whether there is a feed for that country at all (a disabled one counts)."""
        ...

    def read_all(self, country: str) -> list[RawNewsEntry]: ...


class PetNewsUnavailableError(RuntimeError):
    """No feed answered."""
