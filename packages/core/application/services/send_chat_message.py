from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import PetProfile
from packages.shared.errors.base import ValidationError

# How many recent messages cross into the orchestrator (spec v3 §38: never
# resend the entire history). SituationModelBuilder itself only looks at
# the last 6, so this is a generous ceiling, not the real working window.
MAX_HISTORY_MESSAGES = 12


class SendChatMessageInput(BaseModel):
    owner_id: str
    pet_id: str
    conversation_id: str | None = None
    user_message: str


class SendChatMessageOutput(BaseModel):
    conversation: Conversation
    reply: ChatMessage
    mode: str
    confidence: str
    ai_generated: bool
    sources: list[EvidenceSource]
    limitations: list[str]
    safety_flags: list[str]
    recommended_action: str | None = None
    provider: str
    model: str
    state: ConversationState
    coverage_score: float | None = None
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None


class SendChatMessageService:
    def __init__(
        self,
        repository: ConversationRepository,
        orchestrator: ChatOrchestrator,
        pet_profile_repository: PetProfileRepository,
        *,
        max_active_conversations_per_pet: int = 4,
    ) -> None:
        self._repository = repository
        self._orchestrator = orchestrator
        self._pet_profile_repository = pet_profile_repository
        self._max_active_conversations_per_pet = max_active_conversations_per_pet

    def execute(self, data: SendChatMessageInput) -> SendChatMessageOutput:
        if not data.user_message.strip():
            raise ValidationError("user_message must not be empty")
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")

        conversation = self._load_or_create_conversation(data)
        user_message = ChatMessage(role="user", content=data.user_message.strip())
        conversation.messages.append(user_message)

        # A pet-level consent decision (settings, or a previous conversation)
        # always wins over per-conversation state, so a revocation takes
        # effect immediately and a grant is never asked twice (spec v3 §18).
        medical_record_consent = conversation.medical_record_consent
        awaiting_medical_record_consent = conversation.awaiting_medical_record_consent
        if pet_profile.medical_record_consent is not None:
            medical_record_consent = pet_profile.medical_record_consent.granted
            awaiting_medical_record_consent = False

        orchestrator_result = self._orchestrator.answer(
            ChatOrchestratorInput(
                user_message=data.user_message.strip(),
                species=pet_profile.species,
                pet_name=pet_profile.name,
                pet_id=pet_profile.id,
                breed=pet_profile.breed,
                age_years=pet_profile.age_years,
                notes=pet_profile.notes,
                habitat=pet_profile.habitat,
                aquarium_stock=pet_profile.aquarium_stock,
                # Data minimization (spec v3 §38): only recent turns cross
                # the service boundary — the full history never needs to,
                # since SituationModel already carries the compact,
                # structured summary of everything older forward.
                conversation_history=conversation.messages[:-1][-MAX_HISTORY_MESSAGES:],
                situation_model=conversation.situation_model,
                interview_turns_used=conversation.interview_turns_used,
                medical_record_consent=medical_record_consent,
                awaiting_medical_record_consent=awaiting_medical_record_consent,
                awaiting_safety_clarification=conversation.awaiting_safety_clarification,
                safety_clarification_category=conversation.safety_clarification_category,
            )
        )
        reply = ChatMessage(role="assistant", content=orchestrator_result.answer)
        conversation.messages.append(reply)
        conversation.situation_model = orchestrator_result.situation_model
        conversation.coverage_score = orchestrator_result.coverage_score
        conversation.state = orchestrator_result.state
        conversation.interview_turns_used = orchestrator_result.interview_turns_used
        conversation.medical_record_consent = orchestrator_result.medical_record_consent
        conversation.awaiting_medical_record_consent = (
            orchestrator_result.awaiting_medical_record_consent
        )
        conversation.awaiting_safety_clarification = (
            orchestrator_result.awaiting_safety_clarification
        )
        conversation.safety_clarification_category = (
            orchestrator_result.safety_clarification_category
        )
        self._persist_pet_level_consent(pet_profile, orchestrator_result.medical_record_consent)

        stored_conversation = self._repository.save(conversation)
        return SendChatMessageOutput(
            conversation=stored_conversation,
            reply=reply,
            mode=orchestrator_result.mode,
            confidence=orchestrator_result.confidence,
            ai_generated=orchestrator_result.ai_generated,
            sources=orchestrator_result.sources,
            limitations=orchestrator_result.limitations,
            safety_flags=orchestrator_result.safety_flags,
            recommended_action=orchestrator_result.recommended_action,
            provider=orchestrator_result.provider,
            model=orchestrator_result.model,
            state=orchestrator_result.state,
            coverage_score=orchestrator_result.coverage_score,
            medical_record_consent=orchestrator_result.medical_record_consent,
            awaiting_medical_record_consent=orchestrator_result.awaiting_medical_record_consent,
            awaiting_safety_clarification=orchestrator_result.awaiting_safety_clarification,
            safety_clarification_category=orchestrator_result.safety_clarification_category,
        )

    def _load_or_create_conversation(self, data: SendChatMessageInput) -> Conversation:
        if data.conversation_id:
            stored = self._repository.get(data.conversation_id)
            if stored:
                return stored
            raise ValidationError("conversation not found")

        existing_for_pet = self._repository.list_by_pet(data.pet_id)
        if len(existing_for_pet) >= self._max_active_conversations_per_pet:
            raise ValidationError(
                "conversation_limit_reached: hai raggiunto il numero massimo di "
                f"conversazioni ({self._max_active_conversations_per_pet}) per questo "
                "animale. Chiudine una per crearne una nuova."
            )
        return Conversation(
            owner_id=data.owner_id, pet_id=data.pet_id, title=f"Chat for {data.pet_id}"
        )

    def _persist_pet_level_consent(self, pet_profile: PetProfile, granted: bool | None) -> None:
        if granted is None:
            return
        current = pet_profile.medical_record_consent
        if current is not None and current.granted == granted:
            return
        updated = pet_profile.model_copy(
            update={
                "medical_record_consent": MedicalRecordConsentRecord(
                    granted=granted, version=CURRENT_VERSION
                )
            }
        )
        self._pet_profile_repository.save(updated)
