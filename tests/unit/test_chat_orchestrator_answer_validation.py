import json

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.situation.models import SituationModel
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError


class ScriptedLLMClient:
    """Returns a different canned response depending on which role the
    orchestrator is asking for, keyed by a distinctive substring of the
    system prompt (mirrors how the real prompts already differ per role)."""

    def __init__(self, *, evidence_answer: str = "Risposta con fonti [1].") -> None:
        self._evidence_answer = evidence_answer
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        if "extract structured case information" in request.system_prompt:
            content = "{}"
        elif "evidence-first veterinary assistant" in request.system_prompt:
            content = json.dumps({"supported_claims": [self._evidence_answer]})
        else:
            content = "Risposta generica."
        return LLMResponse(content=content, provider="fake", model="fake-model", token_count=10)


def _orchestrator(**client_kwargs: str) -> tuple[ChatOrchestrator, ScriptedLLMClient]:
    client = ScriptedLLMClient(**client_kwargs)
    # 2026-09-21: this file tests _generate_evidence_answer's citation/
    # synthesis validation mechanics directly, so it opts clinical_question
    # into the strict evidence path explicitly — that mechanism is no
    # longer the default route for it (see chat_orchestrator.py's
    # ChatOrchestrator._strict_evidence_intents), but it's still real,
    # tested code available for a caller who wants it.
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        strict_evidence_intents=frozenset({"clinical_question", "husbandry_question"}),
    )
    return orchestrator, client


def test_valid_evidence_answer_strips_citation_markers_for_non_husbandry_intents() -> None:
    # 2026-09-20 product realignment: evidence still validates the answer
    # internally (see result.evidence_synthesis, unaffected by this),
    # but an everyday concern question shouldn't read like a citation
    # list — only husbandry_question keeps markers visible (see
    # test_husbandry_answers_keep_citation_markers_visible below).
    orchestrator, _ = _orchestrator(evidence_answer="Le fonti [1] indicano di monitorare.")

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "evidence"
    assert result.state != ConversationState.SOURCE_VALIDATION_FAILURE
    assert result.answer == "Le fonti indicano di monitorare."
    assert result.evidence_synthesis is not None
    assert result.evidence_synthesis.supported_claims == ["Le fonti [1] indicano di monitorare."]


def test_husbandry_answers_keep_citation_markers_visible() -> None:
    orchestrator, _ = _orchestrator(evidence_answer="Serve un terrario di almeno 120L [1].")

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Che dimensioni minime deve avere il terrario per un geco?",
            species="Rettili e anfibi",
            pet_name="Spike",
        )
    )

    assert result.mode == "evidence"
    assert "[1]" in result.answer


def test_out_of_range_citation_triggers_validation_failure() -> None:
    orchestrator, _ = _orchestrator(evidence_answer="Come riportato in [9], è tutto normale.")

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.state == ConversationState.SOURCE_VALIDATION_FAILURE
    assert result.sources  # the real sources are still surfaced, just not the flawed narrative
    assert any("citation_out_of_range" in v for v in result.limitations)


def test_absolute_claim_triggers_validation_failure() -> None:
    orchestrator, _ = _orchestrator(
        evidence_answer="Questo trattamento è garantito al 100% secondo [1]."
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.state == ConversationState.SOURCE_VALIDATION_FAILURE


def test_unresolved_safety_critical_unknown_prepends_caution_to_evidence_answer() -> None:
    orchestrator, _ = _orchestrator(evidence_answer="Le fonti [1] suggeriscono di monitorare.")
    situation = SituationModel(
        presenting_problem="tosse",
        onset="due giorni",
        observed_behaviours=["tossisce dopo aver bevuto"],
        contexts=["in casa"],
        known_medical_context="nessuna terapia",
        working_domains=["clinical_question"],
        safety_critical_unknowns=["difficoltà respiratoria non chiarita"],
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce ancora",
            species="dog",
            pet_name="Milo",
            situation_model=situation,
        )
    )

    assert "contatta il veterinario" in result.answer.lower()
    assert any("sicurezza" in limitation.lower() for limitation in result.limitations)


def test_evidence_answer_carries_the_structured_synthesis() -> None:
    orchestrator, _ = _orchestrator(evidence_answer="Le fonti [1] indicano di monitorare.")

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.evidence_synthesis is not None
    assert result.evidence_synthesis.supported_claims == ["Le fonti [1] indicano di monitorare."]


def test_empty_synthesis_falls_back_to_a_natural_answer_for_non_husbandry_strict_intents() -> None:
    # 2026-09-20 real-world finding: evidence retrieval can return real
    # literature that just isn't about the case — EvidenceSynthesizer
    # correctly refuses to fabricate a claim from it. For any strict-
    # evidence intent other than husbandry_question, that no longer
    # dead-ends in a cold validation-failure message; it falls through to
    # the natural-answer path instead (see _generate_natural_answer).
    # husbandry_question is the deliberate exception — see the test
    # below. clinical_question is opted into the strict path here only to
    # exercise this fallback mechanism directly: see
    # ChatOrchestrator._strict_evidence_intents for why it isn't strict
    # by default any more (2026-09-21 realignment).
    class EmptySynthesisThenPlainAnswerClient:
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            if "evidence-first veterinary assistant" in request.system_prompt:
                content = "{}"
            else:
                content = "Osserva l'appetito e l'energia nelle prossime ore."
            return LLMResponse(content=content, provider="fake", model="fake-model", token_count=5)

    orchestrator = ChatOrchestrator(
        EmptySynthesisThenPlainAnswerClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        strict_evidence_intents=frozenset({"clinical_question"}),
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "natural"
    assert result.ai_generated is True
    assert result.answer == "Osserva l'appetito e l'energia nelle prossime ore."
    assert result.sources


def test_empty_synthesis_still_refuses_for_husbandry_questions() -> None:
    class EmptySynthesisClient:
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            return LLMResponse(content="{}", provider="fake", model="fake-model", token_count=5)

    orchestrator = ChatOrchestrator(
        EmptySynthesisClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Che dimensioni minime deve avere il terrario per un geco?",
            species="Rettili e anfibi",
            pet_name="Spike",
        )
    )

    assert result.state == ConversationState.SOURCE_VALIDATION_FAILURE
    assert any("evidence_synthesis_empty" in v for v in result.limitations)


def test_llm_provider_failure_during_synthesis_degrades_gracefully() -> None:
    class FailingClient:
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            if "extract structured case information" in request.system_prompt:
                return LLMResponse(content="{}", provider="fake", model="fake-model", token_count=5)
            raise ProviderError("rate limited")

    orchestrator = ChatOrchestrator(
        FailingClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "natural"
    assert result.state == ConversationState.RETRIEVAL_FAILURE
    assert result.sources  # still surfaced even though the answer call itself failed


def test_general_answer_with_hallucinated_citation_is_rejected() -> None:
    # general_info never provides sources, so any [n] citation the LLM
    # produces there is by definition invented (spec v3 §28).
    class HallucinatingGeneralClient(ScriptedLLMClient):
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            if "veterinary app assistant" in request.system_prompt:
                return LLMResponse(
                    content="Come indicato in [1], è tutto ok.",
                    provider="fake",
                    model="fake-model",
                    token_count=5,
                )
            return super().generate(request)

    orchestrator = ChatOrchestrator(
        HallucinatingGeneralClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(user_message="Ciao, come va oggi?", species="dog", pet_name="Milo")
    )

    assert result.mode == "general"
    assert result.state == ConversationState.SOURCE_VALIDATION_FAILURE
