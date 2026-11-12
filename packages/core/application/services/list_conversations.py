from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.services.send_chat_message import migrate_legacy_title
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.conversation.title import is_legacy_title


class ListConversationsInput(BaseModel):
    owner_id: str


class ListConversationsOutput(BaseModel):
    conversations: list[Conversation]


class ListConversationsService:
    def __init__(self, repository: ConversationRepository) -> None:
        self._repository = repository

    def execute(self, data: ListConversationsInput) -> ListConversationsOutput:
        conversations = []
        for conversation in self._repository.list_by_owner(data.owner_id):
            if is_legacy_title(conversation.title):
                migrated = migrate_legacy_title(conversation)
                if migrated.title != conversation.title:
                    # Persisted, so the next listing does not redo it.
                    conversation = self._repository.save(migrated)
            conversations.append(conversation)
        return ListConversationsOutput(conversations=conversations)
