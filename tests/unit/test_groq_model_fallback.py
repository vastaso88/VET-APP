import io
import json
import logging
from email.message import Message
from typing import Any
from urllib import error, request

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest
from packages.infrastructure.llm.providers.groq_chat_api import (
    DAILY_LIMIT_COOLDOWN_SECONDS,
    SHORT_LIMIT_COOLDOWN_SECONDS,
    GroqChatApi,
    split_models,
)
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.vision.groq_image_analyzer import GroqImageAnalyzer
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

MAIN = "openai/gpt-oss-120b"
RESERVE = "openai/gpt-oss-20b"
LAST = "qwen/qwen3.8-27b"

DAILY_LIMIT_BODY = (
    '{"error":{"message":"Rate limit reached for model in organization on tokens per '
    'day (TPD): Limit 200000, Used 199231","code":"rate_limit_exceeded"}}'
)
MINUTE_LIMIT_BODY = (
    '{"error":{"message":"Rate limit reached on tokens per minute (TPM)",'
    '"code":"rate_limit_exceeded"}}'
)
SECRET_PROMPT = "Micia ha la creatinina alta"


class FakeGroq:
    """Stands in for Groq's HTTP endpoint: answers per model, either with a
    reply or with an HTTP error, and records which models were asked."""

    def __init__(self, behaviour: dict[str, tuple[int, str] | str]) -> None:
        self.behaviour = behaviour
        self.asked: list[str] = []
        self.payloads: list[dict[str, Any]] = []

    def __call__(self, http_request: request.Request, timeout: int) -> dict[str, Any]:
        assert isinstance(http_request.data, bytes)
        payload = json.loads(http_request.data)
        model = payload["model"]
        self.asked.append(model)
        self.payloads.append(payload)
        outcome = self.behaviour[model]
        if isinstance(outcome, tuple):
            status, body = outcome
            raise error.HTTPError(
                http_request.full_url,
                status,
                "error",
                Message(),
                io.BytesIO(body.encode()),
            )
        return {
            "model": model,
            "choices": [{"message": {"content": outcome}, "finish_reason": "stop"}],
            "usage": {"total_tokens": 42},
        }


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def _settings(**overrides: str) -> Settings:
    values = {
        "llm_provider": "groq",
        "llm_model": MAIN,
        "llm_api_key": "test-key",
        "llm_fallback_models": f"{RESERVE}, {LAST}",
        "vision_model": LAST,
        **overrides,
    }
    return Settings().model_copy(update=values)


def _api(fake: FakeGroq, clock: Clock, models: list[str] | None = None) -> GroqChatApi:
    return GroqChatApi(
        base_url="https://groq.test/openai/v1",
        api_key="test-key",
        timeout_seconds=5,
        models=models or [MAIN, RESERVE, LAST],
        purpose="chat",
        transport=fake,
        clock=clock,
    )


def _payload(model: str) -> dict[str, Any]:
    return {"model": model, "messages": [{"role": "user", "content": SECRET_PROMPT}]}


REQUEST = LLMGenerationRequest(system_prompt="sistema", user_prompt=SECRET_PROMPT)


def test_the_configured_model_answers_when_it_can() -> None:
    fake = FakeGroq({MAIN: "ciao"})

    response = GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN]
    assert response.content == "ciao"
    assert response.model == MAIN


def test_a_rate_limited_model_hands_over_to_the_reserve() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: "risposta di riserva"})

    response = GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN, RESERVE]
    assert response.content == "risposta di riserva"
    assert response.model == RESERVE


def test_the_reserve_is_walked_in_order_until_one_answers() -> None:
    fake = FakeGroq(
        {MAIN: (429, DAILY_LIMIT_BODY), RESERVE: (429, MINUTE_LIMIT_BODY), LAST: "terza scelta"}
    )

    response = GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN, RESERVE, LAST]
    assert response.content == "terza scelta"


def test_the_service_is_unavailable_only_when_every_model_fails() -> None:
    fake = FakeGroq(
        {
            MAIN: (429, DAILY_LIMIT_BODY),
            RESERVE: (429, DAILY_LIMIT_BODY),
            LAST: (429, DAILY_LIMIT_BODY),
        }
    )

    with pytest.raises(ProviderError, match="429"):
        GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN, RESERVE, LAST]


def test_a_model_over_its_daily_limit_is_left_alone_for_a_while() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: "ok"})
    clock = Clock()
    api = _api(fake, clock)

    api.complete(_payload)
    clock.now += DAILY_LIMIT_COOLDOWN_SECONDS - 1
    api.complete(_payload)

    # The second message did not hit the exhausted model again.
    assert fake.asked == [MAIN, RESERVE, RESERVE]

    fake.behaviour[MAIN] = "di nuovo disponibile"
    clock.now += 2
    body, model = api.complete(_payload)

    assert model == MAIN
    assert fake.asked[-1] == MAIN


def test_a_per_minute_limit_rests_the_model_only_briefly() -> None:
    fake = FakeGroq({MAIN: (429, MINUTE_LIMIT_BODY), RESERVE: "ok"})
    clock = Clock()
    api = _api(fake, clock)

    api.complete(_payload)
    fake.behaviour[MAIN] = "ok"
    clock.now += SHORT_LIMIT_COOLDOWN_SECONDS + 1
    _body, model = api.complete(_payload)

    assert model == MAIN


def test_when_every_model_is_resting_a_real_attempt_is_still_made() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: (429, DAILY_LIMIT_BODY)})
    api = _api(fake, Clock(), models=[MAIN, RESERVE])

    with pytest.raises(ProviderError):
        api.complete(_payload)
    fake.behaviour[RESERVE] = "tornato"
    _body, model = api.complete(_payload)

    assert model == RESERVE


def test_a_server_error_moves_on_without_resting_the_model() -> None:
    fake = FakeGroq({MAIN: (503, "overloaded"), RESERVE: "ok"})
    api = _api(fake, Clock())

    api.complete(_payload)
    fake.behaviour[MAIN] = "ok"
    _body, model = api.complete(_payload)

    assert model == MAIN


def test_a_wrong_key_is_not_masked_by_the_reserve() -> None:
    fake = FakeGroq({MAIN: (401, "invalid api key"), RESERVE: "ok"})

    with pytest.raises(ProviderError, match="401"):
        GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN]


def test_a_reserve_model_that_rejects_the_request_is_skipped() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: (404, "model not found"), LAST: "ok"})

    response = GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert response.model == LAST


def test_without_a_reserve_the_error_is_reported_as_before() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY)})

    with pytest.raises(ProviderError):
        GroqLLMClient(_settings(llm_fallback_models=""), transport=fake).generate(REQUEST)

    assert fake.asked == [MAIN]


def test_the_reasoning_setting_goes_only_to_the_models_that_know_it() -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: (429, DAILY_LIMIT_BODY), LAST: "ok"})

    GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    by_model = {payload["model"]: payload for payload in fake.payloads}
    assert by_model[MAIN]["reasoning_effort"] == "low"
    assert by_model[RESERVE]["reasoning_effort"] == "low"
    assert "reasoning_effort" not in by_model[LAST]


def test_inline_reasoning_of_a_reserve_model_never_reaches_the_owner() -> None:
    fake = FakeGroq(
        {MAIN: (429, DAILY_LIMIT_BODY), RESERVE: "<think>ragiono tra me</think>\nEcco la risposta."}
    )

    response = GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert response.content == "Ecco la risposta."


def test_the_log_names_the_model_used_and_never_the_text(
    caplog: pytest.LogCaptureFixture,
) -> None:
    fake = FakeGroq({MAIN: (429, DAILY_LIMIT_BODY), RESERVE: "risposta riservata"})

    with caplog.at_level(logging.INFO):
        GroqLLMClient(_settings(), transport=fake).generate(REQUEST)

    assert f"model {MAIN} rate limited (daily limit)" in caplog.text
    assert f"served by reserve model {RESERVE}" in caplog.text
    assert SECRET_PROMPT not in caplog.text
    assert "risposta riservata" not in caplog.text
    assert "test-key" not in caplog.text


def test_vision_uses_its_own_reserve_list() -> None:
    fake = FakeGroq(
        {LAST: (429, DAILY_LIMIT_BODY), "vision/reserve": "Referto: tutto nella norma."}
    )
    analyzer = GroqImageAnalyzer(_settings(vision_fallback_models="vision/reserve"), transport=fake)

    text = analyzer.analyze(b"\xff\xd8\xff", "image/jpeg", context="Specie: cane")

    assert fake.asked == [LAST, "vision/reserve"]
    assert text == "Referto: tutto nella norma."


def test_vision_has_no_reserve_by_default() -> None:
    assert Settings.model_fields["vision_fallback_models"].default == ""
    fake = FakeGroq({LAST: (429, DAILY_LIMIT_BODY)})

    with pytest.raises(ProviderError):
        GroqImageAnalyzer(_settings(), transport=fake).analyze(b"x", "image/jpeg", context="")


def test_the_reserve_list_is_a_comma_separated_value() -> None:
    assert split_models(" a , b,,c ") == ["a", "b", "c"]
    assert split_models("") == []
    assert split_models(Settings.model_fields["llm_fallback_models"].default) == [RESERVE, LAST]
