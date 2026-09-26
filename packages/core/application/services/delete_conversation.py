from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.shared.errors.base import ValidationError


class DeleteConversationInput(BaseModel):
    owner_id: str
    conversation_id: str


class DeleteConversationService:
    """Lets an owner free up a slot under the per-pet conversation limit
    (spec v3 §36) by deleting a conversation outright — there's no archive
    concept yet, so this is a real, non-reversible delete."""

    def __init__(self, repository: ConversationRepository) -> None:
        self._repository = repository

    def execute(self, data: DeleteConversationInput) -> None:
        conversation = self._repository.get(data.conversation_id)
        if conversation is None or conversation.owner_id != data.owner_id:
            raise ValidationError("conversation not found")
        self._repository.delete(data.conversation_id)
