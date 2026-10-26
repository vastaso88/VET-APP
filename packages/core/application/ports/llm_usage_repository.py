from datetime import date, datetime
from typing import Protocol

from packages.core.domain.llm_usage.models import LlmUsageEvent, ModelDailyUsage


class LlmUsageRepository(Protocol):
    """The ledger behind the daily budget: one row per model call, the
    day's totals per model, and how many messages each owner sent today.
    Shared storage (Supabase) in production, because every serverless
    instance must see the same totals."""

    def record(self, event: LlmUsageEvent) -> None: ...

    def usage_for_day(self, day: date) -> list[ModelDailyUsage]: ...

    def mark_exhausted(self, model: str, day: date, until: datetime) -> None: ...

    def add_user_message(self, owner_id: str, day: date) -> int:
        """Counts one more message for [owner_id] today and returns the
        new total."""
        ...

    def add_user_usage(self, owner_id: str, day: date, kind: str) -> int:
        """Counts one more use of [kind] ("messages", "vision", "dictation",
        "summary") for [owner_id] today and returns the new total."""
        ...

    def cleanup(self, today: date, *, usage_days: int, user_days: int) -> dict[str, int]:
        """Deletes call rows older than [usage_days] and owner counters
        older than [user_days]; returns how many rows went, per table."""
        ...
