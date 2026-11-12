"""Claude through the official SDK (owner decision 2026-11-07): what the
client sends and withholds, how it counts usage, what it does with a
refusal, an error, a deadline, an exhausted budget; the Groq reserve
behind it; the container's wiring. No network: the SDK client is a fake."""

from __future__ import annotations

import importlib
from types import SimpleNamespace
from typing import Any

import anthropic
import pytest

from packages.bootstrap.container import ApplicationContainer, answer_models
from packages.core.application.ports.llm_client import (
    LLMGenerationRequest,
    LLMRefusal,
    LLMResponse,
)
from packages.core.application.services.llm_budget import LlmBudget, QuotaExhausted
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.infrastructure.llm.providers.anthropic_llm_client import (
    JSON_ONLY_INSTRUCTION,
    AnthropicLLMClient,
    split_system_prompt,
)
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.llm.providers.reserve_llm_client import ReserveLLMClient
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryLlmUsageRepository,
)
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# The SDK's own HTTP library (httpx2 in SDK 2.x), for building its errors.
try:
    _httpx: Any = importlib.import_module("httpx2")
except ModuleNotFoundError:
    _httpx = importlib.import_module("httpx")
MODEL = "claude-haiku-5-5"
SECRET = "Micia ha mangiato il topicida e trema"
STABLE = "VOICE: you are the assistant.\n\nTHIS REQUEST: a direct question."
VARIABLE = "\n\nTHE WRITER IS A CHILD. Simple words."


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "llm_provider": "anthropic",
        "anthropic_api_key": "test-key",
        "anthropic_model": MODEL,
        "llm_api_key": "",
        **overrides,
    }
    return Settings().model_copy(update=values)


def _message(
    text: str = "ciao",
    *,
    stop: str = "end_turn",
    input_tokens: int = 100,
    output_tokens: int = 20,
    cache_read: int = 0,
    cache_creation: int = 0,
    category: str | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        model=MODEL,
        stop_reason=stop,
        stop_details=SimpleNamespace(category=category) if category else None,
        content=[
            SimpleNamespace(type="thinking", thinking="(reasoning)"),
            SimpleNamespace(type="text", text=text),
        ],
        usage=SimpleNamespace(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            cache_read_input_tokens=cache_read,
            cache_creation_input_tokens=cache_creation,
        ),
    )


def _status_error(status: int, cls: type[anthropic.APIStatusError]) -> anthropic.APIStatusError:
    request = _httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    return cls("provider says no", response=_httpx.Response(status, request=request), body=None)


class FakeAnthropic:
    """Stands in for anthropic.Anthropic: answers in order, records every
    request body and every with_options call."""

    def __init__(self, *outcomes: Any) -> None:
        self.outcomes = list(outcomes)
        self.calls: list[dict[str, Any]] = []
        self.options: list[dict[str, Any]] = []
        self.messages = SimpleNamespace(create=self._create)

    def with_options(self, **options: Any) -> FakeAnthropic:
        self.options.append(options)
        return self

    def _create(self, **body: Any) -> Any:
        self.calls.append(body)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


def _client(fake: FakeAnthropic, **overrides: object) -> AnthropicLLMClient:
    return AnthropicLLMClient(_settings(**overrides), client=fake)


ANSWER = LLMGenerationRequest(
    system_prompt=STABLE + VARIABLE,
    user_prompt=SECRET,
    temperature=0.2,
    max_tokens=450,
    cacheable_system_chars=len(STABLE),
)
LIGHT = LLMGenerationRequest(
    system_prompt="Classify.",
    user_prompt=SECRET,
    temperature=0.0,
    max_tokens=60,
    purpose="urgency_classifier",
    model_class="light",
    json_mode=True,
    json_schema={"type": "object", "properties": {"level": {"type": "string"}}},
    timeout_seconds=6,
)


# --- what is sent --------------------------------------------------------------------


def test_an_answer_call_sends_no_sampling_parameter_and_caches_the_stable_prefix() -> None:
    fake = FakeAnthropic(_message())

    _client(fake).generate(ANSWER)

    (body,) = fake.calls
    assert body["model"] == MODEL
    assert "temperature" not in body and "top_p" not in body and "top_k" not in body
    assert "thinking" not in body
    assert body["output_config"] == {"effort": "low"}
    assert body["max_tokens"] == 450 + 600
    assert body["messages"] == [{"role": "user", "content": SECRET}]
    assert [block["text"] for block in body["system"]] == [STABLE, VARIABLE]
    assert all(block["cache_control"] == {"type": "ephemeral"} for block in body["system"])
    assert fake.options == []


def test_the_effort_levels_come_from_the_settings() -> None:
    fake = FakeAnthropic(_message(), _message('{"level": "normal"}'))
    client = _client(fake, anthropic_effort="medium", anthropic_effort_light="low")

    client.generate(ANSWER)
    client.generate(LIGHT)

    assert fake.calls[0]["output_config"]["effort"] == "medium"
    assert fake.calls[1]["output_config"]["effort"] == "low"


def test_a_light_call_switches_thinking_off_and_uses_structured_output() -> None:
    fake = FakeAnthropic(_message('{"level": "normal", "category": null}'))

    response = _client(fake).generate(LIGHT)

    (body,) = fake.calls
    assert body["thinking"] == {"type": "disabled"}
    assert body["max_tokens"] == 60
    assert body["output_config"]["format"] == {"type": "json_schema", "schema": LIGHT.json_schema}
    assert JSON_ONLY_INSTRUCTION.strip() not in body["system"][0]["text"]
    assert response.content == '{"level": "normal", "category": null}'


def test_json_without_a_schema_is_asked_for_in_words() -> None:
    fake = FakeAnthropic(_message("{}"))

    _client(fake).generate(LIGHT.model_copy(update={"json_schema": None}))

    (body,) = fake.calls
    assert "format" not in body["output_config"]
    assert body["system"][-1]["text"].endswith(JSON_ONLY_INSTRUCTION)


def test_a_refused_schema_is_retried_once_in_words() -> None:
    fake = FakeAnthropic(_status_error(400, anthropic.BadRequestError), _message("{}"))

    response = _client(fake).generate(LIGHT)

    assert len(fake.calls) == 2
    assert "format" in fake.calls[0]["output_config"]
    assert "format" not in fake.calls[1]["output_config"]
    assert fake.calls[1]["system"][-1]["text"].endswith(JSON_ONLY_INSTRUCTION)
    assert response.content == "{}"


def test_a_deadline_set_by_the_caller_disables_the_sdk_retries() -> None:
    fake = FakeAnthropic(_message("{}"))

    _client(fake).generate(LIGHT)

    assert fake.options == [{"timeout": 6, "max_retries": 0}]


def test_split_system_prompt_keeps_the_whole_prompt_stable_without_a_split_point() -> None:
    assert split_system_prompt("abc", 0) == ("abc", "")
    assert split_system_prompt("abc", 3) == ("abc", "")
    assert split_system_prompt("abcdef", 3) == ("abc", "def")


# --- what is counted -------------------------------------------------------------------


def test_usage_counts_cache_writes_cache_reads_and_reasoning() -> None:
    fake = FakeAnthropic(
        _message(
            "risposta", input_tokens=300, cache_creation=200, cache_read=1500, output_tokens=700
        )
    )

    response = _client(fake).generate(ANSWER)

    assert response.provider == "anthropic"
    assert response.model == MODEL
    assert response.prompt_tokens == 2000
    assert response.cached_prompt_tokens == 1500
    assert response.completion_tokens == 700
    assert response.token_count == 2700
    assert response.finish_reason == "stop"
    assert response.content == "risposta"


def test_the_ledger_and_the_budget_get_the_whole_count() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = LlmBudget(repository, budgets={MODEL: 4_000_000}, default_budget=200_000)
    fake = FakeAnthropic(_message(input_tokens=300, cache_read=1500, output_tokens=700))
    client = InstrumentedLLMClient(_client(fake), repository=repository, budget=budget)

    client.generate(ANSWER)

    assert budget.used_today(MODEL) == 2500


def test_a_cut_answer_is_reported_as_length() -> None:
    fake = FakeAnthropic(_message("troncata", stop="max_tokens"))

    assert _client(fake).generate(ANSWER).finish_reason == "length"


def test_a_budget_spent_on_reasoning_alone_is_an_error_not_an_empty_reply() -> None:
    fake = FakeAnthropic(_message("", stop="max_tokens"))

    with pytest.raises(ProviderError):
        _client(fake).generate(ANSWER)


# --- refusals, errors, budget ------------------------------------------------------------------


def test_a_refusal_raises_llm_refusal_naming_only_the_category() -> None:
    fake = FakeAnthropic(_message("", stop="refusal", category="bio"))

    with pytest.raises(LLMRefusal) as caught:
        _client(fake).generate(ANSWER)

    assert "bio" in str(caught.value)
    assert SECRET not in str(caught.value)


@pytest.mark.parametrize(
    ("error", "fragment"),
    [
        (_status_error(429, anthropic.RateLimitError), "429"),
        (_status_error(529, anthropic.APIStatusError), "529"),
        (_status_error(401, anthropic.AuthenticationError), "401"),
        (
            anthropic.APITimeoutError(_httpx.Request("POST", "https://api.anthropic.com")),
            "timed out",
        ),
        (
            anthropic.APIConnectionError(
                request=_httpx.Request("POST", "https://api.anthropic.com")
            ),
            "connection",
        ),
    ],
)
def test_sdk_errors_become_provider_errors_that_name_the_status_only(
    error: Exception, fragment: str
) -> None:
    fake = FakeAnthropic(error)

    with pytest.raises(ProviderError) as caught:
        _client(fake).generate(ANSWER)

    assert fragment in str(caught.value)
    assert SECRET not in str(caught.value) and "provider says no" not in str(caught.value)


def test_past_its_daily_budget_the_model_is_left_alone() -> None:
    budget = LlmBudget(InMemoryLlmUsageRepository(), budgets={MODEL: 1000}, default_budget=1000)
    budget.note_usage(MODEL, 1000)
    fake = FakeAnthropic(_message())

    with pytest.raises(QuotaExhausted):
        AnthropicLLMClient(_settings(), client=fake, availability=budget).generate(ANSWER)

    assert fake.calls == []


# --- the Groq reserve -----------------------------------------------------------------------


class _Stub:
    def __init__(self, outcome: str | Exception) -> None:
        self.outcome = outcome
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return LLMResponse(content=self.outcome, provider="stub", model="stub", token_count=1)


def test_the_reserve_answers_when_the_primary_fails() -> None:
    primary, reserve = _Stub(ProviderError("Anthropic request failed with status 529")), _Stub("ok")

    response = ReserveLLMClient(primary, reserve).generate(ANSWER)

    assert response.content == "ok"
    assert len(reserve.requests) == 1


def test_an_exhausted_primary_budget_hands_over_to_the_reserve() -> None:
    primary, reserve = _Stub(QuotaExhausted(3600)), _Stub("ok")

    assert ReserveLLMClient(primary, reserve).generate(ANSWER).content == "ok"


def test_a_refusal_is_not_retried_on_the_reserve() -> None:
    primary, reserve = _Stub(LLMRefusal("declined (bio)")), _Stub("ok")

    with pytest.raises(LLMRefusal):
        ReserveLLMClient(primary, reserve).generate(ANSWER)

    assert reserve.requests == []


def test_the_reserve_gets_what_is_left_of_the_deadline() -> None:
    primary, reserve = _Stub(ProviderError("Anthropic request timed out")), _Stub("ok")

    ReserveLLMClient(primary, reserve).generate(LIGHT.model_copy(update={"timeout_seconds": 10}))

    (request,) = reserve.requests
    assert request.timeout_seconds is not None and 7 <= request.timeout_seconds <= 10


def test_the_reserve_is_not_asked_when_no_time_is_left() -> None:
    primary, reserve = _Stub(ProviderError("Anthropic request timed out")), _Stub("ok")

    with pytest.raises(ProviderError):
        ReserveLLMClient(primary, reserve).generate(LIGHT.model_copy(update={"timeout_seconds": 2}))

    assert reserve.requests == []


# --- the wiring -----------------------------------------------------------------------------


def test_the_container_puts_claude_first_and_groq_as_the_reserve() -> None:
    settings = _settings(llm_api_key="groq-test-key", llm_model="openai/gpt-oss-120b")

    container = ApplicationContainer(settings)

    client = container.llm_client
    assert isinstance(client, InstrumentedLLMClient)
    assert isinstance(client.inner, ReserveLLMClient)
    assert isinstance(client.inner.primary, AnthropicLLMClient)
    assert isinstance(client.inner.reserve, GroqLLMClient)
    assert answer_models(settings)[:2] == [MODEL, "openai/gpt-oss-120b"]


def test_without_a_groq_key_claude_stands_alone() -> None:
    settings = _settings()

    container = ApplicationContainer(settings)

    assert isinstance(container.llm_client, InstrumentedLLMClient)
    assert isinstance(container.llm_client.inner, AnthropicLLMClient)
    assert answer_models(settings) == [MODEL]


def test_the_groq_provider_is_wired_as_before() -> None:
    settings = Settings().model_copy(
        update={"llm_provider": "groq", "llm_api_key": "k", "llm_model": "openai/gpt-oss-120b"}
    )

    assert answer_models(settings)[0] == "openai/gpt-oss-120b"
    assert isinstance(ApplicationContainer(settings).llm_client.inner, GroqLLMClient)  # type: ignore[attr-defined]


def test_settings_refuse_an_effort_the_light_calls_cannot_use() -> None:
    with pytest.raises(ValueError, match="ANTHROPIC_EFFORT_LIGHT"):
        Settings(ANTHROPIC_EFFORT_LIGHT="xhigh")  # type: ignore[call-arg]


def test_settings_require_the_key_for_the_anthropic_provider() -> None:
    with pytest.raises(ValueError, match="ANTHROPIC_API_KEY"):
        Settings(LLM_PROVIDER="anthropic", ANTHROPIC_API_KEY="")  # type: ignore[call-arg]
