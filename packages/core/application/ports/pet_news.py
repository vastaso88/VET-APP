from typing import Protocol

from packages.core.domain.pet_news.models import PetNewsSnapshot, RawNewsEntry


class PetNewsCacheRepository(Protocol):
    """Where the latest snapshot of the headlines is kept between requests.
    On a serverless host an instance can vanish at any time, so the shared
    copy lives in the database."""

    def get(self, key: str) -> PetNewsSnapshot | None: ...

    def put(self, snapshot: PetNewsSnapshot) -> None: ...


class PetNewsFeedReader(Protocol):
    """Reads every enabled feed for an audience and returns their entries.
    Raises `PetNewsUnavailableError` when not a single feed could be read."""

    def read_all(self, key: str) -> list[RawNewsEntry]: ...


class PetNewsUnavailableError(RuntimeError):
    """No feed answered."""
