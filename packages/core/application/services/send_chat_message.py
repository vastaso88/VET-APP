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
from packages.shared.errors.base import ValidationError


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
    sources: list[EvidenceSource]
    limitations: list[str]
    safety_flags: list[str]
    recommended_action: str | None = None
    provider: str
    model: str
    state: ConversationState
    coverage_score: float | None = None


class SendChatMessageService:
    def __init__(
        self,
        repository: ConversationRepository,
        orchestrator: ChatOrchestrator,
        pet_profile_repository: PetProfileRepository,
    ) -> None:
        self._repository = repository
        self._orchestrator = orchestrator
        self._pet_profile_repository = pet_profile_repository

    def execute(self, data: SendChatMessageInput) -> SendChatMessageOutput:
        if not data.user_message.strip():
            raise ValidationError("user_message must not be empty")
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")

        conversation = self._load_or_create_conversation(data)
        user_message = ChatMessage(role="user", content=data.user_message.strip())
        conversation.messages.append(user_message)

        orchestrator_result = self._orchestrator.answer(
            ChatOrchestratorInput(
                user_message=data.user_message.strip(),
                species=pet_profile.species,
                pet_name=pet_profile.name,
                conversation_history=conversation.messages[:-1],
                situation_model=conversation.situation_model,
                interview_turns_used=conversation.interview_turns_used,
            )
        )
        reply = ChatMessage(role="assistant", content=orchestrator_result.answer)
        conversation.messages.append(reply)
        conversation.situation_model = orchestrator_result.situation_model
        conversation.coverage_score = orchestrator_result.coverage_score
        conversation.state = orchestrator_result.state
        conversation.interview_turns_used = orchestrator_result.interview_turns_used

        stored_conversation = self._repository.save(conversation)
        return SendChatMessageOutput(
            conversation=stored_conversation,
            reply=reply,
            mode=orchestrator_result.mode,
            confidence=orchestrator_result.confidence,
            sources=orchestrator_result.sources,
            limitations=orchestrator_result.limitations,
            safety_flags=orchestrator_result.safety_flags,
            recommended_action=orchestrator_result.recommended_action,
            provider=orchestrator_result.provider,
            model=orchestrator_result.model,
            state=orchestrator_result.state,
            coverage_score=orchestrator_result.coverage_score,
        )

    def _load_or_create_conversation(self, data: SendChatMessageInput) -> Conversation:
        if data.conversation_id:
            stored = self._repository.get(data.conversation_id)
            if stored:
                return stored
            raise ValidationError("conversation not found")
        return Conversation(owner_id=data.owner_id, pet_id=data.pet_id, title=f"Chat for {data.pet_id}")
