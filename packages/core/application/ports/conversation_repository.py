from datetime import datetime
from typing import Protocol

from packages.core.domain.conversation.models import Conversation


class ConversationRepository(Protocol):
    def save(self, conversation: Conversation) -> Conversation: ...

    def get(self, conversation_id: str) -> Conversation | None: ...

    def list_by_owner(self, owner_id: str) -> list[Conversation]: ...

    def list_by_pet(self, pet_id: str) -> list[Conversation]: ...

    def delete(self, conversation_id: str) -> None: ...

    def list_inactive_before(self, cutoff: datetime, *, limit: int = 200) -> list[Conversation]:
        """Conversations whose last message is older than [cutoff] (retention)."""
        ...
