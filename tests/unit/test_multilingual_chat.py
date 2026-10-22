from typing import Literal, cast

import pytest
from pydantic import ValidationError

from apps.api.schemas.chat import SendChatMessageRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.evidence_synthesizer import _build_system_prompt
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.application.services.response_generator import ResponseGenerator
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis
from packages.core.domain.localization import _MESSAGES, normalize_locale
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings


@pytest.mark.parametrize("locale", ["it", "en", "es"])
def test_chat_request_accepts_supported_response_locales(locale: str) -> None:
    request = SendChatMessageRequest(
        pet_id="pet-1",
        user_message="hello",
        # "de" is served by the backend but not yet accepted by the request schema.
        response_locale=cast(Literal["it", "en", "es"], normalize_locale(locale)),
    )

    assert request.response_locale == locale


def test_chat_request_rejects_unknown_response_locale() -> None:
    with pytest.raises(ValidationError):
        SendChatMessageRequest(
            pet_id="pet-1",
            user_message="hello",
            response_locale="ja",  # type: ignore[arg-type]
        )


@pytest.mark.parametrize(
    ("selected_locale", "message", "expected"),
    [
        ("it", "non riesce a respirare", "valutazione veterinaria immediata"),
        ("en", "non riesce a respirare", "immediate veterinary assessment"),
        ("es", "cannot breathe", "valoración veterinaria inmediata"),
    ],
)
def test_triage_uses_selected_language_even_when_input_uses_another_language(
    selected_locale: str, message: str, expected: str
) -> None:
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species="dog",
            pet_name="Milo",
            language=normalize_locale(selected_locale),
        )
    )

    assert result.mode == "triage"
    assert expected in result.answer.lower()
    assert result.recommended_action is not None


@pytest.mark.parametrize(
    ("locale", "language"),
    [("it", "Italian"), ("en", "English"), ("es", "Spanish")],
)
def test_natural_answer_prompt_has_unambiguous_selected_language_rule(
    locale: str, language: str
) -> None:
    prompt = build_system_prompt(
        RequestKind.DIRECT,
        may_ask=False,
        has_reference_material=False,
        language=locale,
    )

    if locale == "it":
        assert "Italian" in prompt
    else:
        assert f"{language} ({locale})" in prompt
        assert "even when the owner writes in another language" in prompt


@pytest.mark.parametrize(
    ("locale", "expected"),
    [
        ("it", "Nel frattempo puoi"),
        ("en", "Meanwhile, you can"),
        ("es", "Mientras tanto"),
        ("de", "In der Zwischenzeit"),
    ],
)
def test_evidence_response_connectors_use_selected_language(locale: str, expected: str) -> None:
    synthesis = EvidenceSynthesis(safe_owner_actions=["action"])

    answer = ResponseGenerator().render(synthesis, response_locale=locale)

    assert expected in answer


@pytest.mark.parametrize("selected_locale", ["it", "en", "es", "de"])
@pytest.mark.parametrize(
    "message", ["non riesce a respirare", "cannot breathe", "no puede respirar"]
)
def test_urgent_signal_matrix(selected_locale: str, message: str) -> None:
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message, species="dog", pet_name="Milo", language=selected_locale
        )
    )
    assert result.mode == "triage"
    expected = {
        "it": "contatta subito",
        "en": "contact your",
        "es": "contacta de inmediato",
        "de": "Wenden Sie sich sofort",
    }
    assert expected[selected_locale] in result.answer


def test_backend_catalog_has_complete_locales_and_compatible_placeholders() -> None:
    from string import Formatter

    formatter = Formatter()
    for key, messages in _MESSAGES.items():
        assert set(messages) == {"it", "en", "es", "de", "fr"}, key
        placeholders = [
            {field for _, field, _, _ in formatter.parse(message) if field}
            for message in messages.values()
        ]
        assert all(message.strip() for message in messages.values()), key
        assert all(item == placeholders[0] for item in placeholders), key


@pytest.mark.parametrize(
    ("locale", "name"),
    [("it", "Italian"), ("en", "English"), ("es", "Spanish"), ("de", "German")],
)
def test_evidence_synthesis_also_obeys_selected_language(locale: str, name: str) -> None:
    assert f"entirely in {name}" in _build_system_prompt(locale)


@pytest.mark.parametrize("message", ["yes", "sí", "de acuerdo", "go ahead"])
def test_multilingual_consent_affirmative(message: str) -> None:
    assert ConsentInterpreter().interpret(message) is True


@pytest.mark.parametrize("message", ["no", "don't consult it", "no consultes el historial"])
def test_multilingual_consent_negative(message: str) -> None:
    assert ConsentInterpreter().interpret(message) is False
