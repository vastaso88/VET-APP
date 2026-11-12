"""Build 32, the second guardian: the light model reads the message for an
emergency the fixed lists missed; the lists stay the floor and the
classifier fails open (urgency_classifier.py, ChatOrchestrator)."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.domain.safety.triage_clarification import CLARIFYING_QUESTIONS
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError

EMERGENCY = '{"level": "emergency", "category": "toxin_medication"}'
MAYBE_RESPIRATORY = '{"level": "maybe", "category": "respiratory"}'
MAYBE_OTHER = '{"level": "maybe", "category": null}'
NORMAL = '{"level": "normal", "category": null}'

# Nothing in the fixed lists matches this wording.
MISSED_EMERGENCY = "ha leccato il liquido blu che era colato dalla macchina in garage"


def _orchestrator(verdict: str | Exception) -> tuple[ChatOrchestrator, RecordingLLMClient]:
    client = RecordingLLMClient(by_purpose={"urgency_classifier": verdict})
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=UrgencyClassifier(client, timeout_seconds=6),
    )
    return orchestrator, client


def _ask(orchestrator: ChatOrchestrator, text: str) -> object:
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=text, species="Cane", pet_name="Rex")
    )


def test_parsing_is_lenient_about_wrapping_and_strict_about_values() -> None:
    parse = UrgencyClassifier.parse
    wrapped = parse('Sure: {"level": "emergency", "category": "seizure"} .')
    assert wrapped is not None
    assert wrapped.model_dump() == {"level": "emergency", "category": "seizure"}
    assert parse('{"level": "maybe", "category": "cardiology"}').category == "other"  # type: ignore[union-attr]
    assert parse('{"level": "normal", "category": "seizure"}').category is None  # type: ignore[union-attr]
    assert parse('{"level": "panic"}') is None
    assert parse("not json at all") is None
    assert parse("") is None


def test_an_emergency_the_lists_missed_gets_the_same_fixed_triage_reply() -> None:
    orchestrator, client = _orchestrator(EMERGENCY)

    result = _ask(orchestrator, MISSED_EMERGENCY)

    assert result.mode == "triage"  # type: ignore[attr-defined]
    assert result.model == "safety-triage-guard"  # type: ignore[attr-defined]
    assert result.ai_generated is False  # type: ignore[attr-defined]
    assert result.answer.startswith("Meglio non rischiare")  # type: ignore[attr-defined]
    assert "pronto soccorso veterinario" in result.answer  # type: ignore[attr-defined]
    assert result.safety_flags == ["classifier:toxin_medication"]  # type: ignore[attr-defined]
    assert client.requests_for("answer") == []


def test_the_classifier_call_is_light_short_and_structured() -> None:
    orchestrator, client = _orchestrator(NORMAL)

    _ask(orchestrator, MISSED_EMERGENCY)

    [request] = client.requests_for("urgency_classifier")
    assert request.model_class == "light"
    assert request.json_mode is True
    assert request.timeout_seconds == 6
    assert request.max_tokens <= 100
    assert len(request.system_prompt) < 2000
    assert MISSED_EMERGENCY in request.user_prompt


def test_a_possible_emergency_with_a_known_category_gets_its_clarifying_question() -> None:
    orchestrator, client = _orchestrator(MAYBE_RESPIRATORY)

    result = _ask(orchestrator, "da stamattina fa un rumore strano quando respira")

    assert result.answer == CLARIFYING_QUESTIONS["respiratory"]  # type: ignore[attr-defined]
    assert result.awaiting_safety_clarification is True  # type: ignore[attr-defined]
    assert result.safety_clarification_category == "respiratory"  # type: ignore[attr-defined]
    assert client.requests_for("answer") == []


def test_a_vague_maybe_without_a_question_to_ask_lets_the_answer_through() -> None:
    orchestrator, client = _orchestrator(MAYBE_OTHER)

    result = _ask(orchestrator, "oggi mi sembra un po' strano")

    assert result.mode == "natural"  # type: ignore[attr-defined]
    assert len(client.requests_for("answer")) == 1


def test_the_classifier_fails_open() -> None:
    for verdict in (ProviderError("timed out"), "garbage", '{"level": "normal"}'):
        orchestrator, client = _orchestrator(verdict)

        result = _ask(orchestrator, "quante volte al giorno deve mangiare?")

        assert result.mode == "natural"  # type: ignore[attr-defined]
        assert len(client.requests_for("answer")) == 1


def test_the_fixed_lists_decide_first_and_small_talk_is_not_classified() -> None:
    orchestrator, client = _orchestrator(NORMAL)

    listed = _ask(orchestrator, "ha mangiato del veleno per topi")
    _ask(orchestrator, "grazie!")

    assert listed.mode == "triage"  # type: ignore[attr-defined]
    assert client.requests_for("urgency_classifier") == []


def test_any_language_reaches_the_classifier() -> None:
    orchestrator, client = _orchestrator('{"level": "emergency", "category": "toxin_medication"}')

    result = _ask(orchestrator, "my dog drank from a puddle of windshield fluid in the garage")

    assert result.mode == "triage"  # type: ignore[attr-defined]
    assert "windshield fluid" in client.requests_for("urgency_classifier")[0].user_prompt
