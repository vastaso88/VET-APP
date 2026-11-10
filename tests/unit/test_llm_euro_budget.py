"""The daily spending guard counts euros, not raw tokens (owner decision
2026-11-10, docs/marketing/04_business_plan_costi_margini.md §5).

An output token costs 5 times an input token and a token read from the prompt
cache a tenth of one, so "4 million tokens" was about 0.62 EUR, not 1 EUR.
The prices live in packages/core/domain/llm_usage/pricing.py and nowhere else.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any, get_args

import pytest

from packages.bootstrap.container import get_container
from packages.core.application.ports.llm_client import (
    LLMClient,
    LLMGenerationRequest,
    LLMResponse,
)
from packages.core.application.services.llm_budget import LlmBudget, QuotaExhausted, parse_budgets
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.core.domain.llm_usage.models import LlmUsageEvent
from packages.core.domain.llm_usage.pricing import (
    DEFAULT_INFERENCE_GEO,
    DEFAULT_USD_PER_EUR,
    FREE,
    INFERENCE_GEO_MULTIPLIERS,
    PRICES_USD_PER_MILLION,
    UNKNOWN_CLAUDE_PRICE,
    geo_multiplier,
    price_for,
    spend_usd,
)
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseLlmUsageRepository,
)
from packages.shared.config.settings import Settings

HAIKU = "claude-haiku-5-5"
GROQ = "openai/gpt-oss-120b"
NOON = datetime(2026, 11, 10, 12, 0, tzinfo=UTC)


def _budget(
    *,
    cap: float | None = 1.0,
    usd_per_eur: float = 1.0,
    inference_geo: str = DEFAULT_INFERENCE_GEO,
    budgets: dict[str, int] | None = None,
    repository: InMemoryLlmUsageRepository | None = None,
    reserve_share: float = 0.8,
) -> LlmBudget:
    return LlmBudget(
        repository or InMemoryLlmUsageRepository(),
        budgets=budgets if budgets is not None else {GROQ: 1000},
        default_budget=1000,
        reserve_share=reserve_share,
        clock=lambda: NOON,
        refresh_seconds=3600.0,
        daily_budget_eur=cap,
        usd_per_eur=usd_per_eur,
        inference_geo=inference_geo,
    )


# --- the prices, in one place ----------------------------------------------------------


def test_haiku_55_is_priced_as_the_business_plan_says() -> None:
    price = price_for(HAIKU)

    assert (price.input, price.output, price.cache_read) == (0.10, 0.50, 0.01)
    assert price.cache_write == 0.125
    assert price.is_paid


def test_an_output_token_costs_five_inputs_and_a_cache_read_a_tenth() -> None:
    price = price_for(HAIKU)

    assert price.output == pytest.approx(5 * price.input)
    assert price.cache_read == pytest.approx(price.input / 10)


def test_groq_models_are_free_and_have_no_euro_price() -> None:
    for model in (GROQ, "openai/gpt-oss-20b", "qwen/qwen3.8-27b", "(main)"):
        assert price_for(model) == FREE
        assert not price_for(model).is_paid


def test_an_unlisted_claude_model_is_never_counted_as_free(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with caplog.at_level(logging.WARNING, logger="vetgpt.pricing"):
        price = price_for("claude-some-future-model")

    assert price == UNKNOWN_CLAUDE_PRICE
    assert price.is_paid
    assert price.input >= max(p.input for p in PRICES_USD_PER_MILLION.values())
    assert "no price listed" in caplog.text


# --- the arithmetic, cache included ----------------------------------------------------------


def test_a_call_with_cache_is_priced_part_by_part() -> None:
    """10,000 prompt tokens: 1,000 plain, 8,000 read from the cache, 1,000
    written to it; 600 tokens out."""
    cost = spend_usd(
        price_for(HAIKU),
        prompt_tokens=10_000,
        completion_tokens=600,
        cached_prompt_tokens=8_000,
        cache_write_tokens=1_000,
    )

    # 1,000 x 0.10 + 8,000 x 0.01 + 1,000 x 0.125 + 600 x 0.50, per million
    assert cost == pytest.approx((100 + 80 + 125 + 300) / 1_000_000)


def test_the_cache_makes_the_same_prompt_much_cheaper() -> None:
    price = price_for(HAIKU)
    cold = spend_usd(price, prompt_tokens=10_000, completion_tokens=600)
    warm = spend_usd(price, prompt_tokens=10_000, completion_tokens=600, cached_prompt_tokens=9_000)

    assert warm < cold
    assert cold - warm == pytest.approx(9_000 * (0.10 - 0.01) / 1_000_000)


def test_the_cost_is_linear_so_daily_totals_price_like_the_calls() -> None:
    price = price_for(HAIKU)
    one = spend_usd(price, prompt_tokens=5_000, completion_tokens=300, cached_prompt_tokens=4_000)
    two = spend_usd(price, prompt_tokens=7_000, completion_tokens=500, cache_write_tokens=2_000)
    together = spend_usd(
        price,
        prompt_tokens=12_000,
        completion_tokens=800,
        cached_prompt_tokens=4_000,
        cache_write_tokens=2_000,
    )

    assert one + two == pytest.approx(together)


def test_cached_and_written_tokens_can_never_make_the_input_negative() -> None:
    cost = spend_usd(
        price_for(HAIKU),
        prompt_tokens=100,
        completion_tokens=0,
        cached_prompt_tokens=500,
        cache_write_tokens=500,
    )

    assert cost >= 0


# --- the cap, in euros -------------------------------------------------------------------------


def test_the_cap_is_the_configured_euros() -> None:
    assert _budget(cap=1.0).daily_cap_eur() == 1.0
    assert _budget(cap=2.5).daily_cap_eur() == 2.5
    assert _budget(cap=None).daily_cap_eur() is None


def test_the_same_raw_tokens_cost_more_or_less_by_what_they_are() -> None:
    """The old guard (4 million raw tokens) could not tell these two apart."""
    cheap = _budget()
    cheap.note_usage(HAIKU, 4_000_000, prompt_tokens=4_000_000, cached_prompt_tokens=4_000_000)
    dear = _budget()
    dear.note_usage(HAIKU, 4_000_000, prompt_tokens=0, completion_tokens=4_000_000)

    assert cheap.spent_today_eur() == pytest.approx(0.04)  # cache reads: 4M x $0.01
    assert cheap.state(HAIKU) == "ok"
    assert dear.spent_today_eur() == pytest.approx(2.0)  # output: 4M x $0.50
    assert dear.state(HAIKU) == "exhausted"


def test_the_states_follow_the_money_with_the_existing_reserve_share() -> None:
    # A cap of 0.01 EUR at 1 USD per EUR: each output token costs $0.0000005.
    budget = _budget(cap=0.01, reserve_share=0.8)

    budget.note_usage(HAIKU, 12_000, prompt_tokens=0, completion_tokens=12_000)  # $0.006
    assert budget.state(HAIKU) == "ok"
    budget.note_usage(HAIKU, 4_000, prompt_tokens=0, completion_tokens=4_000)  # $0.008
    assert budget.state(HAIKU) == "reserve"
    budget.note_usage(HAIKU, 4_000, prompt_tokens=0, completion_tokens=4_000)  # $0.010
    assert budget.state(HAIKU) == "exhausted"


def test_a_call_with_cache_adds_what_it_really_cost_in_euros() -> None:
    budget = _budget(usd_per_eur=DEFAULT_USD_PER_EUR)

    budget.note_usage(
        HAIKU,
        10_600,
        prompt_tokens=10_000,
        completion_tokens=600,
        cached_prompt_tokens=8_000,
        cache_write_tokens=1_000,
    )

    assert budget.spent_today_eur() == pytest.approx(0.000605 / DEFAULT_USD_PER_EUR)


def test_the_exchange_rate_is_configurable() -> None:
    at_one = _budget(usd_per_eur=1.0)
    at_two = _budget(usd_per_eur=2.0)
    for budget in (at_one, at_two):
        budget.note_usage(HAIKU, 1_000_000, prompt_tokens=0, completion_tokens=1_000_000)

    assert at_one.spent_today_eur() == pytest.approx(0.5)
    assert at_two.spent_today_eur() == pytest.approx(0.25)


def test_a_call_told_only_its_total_is_counted_as_input() -> None:
    budget = _budget()

    budget.note_usage(HAIKU, 1_000_000)

    assert budget.spent_today_eur() == pytest.approx(0.10)


def test_free_models_never_count_towards_the_euro_cap() -> None:
    budget = _budget()
    budget.note_usage(GROQ, 900, prompt_tokens=500, completion_tokens=400)

    assert budget.spent_today_eur() == 0.0
    assert budget.state(HAIKU) == "ok"


# --- paid and free models keep their own kind of budget ----------------------


def test_a_free_model_keeps_its_token_budget_next_to_the_euro_cap() -> None:
    budget = _budget(budgets={GROQ: 1000})

    budget.note_usage(GROQ, 1000, prompt_tokens=600, completion_tokens=400)

    assert budget.state(GROQ) == "exhausted"
    assert budget.state(HAIKU) == "ok"


def test_a_token_budget_given_for_a_paid_model_is_ignored(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with caplog.at_level(logging.WARNING, logger="vetgpt.budget"):
        budget = _budget(budgets={HAIKU: 10})
    budget.note_usage(HAIKU, 5_000, prompt_tokens=5_000)

    assert budget.state(HAIKU) == "ok"
    assert HAIKU in caplog.text and "euros" in caplog.text


def test_without_a_euro_cap_a_paid_model_keeps_the_old_token_budget() -> None:
    budget = _budget(cap=None, budgets={HAIKU: 4_000_000})

    budget.note_usage(HAIKU, 4_000_000, prompt_tokens=4_000_000, cached_prompt_tokens=4_000_000)

    assert budget.state(HAIKU) == "exhausted"


def test_past_the_cap_the_reserve_answers_and_with_nothing_left_the_quota_says_so() -> None:
    budget = _budget(cap=0.001)
    budget.note_usage(HAIKU, 100_000, prompt_tokens=0, completion_tokens=100_000)  # $0.05

    assert budget.order([HAIKU, GROQ]) == [GROQ]
    budget.note_usage(GROQ, 1000, prompt_tokens=600, completion_tokens=400)
    with pytest.raises(QuotaExhausted):
        budget.order([HAIKU, GROQ])


def test_past_the_cap_a_turn_is_refused_exactly_as_before_for_the_paid_model_alone() -> None:
    """Emergencies are not special-cased here: the same admit() as when the
    token budget ran out (the fixed first-aid text goes, as always)."""
    budget = _budget(cap=0.001)
    budget.note_usage(HAIKU, 100_000, prompt_tokens=0, completion_tokens=100_000)

    denial = budget.admit(owner_id="anna", models=[HAIKU])

    assert denial is not None and denial.reason == "models_exhausted"


# --- from the model usage report to the euro cap ----------------------------


class _Claude(LLMClient):
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        return LLMResponse(
            content="risposta",
            provider="anthropic",
            model=HAIKU,
            token_count=10_600,
            finish_reason="stop",
            prompt_tokens=10_000,
            completion_tokens=600,
            cached_prompt_tokens=8_000,
            cache_write_tokens=1_000,
        )


def test_a_real_call_reaches_the_cap_with_its_cache_parts_and_survives_a_new_instance() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository=repository, usd_per_eur=DEFAULT_USD_PER_EUR)
    client = InstrumentedLLMClient(_Claude(), repository=repository, budget=budget)

    client.generate(LLMGenerationRequest(system_prompt="s", user_prompt="u"))

    expected = 0.000605 / DEFAULT_USD_PER_EUR
    assert budget.spent_today_eur() == pytest.approx(expected)
    # Another serverless instance reads the same day from the ledger.
    other = _budget(repository=repository, usd_per_eur=DEFAULT_USD_PER_EUR)
    assert other.spent_today_eur() == pytest.approx(expected)
    stored = repository.usage_for_day(NOON.date())[0]
    assert (stored.cached_prompt_tokens, stored.cache_write_tokens) == (8_000, 1_000)


# --- the shared ledger in Supabase ------------------------------------------------------------


class _Call:
    def __init__(self, owner: _FakeClient, name: str, payload: Any) -> None:
        self._owner = owner
        self._name = name
        self._payload = payload

    def execute(self) -> None:
        if self._name in self._owner.failing:
            raise RuntimeError("function does not exist")
        self._owner.calls.append((self._name, self._payload))


class _Table:
    def __init__(self, owner: _FakeClient, name: str) -> None:
        self._owner = owner
        self._name = name

    def insert(self, row: Any) -> _Call:
        return _Call(self._owner, f"insert:{self._name}", row)


class _FakeClient:
    def __init__(self, failing: set[str] | None = None) -> None:
        self.failing = failing or set()
        self.calls: list[tuple[str, Any]] = []

    def table(self, name: str) -> _Table:
        return _Table(self, name)

    def rpc(self, name: str, params: Any) -> _Call:
        return _Call(self, name, params)


def _event(**fields: Any) -> LlmUsageEvent:
    return LlmUsageEvent(
        model=HAIKU,
        purpose="answer",
        prompt_tokens=10_000,
        completion_tokens=600,
        cached_prompt_tokens=8_000,
        total_tokens=10_600,
        **fields,
    )


def test_the_per_call_row_keeps_its_shape_and_the_writes_go_to_the_daily_total() -> None:
    client = _FakeClient()

    SupabaseLlmUsageRepository(client).record(_event(cache_write_tokens=1_000))  # type: ignore[arg-type]

    names = [name for name, _ in client.calls]
    assert names == ["insert:llm_usage", "llm_usage_add", "llm_usage_add_cache_writes"]
    row = dict(client.calls)["insert:llm_usage"]
    assert "cache_write_tokens" not in row
    writes = dict(client.calls)["llm_usage_add_cache_writes"]
    assert writes["p_tokens"] == 1_000 and writes["p_model"] == HAIKU


def test_a_call_without_cache_writes_makes_no_extra_request() -> None:
    client = _FakeClient()

    SupabaseLlmUsageRepository(client).record(_event())  # type: ignore[arg-type]

    assert [name for name, _ in client.calls] == ["insert:llm_usage", "llm_usage_add"]


def test_a_database_without_the_new_sql_still_counts_every_call() -> None:
    """The SQL not run yet: the writes are priced as plain input, the call is
    in the ledger and the cap keeps working."""
    client = _FakeClient(failing={"llm_usage_add_cache_writes"})

    SupabaseLlmUsageRepository(client).record(_event(cache_write_tokens=1_000))  # type: ignore[arg-type]

    assert "llm_usage_add" in [name for name, _ in client.calls]


# --- the settings and the container --------------------------------------------------------------


def test_the_defaults_are_one_euro_and_the_ecb_rate_and_haiku_has_no_token_budget() -> None:
    settings = Settings(_env_file=None)  # type: ignore[call-arg]

    assert settings.llm_daily_budget_eur == 1.0
    assert settings.llm_usd_per_eur == pytest.approx(1.1165)
    assert HAIKU not in parse_budgets(settings.llm_daily_token_budgets)


def test_the_cap_and_the_rate_come_from_the_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LLM_DAILY_BUDGET_EUR", "2.5")
    monkeypatch.setenv("LLM_USD_PER_EUR", "1.2")

    budget = get_container().llm_budget

    assert budget.daily_cap_eur() == 2.5
    budget.note_usage(HAIKU, 1_000_000, prompt_tokens=0, completion_tokens=1_000_000)
    assert budget.spent_today_eur() == pytest.approx(0.5 / 1.2)


def test_the_container_default_is_one_euro(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LLM_DAILY_BUDGET_EUR", raising=False)
    monkeypatch.delenv("LLM_USD_PER_EUR", raising=False)

    assert get_container().llm_budget.daily_cap_eur() == 1.0


@pytest.mark.parametrize("bad", ["0", "-1"])
def test_a_cap_that_is_not_positive_is_refused(bad: str, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LLM_DAILY_BUDGET_EUR", bad)

    with pytest.raises(ValueError):
        Settings(_env_file=None)  # type: ignore[call-arg]


# --- where the model runs: US-only inference costs 1.1 times ------------------------------


def test_the_regions_and_their_multipliers() -> None:
    assert INFERENCE_GEO_MULTIPLIERS == {"global": 1.0, "us": 1.1}
    assert DEFAULT_INFERENCE_GEO == "global"
    assert geo_multiplier("global") == 1.0
    assert geo_multiplier("us") == 1.1
    assert geo_multiplier(" US ") == 1.1


def test_a_region_the_table_does_not_know_is_never_counted_as_the_standard_price() -> None:
    assert geo_multiplier("eu") == max(INFERENCE_GEO_MULTIPLIERS.values())
    assert geo_multiplier("") == max(INFERENCE_GEO_MULTIPLIERS.values())


@pytest.mark.parametrize(
    "parts",
    [
        {"prompt_tokens": 1_000_000, "completion_tokens": 0},  # plain input
        {"prompt_tokens": 0, "completion_tokens": 1_000_000},  # output
        {"prompt_tokens": 1_000_000, "completion_tokens": 0, "cached_prompt_tokens": 1_000_000},
        {"prompt_tokens": 1_000_000, "completion_tokens": 0, "cache_write_tokens": 1_000_000},
    ],
    ids=["input", "output", "cache read", "cache write"],
)
def test_us_inference_costs_a_tenth_more_on_every_token_category(parts: dict[str, int]) -> None:
    price = price_for(HAIKU)

    standard = spend_usd(price, inference_geo="global", **parts)
    us_only = spend_usd(price, inference_geo="us", **parts)

    assert standard > 0
    assert us_only == pytest.approx(standard * 1.1)


def test_the_default_region_is_the_standard_price() -> None:
    price = price_for(HAIKU)

    assert spend_usd(price, prompt_tokens=1000, completion_tokens=100) == spend_usd(
        price, prompt_tokens=1000, completion_tokens=100, inference_geo="global"
    )


def test_a_model_older_than_claude_4_6_has_one_price_whatever_the_region() -> None:
    price = price_for("claude-haiku-4-5")

    assert not price.geo_priced
    assert spend_usd(price, prompt_tokens=1000, completion_tokens=100, inference_geo="us") == (
        spend_usd(price, prompt_tokens=1000, completion_tokens=100, inference_geo="global")
    )


def test_every_current_claude_model_but_haiku_4_5_carries_the_region_multiplier() -> None:
    older = {model for model, price in PRICES_USD_PER_MILLION.items() if not price.geo_priced}

    assert older == {"claude-haiku-4-5"}
    assert UNKNOWN_CLAUDE_PRICE.geo_priced


def test_the_budget_counts_the_call_with_the_region_it_runs_in() -> None:
    call = {"prompt_tokens": 10_000, "completion_tokens": 600, "cached_prompt_tokens": 8_000}
    global_budget = _budget(usd_per_eur=DEFAULT_USD_PER_EUR, inference_geo="global")
    us_budget = _budget(usd_per_eur=DEFAULT_USD_PER_EUR, inference_geo="us")
    for budget in (global_budget, us_budget):
        budget.note_usage(HAIKU, 10_600, cache_write_tokens=1_000, **call)

    assert us_budget.spent_today_eur() == pytest.approx(1.1 * global_budget.spent_today_eur())


def test_the_region_moves_a_day_across_the_threshold() -> None:
    """The same usage is "reserve" in the US and still "ok" in global."""
    states = {}
    for geo in ("global", "us"):
        budget = _budget(cap=0.01, reserve_share=0.8, inference_geo=geo)
        budget.note_usage(HAIKU, 15_000, prompt_tokens=0, completion_tokens=15_000)  # 0.0075 USD
        states[geo] = budget.state(HAIKU)

    assert states == {"global": "ok", "us": "reserve"}


def test_the_region_of_the_budget_is_the_one_in_the_settings(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ANTHROPIC_INFERENCE_GEO", "us")
    monkeypatch.setenv("LLM_USD_PER_EUR", "1.0")

    budget = get_container().llm_budget
    budget.note_usage(HAIKU, 1_000_000, prompt_tokens=0, completion_tokens=1_000_000)

    assert budget.spent_today_eur() == pytest.approx(0.5 * 1.1)


def test_the_region_setting_defaults_to_global_and_refuses_what_pricing_does_not_know(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    assert Settings(_env_file=None).anthropic_inference_geo == "global"  # type: ignore[call-arg]
    monkeypatch.setenv("ANTHROPIC_INFERENCE_GEO", "eu")

    with pytest.raises(ValueError):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_the_settings_regions_are_exactly_the_priced_regions() -> None:
    field = Settings.model_fields["anthropic_inference_geo"]

    assert set(get_args(field.annotation)) == set(INFERENCE_GEO_MULTIPLIERS)
