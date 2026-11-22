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

    def list_recent_for_context(
        self,
        owner_id: str,
        pet_id: str,
        *,
        exclude_conversation_id: str | None,
        active_since: datetime,
        limit: int,
    ) -> list[Conversation]:
        """The owner's conversations about this pet, except [exclude_conversation_id], whose
        last message is at or after [active_since]: the most recent [limit] at most, most
        recent first (QK-11: the other chats the v2 answer may mention, without reading every
        conversation of the pet). The caller still checks owner, pet and the date of each
        message; a row whose stored last-message date is unknown is judged by its messages."""
        ...
