"""Retention for the usage ledger and the answer cache (build 33).

Call rows carry no personal data but are only useful for analysis for a
while; the per-owner message counters link an account id to a number and
go sooner; cached answers go when they expire. Idempotent: meant to run on
a schedule (pg_cron in the database, or POST /chat/maintenance from an
external scheduler — see scripts/setup/supabase_schema.sql).
"""

from __future__ import annotations

from datetime import UTC, datetime

from pydantic import BaseModel, Field

from packages.core.application.ports.answer_cache_repository import AnswerCacheRepository
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository

USAGE_RETENTION_DAYS = 90
USER_COUNTER_RETENTION_DAYS = 30


class ChatUsageMaintenanceOutput(BaseModel):
    ran_at: datetime
    deleted: dict[str, int] = Field(default_factory=dict)


class ChatUsageMaintenanceService:
    def __init__(
        self,
        usage_repository: LlmUsageRepository,
        answer_cache: AnswerCacheRepository,
        *,
        usage_days: int = USAGE_RETENTION_DAYS,
        user_days: int = USER_COUNTER_RETENTION_DAYS,
    ) -> None:
        self._usage_repository = usage_repository
        self._answer_cache = answer_cache
        self._usage_days = usage_days
        self._user_days = user_days

    def run(self, now: datetime | None = None) -> ChatUsageMaintenanceOutput:
        moment = now or datetime.now(UTC)
        deleted = dict(
            self._usage_repository.cleanup(
                moment.astimezone(UTC).date(),
                usage_days=self._usage_days,
                user_days=self._user_days,
            )
        )
        deleted["chat_answer_cache"] = max(
            deleted.get("chat_answer_cache", 0), self._answer_cache.purge_expired(moment)
        )
        return ChatUsageMaintenanceOutput(ran_at=moment, deleted=deleted)
