"""Build 32, free-tier economy: every model call is measured, the light
model has its own chain, and the shared daily budget decides which model
may answer (llm_usage_recorder.py, groq_llm_client.py, llm_budget.py)."""

from __future__ import annotations

import io
import json
from datetime import UTC, date, datetime
from email.message import Message
from typing import Any
from urllib import error, request

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
from packages.infrastructure.llm.providers.groq_chat_api import GroqChatApi, parse_retry_after
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

MAIN = "openai/gpt-oss-120b"
RESERVE = "openai/gpt-oss-20b"
LIGHT = "llama-3.1-8b-instant"

DAILY_LIMIT_BODY = (
    '{"error":{"message":"Rate limit reached for model in organization on tokens per '
    'day (TPD): Limit 200000, Used 199231, Requested 1200. Please try again in 1h2m3.5s.",'
    '"code":"rate_limit_exceeded"}}'
)
MINUTE_LIMIT_BODY = (
    '{"error":{"message":"Rate limit reached on tokens per minute (TPM). Please try again '
    'in 12.5s.","code":"rate_limit_exceeded"}}'
)
TODAY = date(2026, 10, 14)
NOON = datetime(2026, 10, 14, 12, 0, tzinfo=UTC)


class FakeGroq:
    """Groq's endpoint: per model, a reply or an HTTP error; records what
    was asked, with which payload and deadline."""

    def __init__(self, behaviour: dict[str, tuple[int, str] | str]) -> None:
        self.behaviour = behaviour
        self.asked: list[str] = []
        self.payloads: list[dict[str, Any]] = []
        self.timeouts: list[int] = []

    def __call__(self, http_request: request.Request, timeout: int) -> dict[str, Any]:
        assert isinstance(http_request.data, bytes)
        payload = json.loads(http_request.data)
        model = payload["model"]
        self.asked.append(model)
        self.payloads.append(payload)
        self.timeouts.append(timeout)
        outcome = self.behaviour.get(model, "ok")
        if isinstance(outcome, tuple):
            status, body = outcome
            raise error.HTTPError(
                http_request.full_url, status, "error", Message(), io.BytesIO(body.encode())
            )
        return {
            "model": model,
            "choices": [{"message": {"content": outcome}, "finish_reason": "stop"}],
            "usage": {
                "prompt_tokens": 1200,
                "completion_tokens": 300,
                "total_tokens": 1500,
                "prompt_tokens_details": {"cached_tokens": 900},
            },
        }


def _settings(**overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "llm_provider": "groq",
        "llm_model": MAIN,
        "llm_api_key": "test-key",
        "llm_fallback_models": RESERVE,
        "llm_model_light": LIGHT,
        "llm_light_fallback_models": RESERVE,
        "llm_reasoning_headroom_tokens": 350,
        **overrides,
    }
    return Settings().model_copy(update=values)


def _budget(repository: InMemoryLlmUsageRepository | None = None, **kw: Any) -> LlmBudget:
    return LlmBudget(
        repository or InMemoryLlmUsageRepository(),
        budgets={MAIN: 1000, RESERVE: 1000, LIGHT: 2500},
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


def test_groq_usage_fields_including_cached_prompt_tokens_are_read() -> None:
    fake = FakeGroq({MAIN: "risposta"})

    response = GroqLLMClient(_settings(), transport=fake).generate(
        LLMGenerationRequest(system_prompt="s", user_prompt="u")
    )

    assert (response.prompt_tokens, response.completion_tokens) == (1200, 300)
    assert response.cached_prompt_tokens == 900
    assert response.token_count == 1500


# --- the light chain --------------------------------------------------------------------


def test_light_requests_go_to_the_light_model_in_json_mode_without_reasoning_fields() -> None:
    fake = FakeGroq({LIGHT: '{"level": "normal"}', MAIN: "answer"})
    client = GroqLLMClient(_settings(), transport=fake)

    client.generate(
        LLMGenerationRequest(
            system_prompt="s",
            user_prompt="u",
            max_tokens=60,
            model_class="light",
            json_mode=True,
            timeout_seconds=6,
        )
    )
    client.generate(LLMGenerationRequest(system_prompt="s", user_prompt="u", max_tokens=450))

    assert fake.asked == [LIGHT, MAIN]
    light, main = fake.payloads
    assert light["response_format"] == {"type": "json_object"}
    assert "reasoning_effort" not in light and light["max_tokens"] == 60
    assert fake.timeouts[0] == 6
    # The main model is a reasoning model: low effort plus the headroom.
    assert main["reasoning_effort"] == "low" and main["max_tokens"] == 450 + 350
    assert "response_format" not in main


def test_a_rate_limited_light_model_falls_back_to_its_own_reserve() -> None:
    fake = FakeGroq({LIGHT: (429, MINUTE_LIMIT_BODY), RESERVE: '{"level": "normal"}'})

    response = GroqLLMClient(_settings(), transport=fake).generate(
        LLMGenerationRequest(system_prompt="s", user_prompt="u", model_class="light")
    )

    assert fake.asked == [LIGHT, RESERVE]
    assert response.model == RESERVE


def test_a_light_model_missing_on_the_account_falls_through_to_its_reserve() -> None:
    # 2026-10-14: the evaluation account had no llama-3.1-8b-instant at all.
    missing = (404, '{"error":{"message":"The model does not exist","code":"model_not_found"}}')
    fake = FakeGroq({LIGHT: missing, RESERVE: '{"level": "normal"}'})
    client = GroqLLMClient(_settings(), transport=fake)

    for _ in range(2):
        response = client.generate(
            LLMGenerationRequest(system_prompt="s", user_prompt="u", model_class="light")
        )
        assert response.model == RESERVE

    # Asked once, then left alone: not hit again on the next call.
    assert fake.asked == [LIGHT, RESERVE, RESERVE]


def test_a_chain_of_only_missing_models_fails_at_once_without_a_round_trip() -> None:
    missing = (404, '{"error":{"message":"The model does not exist","code":"model_not_found"}}')
    fake = FakeGroq({LIGHT: missing, RESERVE: missing})
    client = GroqLLMClient(_settings(), transport=fake)
    request = LLMGenerationRequest(system_prompt="s", user_prompt="u", model_class="light")

    with pytest.raises(ProviderError):
        client.generate(request)
    asked_once = list(fake.asked)
    with pytest.raises(ProviderError, match="available on this account"):
        client.generate(request)

    assert asked_once == [LIGHT, RESERVE]
    assert fake.asked == asked_once  # the second call asked nothing


def test_without_a_light_model_everything_goes_to_the_main_chain() -> None:
    fake = FakeGroq({MAIN: "answer"})

    GroqLLMClient(_settings(llm_model_light=""), transport=fake).generate(
        LLMGenerationRequest(system_prompt="s", user_prompt="u", model_class="light")
    )

    assert fake.asked == [MAIN]


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


def test_a_daily_429_marks_the_model_exhausted_for_everyone_a_minute_429_does_not() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository)
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: "ok"})
    api = GroqChatApi(
        base_url="https://groq.test/openai/v1",
        api_key="k",
        timeout_seconds=5,
        models=[MAIN, RESERVE],
        purpose="chat",
        transport=fake,
        availability=budget,
    )

    _, served_by = api.complete(lambda model: {"model": model})

    assert served_by == RESERVE
    assert budget.state(MAIN) == "exhausted"
    [row] = [u for u in repository.usage_for_day(TODAY) if u.model == MAIN]
    # Groq said "try again in 1h2m3.5s": that, not the whole day.
    assert row.exhausted_until is not None
    assert (row.exhausted_until - NOON).total_seconds() == pytest.approx(3724, abs=1)
    assert 60 <= budget.retry_after_seconds([MAIN]) <= 3724

    minute_budget = _budget()
    minute_fake = FakeGroq({MAIN: (429, MINUTE_LIMIT_BODY), RESERVE: "ok"})
    minute_api = GroqChatApi(
        base_url="https://groq.test/openai/v1",
        api_key="k",
        timeout_seconds=5,
        models=[MAIN, RESERVE],
        purpose="chat",
        transport=minute_fake,
        availability=minute_budget,
    )

    _, served_by = minute_api.complete(lambda model: {"model": model})

    assert served_by == RESERVE  # the reserve chain works for both kinds of 429
    assert minute_budget.state(MAIN) == "ok"


def test_the_budget_can_refuse_before_any_request_is_sent() -> None:
    budget = _budget()
    budget.note_usage(MAIN, 1000)
    budget.note_usage(RESERVE, 1000)
    fake = FakeGroq({})
    api = GroqChatApi(
        base_url="https://groq.test/openai/v1",
        api_key="k",
        timeout_seconds=5,
        models=[MAIN, RESERVE],
        purpose="chat",
        transport=fake,
        availability=budget,
    )

    with pytest.raises(QuotaExhausted):
        api.complete(lambda model: {"model": model})

    assert fake.asked == []


@pytest.mark.parametrize(
    ("detail", "seconds"),
    [
        ("Please try again in 1h2m3.5s.", 3724),
        ("try again in 12.5s", 13),
        ("try again in 850ms", 1),
        ("no hint here", None),
    ],
)
def test_the_retry_time_in_groqs_message_is_read(detail: str, seconds: int | None) -> None:
    assert parse_retry_after(detail) == seconds


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
