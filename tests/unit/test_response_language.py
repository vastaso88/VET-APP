"""Multilingual groundwork: the reply language travels from the request to
the system prompt; Italian stays exactly as it always was."""

from collections.abc import Iterator
from typing import Any, cast

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.domain.common.language import (
    language_from_accept_header,
    normalize_language,
    resolve_language,
    response_language_instruction,
)
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

INSTRUCTION_MARKER = "Always reply in the user's language"


class RecordingLLM:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content="Ok.", provider="fake", model="fake-model", token_count=1, finish_reason="stop"
        )


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (None, "it"),
        ("", "it"),
        ("it", "it"),
        ("EN", "en"),
        (" en ", "en"),
        ("en-GB", "en"),
        ("en_GB", "en"),
        ("de-AT", "de"),
        ("fr", "fr"),
        ("es_MX", "es"),
        ("ja", "it"),
        ("xx", "it"),
        ("klingon", "it"),
    ],
)
def test_normalize_language(raw: str | None, expected: str) -> None:
    assert normalize_language(raw) == expected


def test_accept_language_takes_the_first_supported_language() -> None:
    assert language_from_accept_header("fr-CH, fr;q=0.9, en;q=0.8") == "fr"
    assert language_from_accept_header("ja, zh;q=0.9, de;q=0.5") == "de"
    assert language_from_accept_header("ja, zh") is None
    assert language_from_accept_header("") is None
    assert language_from_accept_header(None) is None


def test_the_body_value_wins_over_the_header_then_italian() -> None:
    assert resolve_language("en", "de") == "en"
    assert resolve_language(None, "de-DE,de;q=0.9") == "de"
    assert resolve_language(None, None) == "it"
    assert resolve_language(None, "ja") == "it"
    # Present but unsupported: the client chose, we can only serve Italian.
    assert resolve_language("xx", "de") == "it"


def test_instruction_is_empty_for_italian_and_named_for_the_others() -> None:
    assert response_language_instruction("it") == ""
    assert response_language_instruction("zz") == ""
    assert "English (en)" in response_language_instruction("en")
    assert "German (de)" in response_language_instruction("de-DE")


@pytest.mark.parametrize("kind", list(RequestKind))
def test_italian_prompt_is_byte_identical_and_english_adds_the_line(kind: RequestKind) -> None:
    default = build_system_prompt(kind, may_ask=True, has_reference_material=True)
    italian = build_system_prompt(kind, may_ask=True, has_reference_material=True, language="it")
    unknown = build_system_prompt(kind, may_ask=True, has_reference_material=True, language="xx")
    english = build_system_prompt(kind, may_ask=True, has_reference_material=True, language="en")

    assert italian == default == unknown
    assert INSTRUCTION_MARKER not in default
    assert english == default + "\n\n" + response_language_instruction("en")
    assert "English (en)" in english


def _ask(language: str | None, message: str) -> RecordingLLM:
    client = RecordingLLM()
    kwargs: dict[str, Any] = {} if language is None else {"language": language}
    ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(user_message=message, species="Cane", pet_name="Birba", **kwargs)
    )
    return client


def test_orchestrator_puts_the_language_in_the_system_prompt() -> None:
    message = "cosa posso dare da mangiare al mio cane?"
    default = _ask(None, message)
    italian = _ask("it", message)
    english = _ask("en", message)

    assert default.requests[-1].system_prompt == italian.requests[-1].system_prompt
    assert INSTRUCTION_MARKER not in italian.requests[-1].system_prompt
    assert "English (en)" in english.requests[-1].system_prompt


def test_the_small_talk_prompt_follows_the_language_too() -> None:
    italian = _ask("it", "ciao")
    french = _ask("fr", "ciao")

    assert INSTRUCTION_MARKER not in italian.requests[-1].system_prompt
    assert "French (fr)" in french.requests[-1].system_prompt
    assert french.requests[-1].system_prompt.startswith(italian.requests[-1].system_prompt)


Seen = dict[str, list[Any]]


@pytest.fixture
def api() -> Iterator[tuple[TestClient, Seen]]:
    """A client whose chat and edit services record the input they receive
    and then run for real."""
    reset_container()
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.pet_profile_repository.save(
        PetProfile(id="pet-lang", owner_id=user.id, name="Birba", species="Cane")
    )
    seen: Seen = {"send": [], "edit": []}

    real_send = container.send_chat_message_service()
    real_edit = container.edit_chat_message_service()

    class SendRecorder:
        def execute(self, data: Any) -> Any:
            seen["send"].append(data)
            return real_send.execute(data)

    class EditRecorder:
        def execute(self, data: Any) -> Any:
            seen["edit"].append(data)
            return real_edit.execute(data)

    patched = cast(Any, container)
    patched.send_chat_message_service = lambda: SendRecorder()
    patched.edit_chat_message_service = lambda: EditRecorder()
    try:
        yield TestClient(app), seen
    finally:
        reset_container()


def _post(client: TestClient, headers: dict[str, str] | None = None, **extra: Any) -> Any:
    response = client.post(
        "/chat",
        json={"pet_id": "pet-lang", "user_message": "ciao", **extra},
        headers=headers or {},
    )
    assert response.status_code == 200, response.text
    return response


def test_chat_route_defaults_to_italian(api: tuple[TestClient, Seen]) -> None:
    client, seen = api
    _post(client)
    assert seen["send"][-1].language == "it"


def test_chat_route_reads_the_language_from_the_body(api: tuple[TestClient, Seen]) -> None:
    client, seen = api
    _post(client, language="en-GB")
    assert seen["send"][-1].language == "en"
    _post(client, language="klingon")
    assert seen["send"][-1].language == "it"


def test_chat_route_falls_back_to_the_accept_language_header(
    api: tuple[TestClient, Seen],
) -> None:
    client, seen = api
    _post(client, headers={"Accept-Language": "ja, es-ES;q=0.8, en;q=0.5"})
    assert seen["send"][-1].language == "es"
    # The body wins over the header.
    _post(client, headers={"Accept-Language": "de"}, language="fr")
    assert seen["send"][-1].language == "fr"
    # Nothing supported in the header: Italian.
    _post(client, headers={"Accept-Language": "ja"})
    assert seen["send"][-1].language == "it"


def test_edit_route_takes_the_language_from_body_and_header(api: tuple[TestClient, Seen]) -> None:
    client, seen = api
    sent = _post(client, client_message_id="c1").json()
    base = f"/conversations/{sent['conversation']['id']}/messages"

    edited = client.put(
        f"{base}/c1", json={"user_message": "buongiorno", "client_message_id": "c2"}
    )
    assert edited.status_code == 200, edited.text
    assert seen["edit"][-1].language == "it"

    client.put(
        f"{base}/c2",
        json={"user_message": "hello", "client_message_id": "c3", "language": "en"},
    )
    assert seen["edit"][-1].language == "en"

    client.put(
        f"{base}/c3",
        json={"user_message": "salut", "client_message_id": "c4"},
        headers={"Accept-Language": "fr-FR,fr;q=0.9"},
    )
    assert seen["edit"][-1].language == "fr"
