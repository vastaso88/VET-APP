"""The AI usage report of the admin portal: today against the euro cap, the month
against the account's credits, usage per model, the last 30 days. It prices the
ledger exactly like the daily cap does and carries no personal data."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.llm_usage_report import (
    SERIES_DAYS,
    LlmUsageReport,
    LlmUsageReportService,
    describe_model,
)
from packages.core.domain.llm_usage.models import LlmUsageEvent
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseLlmUsageRepository,
)

HAIKU = "claude-haiku-5-5"
SONNET = "claude-sonnet-5-5"
# A row of the reserve provider removed on 2026-11-25: still in the ledger, still read.
OLD_RESERVE = "openai/gpt-oss-120b"
NOW = datetime(2026, 11, 15, 12, 0, tzinfo=UTC)
TODAY = NOW.date()


def _event(
    model: str,
    *,
    days_ago: int = 0,
    prompt: int = 0,
    completion: int = 0,
    cached: int = 0,
    written: int = 0,
    calls: int = 1,
) -> list[LlmUsageEvent]:
    return [
        LlmUsageEvent(
            model=model,
            purpose="answer",
            occurred_at=NOW - timedelta(days=days_ago),
            prompt_tokens=prompt,
            completion_tokens=completion,
            cached_prompt_tokens=cached,
            cache_write_tokens=written,
            total_tokens=prompt + completion,
        )
        for _ in range(calls)
    ]


def _service(
    events: list[LlmUsageEvent] | None = None,
    *,
    cap: float = 1.0,
    usd_per_eur: float = 1.0,
    inference_geo: str = "global",
    credits: float = 100.0,
    reserve_share: float = 0.8,
    repository: InMemoryLlmUsageRepository | None = None,
) -> tuple[LlmUsageReportService, LlmBudget]:
    repository = repository or InMemoryLlmUsageRepository()
    for event in events or []:
        repository.record(event)
    budget = LlmBudget(
        repository,
        budgets={},
        default_budget=1000,
        reserve_share=reserve_share,
        clock=lambda: NOW,
        refresh_seconds=3600.0,
        daily_budget_eur=cap,
        usd_per_eur=usd_per_eur,
        inference_geo=inference_geo,
    )
    service = LlmUsageReportService(
        repository,
        budget,
        monthly_credits_usd=credits,
        usd_per_eur=usd_per_eur,
        inference_geo=inference_geo,
        clock=lambda: NOW,
    )
    return service, budget


def _report(events: list[LlmUsageEvent] | None = None, **kwargs: Any) -> LlmUsageReport:
    return _service(events, **kwargs)[0].report()


# --- an empty ledger ---------------------------------------------------------------------


def test_with_nothing_recorded_everything_is_zero_and_the_series_is_complete() -> None:
    report = _report()

    assert report.today.spent_eur == 0 and report.today.state == "ok"
    assert report.month.spent_usd == 0 and report.month.share_of_credits == 0
    assert report.models == []
    assert len(report.daily) == SERIES_DAYS == 30
    assert report.daily[-1].date == TODAY
    assert report.daily[0].date == TODAY - timedelta(days=29)
    assert [d.date for d in report.daily] == sorted({d.date for d in report.daily})
    assert report.sonnet_answers_today == report.failed_calls_today == 0


# --- today, against the euro cap ----------------------------------------------------------------


def test_today_is_priced_like_the_daily_cap_with_its_cache_parts() -> None:
    # 1,000 + 8,000 read + 1,000 written + 600 out = $0.000605 a call, x1000.
    events = _event(HAIKU, prompt=10_000, completion=600, cached=8_000, written=1_000, calls=1000)

    report = _report(events, cap=1.0)

    assert report.today.spent_usd == pytest.approx(0.605)
    assert report.today.spent_eur == pytest.approx(0.605)
    assert report.today.cap_eur == 1.0
    assert report.today.share_of_cap == pytest.approx(0.605)
    assert report.today.state == "ok"


def test_the_euro_amount_follows_the_exchange_rate() -> None:
    events = _event(HAIKU, completion=1_000_000)  # $0.50

    report = _report(events, usd_per_eur=1.25)

    assert report.today.spent_usd == pytest.approx(0.5)
    assert report.today.spent_eur == pytest.approx(0.4)
    assert report.usd_per_eur == 1.25


@pytest.mark.parametrize(
    ("output_tokens", "state"),
    [(10_000, "ok"), (17_000, "reserve"), (21_000, "exhausted")],
)
def test_the_state_is_the_one_the_chat_decides_by(output_tokens: int, state: str) -> None:
    """A cap of 0.01 EUR: $0.0000005 an output token; reserve from 80%."""
    service, budget = _service(_event(HAIKU, completion=output_tokens), cap=0.01)

    report = service.report()

    assert report.today.state == state
    assert report.today.state == budget.state(HAIKU)


def test_the_us_region_adds_a_tenth_to_what_the_portal_shows() -> None:
    events = _event(HAIKU, completion=1_000_000)

    standard = _report(events, inference_geo="global")
    us_only = _report(events, inference_geo="us")

    assert us_only.today.spent_usd == pytest.approx(standard.today.spent_usd * 1.1)
    assert us_only.inference_geo == "us"


# --- the month, against the credits -----


def test_the_month_adds_the_days_of_this_month_only() -> None:
    events = (
        _event(HAIKU, completion=1_000_000)  # today, $0.50
        + _event(HAIKU, days_ago=10, completion=1_000_000)  # 5 Nov, $0.50
        + _event(HAIKU, days_ago=20, completion=1_000_000)  # 26 Oct: another month
    )

    report = _report(events, credits=100.0)

    assert report.month.month == "2026-11"
    assert report.month.spent_usd == pytest.approx(1.0)
    assert report.month.share_of_credits == pytest.approx(0.01)
    assert report.month.credits_usd == 100.0
    # The October day is not in the month but is in the 30-day series.
    series = {d.date: d.usd for d in report.daily}
    assert series[TODAY - timedelta(days=20)] == pytest.approx(0.5)


def test_the_month_projection_is_a_straight_line() -> None:
    events = _event(HAIKU, completion=1_000_000, days_ago=5)  # $0.50 in 15 days of 30

    report = _report(events)

    assert (report.month.days_elapsed, report.month.days_in_month) == (15, 30)
    assert report.month.projected_usd == pytest.approx(1.0)


def test_the_credits_come_from_the_setting_not_from_the_code() -> None:
    events = _event(HAIKU, completion=1_000_000)

    report = _report(events, credits=50.0)

    assert report.month.share_of_credits == pytest.approx(0.5 / 50.0)


# --- per model -----


def test_every_model_has_its_own_row_with_today_and_the_month() -> None:
    events = (
        _event(HAIKU, prompt=2000, completion=500, calls=3)
        + _event(HAIKU, days_ago=3, prompt=2000, completion=500, calls=2)
        + _event(SONNET, prompt=3000, completion=800, calls=1)
        + _event(OLD_RESERVE, prompt=1000, completion=300, calls=4)
    )

    report = _report(events)
    by_label = {m.label: m for m in report.models}

    assert set(by_label) == {"Haiku 5.5", "Sonnet 5.5", "gpt-oss-120b"}
    haiku = by_label["Haiku 5.5"]
    assert (haiku.provider, haiku.paid) == ("anthropic", True)
    assert haiku.today.calls == 3 and haiku.month.calls == 5
    assert haiku.today.total_tokens == 3 * 2500 and haiku.month.total_tokens == 5 * 2500
    assert haiku.today.eur == pytest.approx(3 * (2000 * 0.10 + 500 * 0.50) / 1_000_000)
    old = by_label["gpt-oss-120b"]
    assert (old.provider, old.paid) == ("groq", False)
    assert old.month.eur == 0 and old.month.calls == 4


def test_models_are_listed_dearest_first_and_sonnet_costs_more_than_haiku() -> None:
    events = _event(HAIKU, completion=10_000) + _event(SONNET, completion=10_000)

    labels = [m.label for m in _report(events).models]

    assert labels == ["Sonnet 5.5", "Haiku 5.5"]


def test_sonnet_answers_are_counted_for_today() -> None:
    events = (
        _event(SONNET, calls=2)
        + _event(SONNET, days_ago=1, calls=5)
        + _event(HAIKU, calls=7)
        + _event(OLD_RESERVE, calls=3)
    )

    assert _report(events).sonnet_answers_today == 2


def test_the_old_rows_of_the_removed_reserve_stay_readable_and_free() -> None:
    old = (
        _event(OLD_RESERVE, prompt=1000, completion=300, calls=4)
        + _event("qwen/qwen3.8-27b", days_ago=2, prompt=500, completion=100, calls=3)
        + _event("llama-3.3-70b-versatile", days_ago=20, prompt=200, completion=50, calls=2)
    )

    report = _report(_event(HAIKU, completion=1_000_000) + old)

    rows = {m.label: m for m in report.models}
    assert rows["gpt-oss-120b"].today.calls == 4
    assert rows["gpt-oss-120b"].today.total_tokens == 4 * 1300
    assert rows["qwen3.8-27b"].month.calls == 3
    assert all(rows[label].month.eur == 0 for label in ("gpt-oss-120b", "qwen3.8-27b"))
    # The spend is Claude's alone, and no call is lost from the days.
    assert report.today.spent_usd == pytest.approx(0.5)
    assert sum(day.calls for day in report.daily) == 1 + 4 + 3 + 2
    assert sum(day.reserve_calls for day in report.daily) == 4 + 3 + 2
    # Serializable as the portal receives it.
    assert report.model_dump(mode="json")["models"]


def test_failed_calls_are_counted_apart_and_never_priced() -> None:
    events = _event("(main)", calls=3) + _event("(light)", calls=1) + _event("(main)", days_ago=2)

    report = _report(events)

    assert report.failed_calls_today == 4
    assert report.failed_calls_month == 5
    assert report.models == []
    assert report.today.spent_usd == 0


# --- the last 30 days -----


def test_the_series_covers_exactly_the_last_thirty_days() -> None:
    events = (
        _event(HAIKU, completion=1_000_000, days_ago=29)  # the first day: in
        + _event(HAIKU, completion=1_000_000, days_ago=30)  # one too old: out
        + _event(HAIKU, completion=2_000_000)  # today
    )

    report = _report(events)

    assert len(report.daily) == 30
    assert report.daily[0].eur == pytest.approx(0.5)
    assert report.daily[-1].eur == pytest.approx(1.0)
    assert sum(d.eur for d in report.daily) == pytest.approx(1.5)


def test_a_day_says_how_many_calls_went_to_claude_and_how_many_to_the_old_reserve() -> None:
    events = _event(HAIKU, calls=6, days_ago=1) + _event(OLD_RESERVE, calls=2, days_ago=1)

    day = _report(events).daily[-2]

    assert (day.calls, day.paid_calls, day.reserve_calls) == (8, 6, 2)


# --- no personal data -----


def _keys(value: object) -> set[str]:
    if isinstance(value, dict):
        return set(value) | {key for item in value.values() for key in _keys(item)}
    if isinstance(value, list):
        return {key for item in value for key in _keys(item)}
    return set()


def test_the_report_has_numbers_and_model_names_only() -> None:
    dumped = _report(_event(HAIKU, prompt=100, completion=50)).model_dump(mode="json")

    forbidden = {"owner_id", "user_id", "email", "text", "message", "content", "purpose", "id"}
    assert not (_keys(dumped) & forbidden)


# --- the repository reads -----


def test_the_range_includes_both_ends() -> None:
    repository = InMemoryLlmUsageRepository()
    for offset in range(5):
        for event in _event(HAIKU, days_ago=offset, prompt=10):
            repository.record(event)

    rows = repository.usage_for_days(TODAY - timedelta(days=3), TODAY - timedelta(days=1))

    assert [row.day for row in rows] == [
        TODAY - timedelta(days=3),
        TODAY - timedelta(days=2),
        TODAY - timedelta(days=1),
    ]


class _Query:
    def __init__(self, calls: list[tuple[str, tuple[Any, ...]]]) -> None:
        self._calls = calls

    def __getattr__(self, name: str) -> Any:
        def record(*args: Any) -> _Query:
            self._calls.append((name, args))
            return self

        return record

    def execute(self) -> Any:
        class _Response:
            data = [{"day": "2026-11-15", "model": HAIKU, "calls": 2, "prompt_tokens": 10}]

        return _Response()


class _Client:
    def __init__(self) -> None:
        self.calls: list[tuple[str, tuple[Any, ...]]] = []

    def table(self, name: str) -> _Query:
        self.calls.append(("table", (name,)))
        return _Query(self.calls)


def test_supabase_reads_the_daily_totals_for_the_range() -> None:
    client = _Client()

    rows = SupabaseLlmUsageRepository(client).usage_for_days(  # type: ignore[arg-type]
        date(2026, 10, 17), date(2026, 11, 15)
    )

    assert ("table", ("llm_usage_daily",)) in client.calls
    assert ("gte", ("day", "2026-10-17")) in client.calls
    assert ("lte", ("day", "2026-11-15")) in client.calls
    assert rows[0].model == HAIKU and rows[0].calls == 2


# --- naming the models -----


@pytest.mark.parametrize(
    ("model", "label", "provider"),
    [
        ("claude-haiku-5-5", "Haiku 5.5", "anthropic"),
        ("claude-sonnet-5-5", "Sonnet 5.5", "anthropic"),
        ("claude-opus-5", "Opus 5", "anthropic"),
        ("openai/gpt-oss-120b", "gpt-oss-120b", "groq"),
        ("qwen/qwen3.8-27b", "qwen3.8-27b", "groq"),
        ("demo-model", "demo-model", "echo"),
    ],
)
def test_models_have_a_readable_label_and_a_provider(model: str, label: str, provider: str) -> None:
    assert describe_model(model) == (label, provider)
