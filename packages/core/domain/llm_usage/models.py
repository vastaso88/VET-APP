"""What one call to a language model cost, and the day's total per model.

Groq's free tier counts tokens per day and per model, for the whole
organization (2026-10-05: one evaluation run took the production chat
down). To stay inside it on purpose rather than by luck, every call is
recorded with its purpose, and the daily totals drive the budget
(llm_budget.py). Nothing here carries the owner's words: counts only.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from pydantic import BaseModel, Field


def utc_now() -> datetime:
    return datetime.now(UTC)


def usage_day(moment: datetime) -> date:
    """The UTC calendar day a call is counted under. Groq's own windows are
    rolling 24 hours per model; the calendar day is the conservative
    approximation we can share across serverless instances."""
    return moment.astimezone(UTC).date()


def next_day_start(moment: datetime) -> datetime:
    """Midnight UTC after [moment]: when the day counters start over."""
    day_after = usage_day(moment) + timedelta(days=1)
    return datetime(day_after.year, day_after.month, day_after.day, tzinfo=UTC)


def estimate_tokens(text: str) -> int:
    """A provider-free estimate: about one token every 3.5 characters, which
    is close for Italian prose on the o200k tokenizer family (measured with
    tiktoken on the evaluation prompts, 2026-10-14). Used only where the
    provider reports no usage (the stand-in model, failures)."""
    return max(0, round(len(text) / 3.5))


class LlmUsageEvent(BaseModel):
    id: str = Field(default_factory=lambda: uuid4().hex)
    occurred_at: datetime = Field(default_factory=utc_now)
    model: str
    model_class: str = "main"
    purpose: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_prompt_tokens: int = 0
    total_tokens: int = 0
    duration_ms: int = 0
    # "ok", "length" (the reply hit max_tokens), "rate_limited", "error".
    outcome: str = "ok"

    @property
    def day(self) -> date:
        return usage_day(self.occurred_at)


class ModelDailyUsage(BaseModel):
    day: date
    model: str
    calls: int = 0
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_prompt_tokens: int = 0
    total_tokens: int = 0
    # Set when the provider itself said the model's daily limit is reached
    # (HTTP 429 "per day"), with the moment it said to try again.
    exhausted_until: datetime | None = None
