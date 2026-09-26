from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class ExtractionAwareLLMClient:
    def __init__(self, extraction_json: str = "{}") -> None:
        self._extraction_json = extraction_json
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        if "extract structured case information" in request.system_prompt:
            content = self._extraction_json
        else:
            content = "Risposta con fonti."
        return LLMResponse(content=content, provider="fake", model="fake-model", token_count=10)


def _orchestrator_with_records(pet_id: str = "pet-1") -> ChatOrchestrator:
    repo = InMemoryClinicalEventRepository(
        seed=[ClinicalEvent(pet_id=pet_id, title="Richiamo vaccinale", subtitle="al completo")]
    )
    return ChatOrchestrator(
        ExtractionAwareLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        medical_record_context_retriever=MedicalRecordContextRetriever(repo),
        enable_interview_loop=True,
    )


def test_asks_for_consent_when_pet_has_records_and_context_is_missing() -> None:
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce", species="dog", pet_name="Milo", pet_id="pet-1"
        )
    )

    assert result.mode == "consent_request"
    assert result.awaiting_medical_record_consent is True
    assert result.medical_record_consent is None
    assert "cartella clinica" in result.answer


def test_granting_consent_merges_record_summary_into_situation() -> None:
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Sì, consultala pure",
            species="dog",
            pet_name="Milo",
            pet_id="pet-1",
            awaiting_medical_record_consent=True,
        )
    )

    assert result.medical_record_consent is True
    assert result.situation_model is not None
    assert "Richiamo vaccinale" in (result.situation_model.known_medical_context or "")
    # Consent was never asked again in this turn.
    assert result.mode != "consent_request"


def test_declining_consent_proceeds_without_medical_context() -> None:
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="No grazie",
            species="dog",
            pet_name="Milo",
            pet_id="pet-1",
            awaiting_medical_record_consent=True,
        )
    )

    assert result.medical_record_consent is False
    assert result.mode != "consent_request"
    assert not (result.situation_model.known_medical_context if result.situation_model else None)


def test_unclear_reply_to_consent_question_is_treated_as_declined() -> None:
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Boh, fai tu",
            species="dog",
            pet_name="Milo",
            pet_id="pet-1",
            awaiting_medical_record_consent=True,
        )
    )

    assert result.medical_record_consent is False


def test_consent_is_never_asked_again_once_resolved() -> None:
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce ancora",
            species="dog",
            pet_name="Milo",
            pet_id="pet-1",
            medical_record_consent=False,
        )
    )

    assert result.mode != "consent_request"


def test_previously_granted_consent_is_used_without_asking_again() -> None:
    # Simulates a standing per-pet consent decision from an earlier
    # conversation (SendChatMessageService seeds this field from
    # PetProfile.medical_record_consent) — the record should be pulled in
    # on the very first turn of a brand new conversation, not just when
    # consent is granted mid-conversation.
    orchestrator = _orchestrator_with_records()

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce",
            species="dog",
            pet_name="Milo",
            pet_id="pet-1",
            medical_record_consent=True,
        )
    )

    assert result.mode != "consent_request"
    assert result.situation_model is not None
    assert "Richiamo vaccinale" in (result.situation_model.known_medical_context or "")


def test_no_consent_request_when_pet_has_no_records() -> None:
    orchestrator = ChatOrchestrator(
        ExtractionAwareLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        medical_record_context_retriever=MedicalRecordContextRetriever(
            InMemoryClinicalEventRepository()
        ),
        enable_interview_loop=True,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce", species="dog", pet_name="Milo", pet_id="pet-1"
        )
    )

    assert result.mode != "consent_request"


def test_no_consent_request_when_retriever_is_not_configured() -> None:
    orchestrator = ChatOrchestrator(
        ExtractionAwareLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        enable_interview_loop=True,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce", species="dog", pet_name="Milo", pet_id="pet-1"
        )
    )

    assert result.mode != "consent_request"
    assert result.state != ConversationState.USER_DECLINED_RECORD_ACCESS
