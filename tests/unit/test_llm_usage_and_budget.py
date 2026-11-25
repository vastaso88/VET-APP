"""Every model call is measured, and the shared daily budget decides which model
may answer (llm_usage_recorder.py, llm_budget.py)."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.ports.llm_client import LLMGenerationRequest
from packages.core.application.services.llm_budget import (
    LlmBudget,
    QuotaExhausted,
    format_wait_it,
    parse_budgets,
)
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.core.domain.llm_usage.models import ModelDailyUsage
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.shared.errors.base import ProviderError

MAIN = "model-a"
RESERVE = "model-b"

TODAY = date(2026, 10, 14)
NOON = datetime(2026, 10, 14, 12, 0, tzinfo=UTC)


def _budget(repository: InMemoryLlmUsageRepository | None = None, **kw: Any) -> LlmBudget:
    return LlmBudget(
        repository or InMemoryLlmUsageRepository(),
        budgets={MAIN: 1000, RESERVE: 1000},
        default_budget=1000,
        clock=lambda: NOON,
        # Long enough that what this process notes between two reads of the
        # ledger is not thrown away by the next read.
        refresh_seconds=3600.0,
        **kw,
    )


# --- measuring -----------------------------------------------------------------------


def test_every_call_is_recorded_with_purpose_tokens_and_duration() -> None:
    repository = InMemoryLlmUsageRepository()
    client = InstrumentedLLMClient(RecordingLLMClient("ok"), repository=repository)

    client.generate(
        LLMGenerationRequest(
            system_prompt="s" * 350,
            user_prompt="u" * 350,
            purpose="situation_model",
            model_class="light",
        )
    )

    [event] = repository.events
    assert event.purpose == "situation_model"
    assert event.model_class == "light"
    assert event.model == "fake-model"
    assert event.prompt_tokens == 200 and event.completion_tokens == 1
    assert event.total_tokens == 201
    assert event.outcome == "ok"
    assert event.duration_ms >= 0
    [daily] = repository.usage_for_day(event.day)
    assert (daily.model, daily.calls, daily.total_tokens) == ("fake-model", 1, 201)


def test_a_provider_failure_is_recorded_and_still_raised() -> None:
    repository = InMemoryLlmUsageRepository()
    client = InstrumentedLLMClient(
        RecordingLLMClient(by_purpose={"answer": ProviderError("status 429: per day")}),
        repository=repository,
    )

    with pytest.raises(ProviderError):
        client.generate(LLMGenerationRequest(system_prompt="s", user_prompt="u"))

    assert repository.events[0].outcome == "rate_limited"
    assert repository.events[0].total_tokens == 0


def test_a_ledger_outage_never_costs_the_answer() -> None:
    class BrokenLedger(InMemoryLlmUsageRepository):
        def record(self, event: Any) -> None:
            raise RuntimeError("db down")

    client = InstrumentedLLMClient(RecordingLLMClient("ok"), repository=BrokenLedger())

    assert client.generate(LLMGenerationRequest(system_prompt="s", user_prompt="u")).content == "ok"


# --- the shared budget ------------------------------------------------------------------


def test_past_the_reserve_share_the_reserve_models_go_first() -> None:
    budget = _budget()
    budget.note_usage(MAIN, 850)

    assert budget.state(MAIN) == "reserve"
    assert budget.order([MAIN, RESERVE]) == [RESERVE, MAIN]


def test_an_exhausted_model_is_skipped_and_with_none_left_the_wait_is_known() -> None:
    budget = _budget()
    budget.note_usage(MAIN, 1000)

    assert budget.order([MAIN, RESERVE]) == [RESERVE]

    budget.note_usage(RESERVE, 1000)
    with pytest.raises(QuotaExhausted) as raised:
        budget.order([MAIN, RESERVE])
    # Until the day's counters reset: midnight UTC, twelve hours from noon.
    assert raised.value.retry_after_seconds == 12 * 3600


def test_the_budget_reads_what_other_instances_recorded() -> None:
    repository = InMemoryLlmUsageRepository()
    other = InstrumentedLLMClient(RecordingLLMClient(model=MAIN), repository=repository)
    for _ in range(5):
        other.generate(LLMGenerationRequest(system_prompt="s" * 700, user_prompt="u" * 700))

    budget = LlmBudget(repository, budgets={MAIN: 1000}, default_budget=1000, refresh_seconds=0.0)

    assert (
        budget.used_today(MAIN)
        == repository.usage_for_day(datetime.now(UTC).date())[0].total_tokens
    )
    assert budget.state(MAIN) == "exhausted"


def test_a_row_left_alone_until_a_time_keeps_its_meaning() -> None:
    # Nothing writes `exhausted_until` any more; a row that has it is still read.
    class Ledger(InMemoryLlmUsageRepository):
        def usage_for_day(self, day: date) -> list[ModelDailyUsage]:
            return [
                ModelDailyUsage(day=day, model=MAIN, exhausted_until=NOON + timedelta(minutes=20))
            ]

    budget = _budget(Ledger())

    assert budget.state(MAIN) == "exhausted"
    assert budget.retry_after_seconds([MAIN]) == 20 * 60


# --- the owner's allowance ---------------------------------------------------------------


def test_each_owner_has_a_daily_number_of_messages_and_developers_are_exempt() -> None:
    budget = _budget(user_daily_limit=2)

    assert budget.admit(owner_id="anna", models=[MAIN]) is None
    assert budget.admit(owner_id="anna", models=[MAIN]) is None
    denial = budget.admit(owner_id="anna", models=[MAIN])
    assert denial is not None
    assert (denial.reason, denial.daily_limit) == ("user_limit", 2)
    assert denial.retry_after_seconds == 12 * 3600
    # Another owner, and an exempt account, are not affected.
    assert budget.admit(owner_id="bruno", models=[MAIN]) is None
    assert budget.admit(owner_id="anna", models=[MAIN], exempt=True) is None


def test_with_every_model_exhausted_the_turn_is_refused_without_counting_the_owner() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository, user_daily_limit=2)
    budget.note_usage(MAIN, 1000)

    denial = budget.admit(owner_id="anna", models=[MAIN])

    assert denial is not None and denial.reason == "models_exhausted"
    assert repository.add_user_message("anna", TODAY) == 1  # nothing was counted before


def test_a_zero_limit_means_no_limit() -> None:
    budget = _budget(user_daily_limit=0)
    for _ in range(50):
        assert budget.admit(owner_id="anna", models=[MAIN]) is None


# --- small helpers -------------------------------------------------------------------------


def test_budgets_setting_and_wait_wording() -> None:
    assert parse_budgets("a=200000, b=500_000,bad,=3") == {"a": 200000, "b": 500000}
    assert format_wait_it(90) == "pochi minuti"
    assert format_wait_it(20 * 60) == "20 minuti"
    assert format_wait_it(2 * 3600 + 60) == "2 ore"
    assert format_wait_it(3600 + 20 * 60) == "1 ora e 20 minuti"
