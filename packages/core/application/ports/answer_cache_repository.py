from datetime import UTC, datetime
from typing import Protocol

from pydantic import BaseModel, Field

from packages.core.domain.knowledge.models import EvidenceSource


class CachedAnswer(BaseModel):
    """An answer to a general question, kept for a day so the same question
    (normalized) from any owner of the same kind of animal is served without
    a model call. Never a personal case: see answer_cache.py."""

    key: str
    species: str
    language: str = "it"
    question: str
    answer: str
    provider: str
    model: str
    sources: list[EvidenceSource] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    expires_at: datetime
    hits: int = 0

    def is_expired(self, now: datetime) -> bool:
        return self.expires_at <= now


class AnswerCacheRepository(Protocol):
    def get(self, key: str) -> CachedAnswer | None: ...

    def put(self, answer: CachedAnswer) -> None: ...

    def count_hit(self, key: str) -> None: ...

    def purge_expired(self, now: datetime) -> int:
        """Deletes the answers past their expiry; returns how many."""
        ...
