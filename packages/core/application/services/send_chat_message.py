from datetime import UTC, datetime

from pydantic import BaseModel

from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
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


def owner_names_for_anonymization(display_name: str | None, *, pet_name: str) -> list[str]:
    """The owner's name as a value to redact from text sent to the LLM
    provider — unless it is also the pet's name (people do name a pet
    after themselves, or register with the pet's name): redacting it then
    would blank the one name the conversation is about.
    """
    name = (display_name or "").strip()
    if not name:
        return []
    pet = pet_name.strip().lower()
    if name.lower() == pet or pet in {part.lower() for part in name.split()}:
        return []
    return [name]


class SendChatMessageInput(BaseModel):
    owner_id: str
    pet_id: str
    conversation_id: str | None = None
    user_message: str
    attachment_id: str | None = None
    # The signed-in owner's display name, when the account has one.
    owner_display_name: str | None = None


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
        attachment_repository: ChatAttachmentRepository | None = None,
        reminder_context_retriever: ReminderContextRetriever | None = None,
        max_active_conversations_per_pet: int = 4,
    ) -> None:
        self._repository = repository
        self._orchestrator = orchestrator
        self._pet_profile_repository = pet_profile_repository
        # None simply means this deployment never offers photo attachments,
        # same convention as ChatOrchestrator's optional
        # medical_record_context_retriever.
        self._attachment_repository = attachment_repository
        # None: this deployment's chat doesn't see reminders (same
        # optional-collaborator convention as above).
        self._reminder_context_retriever = reminder_context_retriever
        self._max_active_conversations_per_pet = max_active_conversations_per_pet

    def execute(self, data: SendChatMessageInput) -> SendChatMessageOutput:
        if not data.user_message.strip():
            raise ValidationError("user_message must not be empty")
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")

        conversation = self._load_or_create_conversation(data)
        photo_context = self._resolve_attachment(data, conversation, pet_profile)
        user_message = ChatMessage(
            role="user", content=data.user_message.strip(), attachment_id=data.attachment_id
        )
        conversation.messages.append(user_message)

        # A pet-level consent decision (settings, or a previous conversation)
        # always wins over per-conversation state, so a revocation takes
        # effect immediately and a grant is never asked twice (spec v3 §18).
        medical_record_consent = conversation.medical_record_consent
        awaiting_medical_record_consent = conversation.awaiting_medical_record_consent
        if pet_profile.medical_record_consent is not None:
            medical_record_consent = pet_profile.medical_record_consent.granted
            awaiting_medical_record_consent = False

        today = datetime.now(UTC).date()
        reminders_context = (
            self._reminder_context_retriever.summarize_for_pet(data.owner_id, pet_profile.id, today)
            if self._reminder_context_retriever is not None
            else None
        )

        orchestrator_result = self._orchestrator.answer(
            ChatOrchestratorInput(
                user_message=data.user_message.strip(),
                species=pet_profile.species,
                pet_name=pet_profile.name,
                pet_id=pet_profile.id,
                breed=pet_profile.breed,
                age_years=pet_profile.age_years,
                notes=pet_profile.notes,
                birth_date_label=pet_profile.birth_date_label,
                sex=pet_profile.sex,
                weight_label=pet_profile.weight_label,
                dog_size_category=pet_profile.dog_size_category,
                reminders_context=reminders_context,
                owner_names=owner_names_for_anonymization(
                    data.owner_display_name, pet_name=pet_profile.name
                ),
                today=today,
                habitat=pet_profile.habitat,
                aquarium_stock=pet_profile.aquarium_stock,
                photo_context=photo_context,
                attachment_unreadable=bool(data.attachment_id) and not photo_context,
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

    def _resolve_attachment(
        self,
        data: SendChatMessageInput,
        conversation: Conversation,
        pet_profile: PetProfile,
    ) -> str | None:
        """Returns the attachment's cached visual analysis (or None if
        there's no attachment), and links it to this conversation on
        first use — an attachment can be uploaded before a conversation
        officially exists yet (a brand new chat), so it starts scoped
        only by pet_id (see UploadChatAttachmentService).
        """
        if not data.attachment_id:
            return None
        if self._attachment_repository is None:
            raise ValidationError("attachments are not enabled for this deployment")
        attachment = self._attachment_repository.get(data.attachment_id)
        if attachment is None:
            raise ValidationError("attachment not found")
        if attachment.owner_id != data.owner_id or attachment.pet_id != pet_profile.id:
            raise ValidationError("attachment does not belong to this pet")
        if attachment.conversation_id is None:
            self._attachment_repository.save(
                attachment.model_copy(update={"conversation_id": conversation.id})
            )
        return attachment.analysis

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
