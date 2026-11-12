"""Three consent fixes from the compliance audit (2026-10-06): the inline
question says what really happens, the record summary is anonymized also
inside the situation model, and a v1 decision counts as no decision."""

from fastapi.testclient import TestClient
from test_chat_orchestrator_medical_consent import ExtractionAwareLLMClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.medical_record.consent_text import (
    CURRENT_VERSION,
    INLINE_QUESTION_IT,
    effective_decision,
)
from packages.core.domain.medical_record.models import ClinicalEvent, MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer

SECRET_SUMMARY = "Visita del 12/09/2026, proprietario Mario Rossi, tel. 333 1234567, cistite."


def _records_retriever() -> MedicalRecordContextRetriever:
    return MedicalRecordContextRetriever(
        InMemoryClinicalEventRepository(
            seed=[ClinicalEvent(pet_id="pet-1", title="Visita", subtitle=SECRET_SUMMARY)]
        )
    )


def _interviewing_orchestrator(client: ExtractionAwareLLMClient) -> ChatOrchestrator:
    return ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        RuleBasedPiiAnonymizer(),
        situation_model_builder=SituationModelBuilder(client),
        interview_planner=InterviewPlanner(client),
        medical_record_context_retriever=_records_retriever(),
        enable_interview_loop=True,
    )


# --- A. the inline question -----------------------------------------------------


def test_the_inline_consent_question_is_the_text_on_record() -> None:
    client = ExtractionAwareLLMClient()
    result = _interviewing_orchestrator(client).answer(
        ChatOrchestratorInput(
            user_message="il gatto vomita da due giorni",
            species="cat",
            pet_name="Micia",
            pet_id="pet-1",
            medical_record_consent=None,
        )
    )

    assert result.mode == "consent_request"
    assert result.answer == INLINE_QUESTION_IT.format(pet_name="Micia")
    assert "Guarderò solo" not in result.answer
    assert "tre voci più recenti" in result.answer


# --- B. the record summary inside the situation model -----------------------------


def test_the_record_summary_reaches_the_provider_anonymized_in_every_prompt() -> None:
    client = ExtractionAwareLLMClient()
    orchestrator = _interviewing_orchestrator(client)

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="il gatto vomita da due giorni",
            species="cat",
            pet_name="Micia",
            pet_id="pet-1",
            medical_record_consent=True,
            # The owner's name is known from the account, as in production.
            owner_names=["Mario Rossi"],
        )
    )

    assert result.situation_model is not None
    assert result.situation_model.known_medical_context
    assert "Mario Rossi" not in result.situation_model.known_medical_context
    assert "cistite" in result.situation_model.known_medical_context
    sent = "\n".join(f"{r.system_prompt}\n{r.user_prompt}" for r in client.requests)
    assert client.requests, "the interview loop made model calls"
    assert "Mario Rossi" not in sent
    assert "333 1234567" not in sent
    assert "[TELEFONO]" in sent or "[NOME]" in sent


# --- C. a v1 decision is no decision ------------------------------------------


def test_only_a_decision_under_the_current_text_counts() -> None:
    assert effective_decision(None) is None
    assert effective_decision(MedicalRecordConsentRecord(granted=True, version="v1")) is None
    assert effective_decision(MedicalRecordConsentRecord(granted=False, version="v1")) is None
    assert effective_decision(MedicalRecordConsentRecord(granted=True, version=CURRENT_VERSION))
    assert (
        effective_decision(MedicalRecordConsentRecord(granted=False, version=CURRENT_VERSION))
        is False
    )


class _RecordingOrchestrator:
    def __init__(self) -> None:
        self.inputs: list[ChatOrchestratorInput] = []

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        self.inputs.append(data)
        return ChatOrchestratorResult(
            answer="ok",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
            medical_record_consent=data.medical_record_consent,
        )


def _pet_with(consent: MedicalRecordConsentRecord | None) -> InMemoryPetProfileRepository:
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Micia",
            species="Gatto",
            medical_record_consent=consent,
        )
    )
    return pets


def test_the_chat_treats_a_v1_consent_as_undecided() -> None:
    orchestrator = _RecordingOrchestrator()
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,  # type: ignore[arg-type]
        _pet_with(MedicalRecordConsentRecord(granted=True, version="v1")),
    )

    service.execute(SendChatMessageInput(owner_id="owner-1", pet_id="pet-1", user_message="ciao"))

    [data] = orchestrator.inputs
    assert data.medical_record_consent is None
    assert data.awaiting_medical_record_consent is False


def test_a_current_consent_is_still_honoured() -> None:
    orchestrator = _RecordingOrchestrator()
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,  # type: ignore[arg-type]
        _pet_with(MedicalRecordConsentRecord(granted=True, version=CURRENT_VERSION)),
    )

    service.execute(SendChatMessageInput(owner_id="owner-1", pet_id="pet-1", user_message="ciao"))

    assert orchestrator.inputs[0].medical_record_consent is True


def test_a_new_decision_in_chat_replaces_a_v1_record_even_with_the_same_answer() -> None:
    class Granting(_RecordingOrchestrator):
        def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
            result = super().answer(data)
            result.medical_record_consent = True
            return result

    pets = _pet_with(MedicalRecordConsentRecord(granted=True, version="v1"))
    service = SendChatMessageService(InMemoryConversationRepository(), Granting(), pets)  # type: ignore[arg-type]

    service.execute(SendChatMessageInput(owner_id="owner-1", pet_id="pet-1", user_message="sì"))

    record = pets.get("pet-1").medical_record_consent  # type: ignore[union-attr]
    assert record is not None
    assert record.granted is True
    assert record.version == CURRENT_VERSION


def test_get_consent_reports_a_v1_decision_as_needing_a_new_one() -> None:
    reset_container()
    client = TestClient(app)
    try:
        container = get_container()
        user = container.auth_provider.get_current_user()
        container.pet_profile_repository.save(
            PetProfile(
                id="pet-v1",
                owner_id=user.id,
                name="Micia",
                species="Gatto",
                medical_record_consent=MedicalRecordConsentRecord(granted=True, version="v1"),
            )
        )

        before = client.get("/pets/pet-v1/medical-record-consent").json()
        assert before["granted"] is None
        assert before["needs_decision"] is True
        assert before["recorded_version"] == "v1"
        assert before["current_version"] == CURRENT_VERSION

        assert (
            client.put("/pets/pet-v1/medical-record-consent", json={"granted": True}).status_code
            == 200
        )
        after = client.get("/pets/pet-v1/medical-record-consent").json()
        assert after["granted"] is True
        assert after["needs_decision"] is False
        assert after["recorded_version"] == CURRENT_VERSION

        assert client.get("/pets/not-mine/medical-record-consent").status_code == 400
    finally:
        reset_container()


def test_state_enum_unchanged_for_consent_request() -> None:
    assert ConversationState.NEED_MORE_INFORMATION.value == "NEED_MORE_INFORMATION"
