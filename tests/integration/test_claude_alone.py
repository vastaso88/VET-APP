"""Claude has no reserve (owner decision 2026-11-25). When it cannot answer, or is past
the day's spending cap, the owner reads one of the calm texts the chat already had, never
an error 500, and the question is not used up.

Real app, container and Anthropic client; only the SDK underneath is a stand-in.
"""

from __future__ import annotations

import importlib
from collections.abc import Callable, Iterator
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import anthropic
import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.core.domain.localization import translate
from packages.core.domain.safety.harmful_requests import QUOTA_TEXTS
from packages.infrastructure.llm.providers.anthropic_llm_client import AnthropicLLMClient
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.shared.config.settings import reset_settings

# The SDK's own HTTP library (httpx2 in SDK 2.x), for building its errors.
try:
    _httpx: Any = importlib.import_module("httpx2")
except ModuleNotFoundError:
    _httpx = importlib.import_module("httpx")

MODEL = "claude-haiku-5-5"
LANGUAGES = ("it", "en", "es", "de", "fr")
# An invented report with text, of the evaluation tools.
REPORT = (
    Path(__file__).resolve().parents[2] / "scripts/eval/chat_quality/fixtures/referti/emocromo.pdf"
)
QUESTION = "Quanto deve bere al giorno un cane di dieci chili?"
Outcome = Callable[[dict[str, Any]], Any]


def _status(status: int, cls: type[anthropic.APIStatusError]) -> anthropic.APIStatusError:
    request = _httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    return cls("provider says no", response=_httpx.Response(status, request=request), body=None)


def _request() -> Any:
    return _httpx.Request("POST", "https://api.anthropic.com")


OUTAGES: dict[str, Exception] = {
    "overloaded": _status(529, anthropic.APIStatusError),
    "rate limited": _status(429, anthropic.RateLimitError),
    "key refused": _status(401, anthropic.AuthenticationError),
    "no credit left": _status(400, anthropic.BadRequestError),
    "too slow": anthropic.APITimeoutError(_request()),
    "unreachable": anthropic.APIConnectionError(request=_request()),
}


class FakeSdk:
    """Stands in for anthropic.Anthropic: one outcome for every call."""

    def __init__(self, outcome: Outcome) -> None:
        self.outcome = outcome
        self.calls: list[dict[str, Any]] = []
        self.messages = SimpleNamespace(create=self._create)

    def with_options(self, **_: Any) -> FakeSdk:
        return self

    def _create(self, **body: Any) -> Any:
        self.calls.append(body)
        result = self.outcome(body)
        if isinstance(result, Exception):
            raise result
        return result


def _message(text: str, *, output_tokens: int = 20) -> SimpleNamespace:
    return SimpleNamespace(
        model=MODEL,
        stop_reason="end_turn",
        stop_details=None,
        content=[SimpleNamespace(type="text", text=text)],
        usage=SimpleNamespace(
            input_tokens=100,
            output_tokens=output_tokens,
            cache_read_input_tokens=0,
            cache_creation_input_tokens=0,
        ),
    )


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """500s come back as responses, as they do in production."""
    monkeypatch.setenv("LLM_PROVIDER", "anthropic")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "anthropic-test-value")
    monkeypatch.setenv("EVIDENCE_BACKEND", "in_memory")
    monkeypatch.setenv("LLM_DAILY_BUDGET_EUR", "1")
    reset_settings()
    reset_container()
    yield TestClient(app, raise_server_exceptions=False)
    reset_settings()
    reset_container()


def _claude(outcome: Outcome) -> FakeSdk:
    llm = get_container().llm_client
    assert isinstance(llm, InstrumentedLLMClient)
    assert isinstance(llm.inner, AnthropicLLMClient)
    sdk = FakeSdk(outcome)
    llm.inner._client = sdk
    return sdk


def _pet(client: TestClient) -> str:
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"})
    return str(created.json()["pet_profile"]["id"])


def _ask(client: TestClient, pet_id: str, language: str = "it", text: str = QUESTION) -> Any:
    return client.post("/chat", json={"pet_id": pet_id, "user_message": text, "language": language})


def _used(kind: str) -> int:
    repository = get_container().llm_usage_repository
    assert isinstance(repository, InMemoryLlmUsageRepository)
    return sum(counters.get(kind, 0) for counters in repository._user_usage.values())


def _spend_the_cap() -> None:
    # 2 EUR and more of output, over the 1 EUR of the day.
    get_container().llm_budget.note_usage(MODEL, 5_000_000, completion_tokens=5_000_000)


# --- Claude does not answer -----------------------------------------------------------------


@pytest.mark.parametrize("outage", sorted(OUTAGES))
def test_an_outage_of_claude_gives_the_calm_text_and_no_question_is_used(
    client: TestClient, outage: str
) -> None:
    sdk = _claude(lambda _: OUTAGES[outage])
    pet_id = _pet(client)

    response = _ask(client, pet_id)

    assert response.status_code == 200, response.text
    reply = response.json()["reply"]
    assert translate("provider_failure", "it") in reply["content"]
    assert "provider says no" not in response.text and "anthropic" not in response.text.lower()
    assert sdk.calls  # Claude was asked, and nobody else
    assert _used("messages") == 0


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_calm_text_is_in_the_owners_language(client: TestClient, language: str) -> None:
    _claude(lambda _: OUTAGES["overloaded"])

    response = _ask(client, _pet(client), language)

    assert response.status_code == 200, response.text
    assert translate("provider_failure", language) in response.json()["reply"]["content"]


def test_a_refusal_of_claude_is_not_an_error_either(client: TestClient) -> None:
    refused = _message("")
    refused.stop_reason = "refusal"
    _claude(lambda _: refused)

    response = _ask(client, _pet(client))

    assert response.status_code == 200, response.text
    assert translate("provider_failure", "it") in response.json()["reply"]["content"]


# --- past the spending cap ------------------------------------------------------------------


@pytest.mark.parametrize("language", LANGUAGES)
def test_past_the_cap_the_chat_says_when_to_come_back_and_asks_nobody(
    client: TestClient, language: str
) -> None:
    sdk = _claude(lambda _: _message("mai"))
    pet_id = _pet(client)
    _spend_the_cap()

    response = _ask(client, pet_id, language)

    assert response.status_code == 200, response.text
    opening = QUOTA_TEXTS[language].split("{wait}")[0].format(name="Rex")
    assert response.json()["reply"]["content"].startswith(opening)
    assert sdk.calls == []
    assert _used("messages") == 0


def test_a_cap_reached_during_the_turn_gives_the_same_text(client: TestClient) -> None:
    # The helpers before the answer spend what was left of the day: the answer is not asked.
    def spends(body: dict[str, Any]) -> Any:
        assert body["thinking"] == {"type": "disabled"}, "only the helpers are asked"
        return _message('{"level": "normal", "category": null}', output_tokens=5_000_000)

    sdk = _claude(spends)

    response = _ask(client, _pet(client))

    assert response.status_code == 200, response.text
    assert sdk.calls
    opening = QUOTA_TEXTS["it"].split("{wait}")[0].format(name="Rex")
    assert response.json()["reply"]["content"].startswith(opening)
    assert _used("messages") == 0


def test_an_emergency_past_the_cap_still_gets_a_reply(client: TestClient) -> None:
    _claude(lambda _: _message("mai"))
    pet_id = _pet(client)
    _spend_the_cap()

    response = _ask(client, pet_id, text="Il mio cane non respira, cosa faccio?")

    assert response.status_code == 200, response.text
    assert response.json()["reply"]["content"].strip()


# --- the other features that call Claude --------------------------------------------------------


@pytest.mark.parametrize("over_the_cap", [False, True])
def test_the_summary_for_the_vet_fails_kindly_and_is_given_back(
    client: TestClient, over_the_cap: bool
) -> None:
    _claude(lambda _: _message("Può bere circa mezzo litro di acqua al giorno, sempre fresca."))
    asked = _ask(client, _pet(client))
    conversation_id = asked.json()["conversation"]["id"]
    _claude(lambda _: OUTAGES["overloaded"])
    if over_the_cap:
        _spend_the_cap()

    response = client.get(f"/conversations/{conversation_id}/summary")

    assert response.status_code == 502
    assert (
        response.json()["detail"] == "Servizio temporaneamente non disponibile. Riprova tra poco."
    )
    assert "provider says no" not in response.text
    assert _used("summary") == 0


@pytest.mark.parametrize("over_the_cap", [False, True])
def test_a_document_is_kept_when_claude_cannot_read_it(
    client: TestClient, over_the_cap: bool
) -> None:
    sdk = _claude(lambda _: OUTAGES["overloaded"])
    pet_id = _pet(client)
    if over_the_cap:
        _spend_the_cap()

    response = client.post(
        "/chat-attachments",
        data={"pet_id": pet_id},
        files={"file": ("referto.pdf", REPORT.read_bytes(), "application/pdf")},
    )

    assert response.status_code == 200, response.text
    [saved] = get_container().chat_attachment_repository._items.values()  # type: ignore[attr-defined]
    assert saved.analysis is None and saved.analysis_failed is True
    assert bool(sdk.calls) is not over_the_cap
    assert _used("vision") == 0
