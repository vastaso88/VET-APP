from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.conversation.title import clean_custom_title
from packages.shared.errors.base import ValidationError


class RenameConversationInput(BaseModel):
    owner_id: str
    conversation_id: str
    title: str


class RenameConversationOutput(BaseModel):
    conversation: Conversation


class RenameConversationService:
    """The owner gives a conversation their own title (PATCH
    /conversations/{id}). Owner-scoped like delete: a conversation that is
    not theirs is reported as not found, never as forbidden."""

    def __init__(self, repository: ConversationRepository) -> None:
        self._repository = repository

    def execute(self, data: RenameConversationInput) -> RenameConversationOutput:
        conversation = self._repository.get(data.conversation_id)
        if conversation is None or conversation.owner_id != data.owner_id:
            raise ValidationError("conversation not found")
        try:
            title = clean_custom_title(data.title)
        except ValueError as exc:
            raise ValidationError("invalid_title: il titolo non può essere vuoto") from exc
        conversation.title = title
        return RenameConversationOutput(conversation=self._repository.save(conversation))
