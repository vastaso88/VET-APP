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
            content = self._evidence_answer
        else:
            content = "Risposta generica."
        return LLMResponse(content=content, provider="fake", model="fake-model", token_count=10)


def _orchestrator(**client_kwargs) -> tuple[ChatOrchestrator, ScriptedLLMClient]:
    client = ScriptedLLMClient(**client_kwargs)
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    return orchestrator, client


def test_valid_evidence_answer_passes_through_unchanged() -> None:
    orchestrator, _ = _orchestrator(evidence_answer="Le fonti [1] indicano di monitorare.")

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "evidence"
    assert result.state != ConversationState.SOURCE_VALIDATION_FAILURE
    assert result.answer == "Le fonti [1] indicano di monitorare."


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
