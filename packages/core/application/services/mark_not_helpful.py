"""\"Non mi ha aiutato\" under a health answer (plan \"fratello maggiore\",
2026-11-10, contract agreed with the app session).

Marks the assistant message and arms the conversation: its next health answer
is written by the more capable model, within the plan's daily cap (the chat
decides; this service only records). Owner-scoped like every route: a
conversation or message that is not the owner's, a message that is not an
assistant's health answer, all read as "not found". Idempotent, and it costs
no question of the daily allowance.
"""

from __future__ import annotations

from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.shared.errors.base import ValidationError


class MarkNotHelpfulInput(BaseModel):
    owner_id: str
    conversation_id: str
    message_id: str


class MarkNotHelpfulService:
    def __init__(self, repository: ConversationRepository) -> None:
        self._repository = repository

    def execute(self, data: MarkNotHelpfulInput) -> None:
        conversation = self._repository.get(data.conversation_id)
        if conversation is None or conversation.owner_id != data.owner_id:
            raise ValidationError("conversation not found")
        message = next((m for m in conversation.messages if m.id == data.message_id), None)
        if message is None or message.role != "assistant" or not message.health_answer:
            raise ValidationError("message not found")
        if message.not_helpful:
            return
        message.not_helpful = True
        conversation.escalate_next_health = True
        self._repository.save(conversation)
