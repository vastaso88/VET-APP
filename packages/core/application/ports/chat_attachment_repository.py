from datetime import datetime
from typing import Protocol

from packages.core.domain.conversation.attachment import ChatAttachment


class ChatAttachmentRepository(Protocol):
    def save(self, attachment: ChatAttachment) -> ChatAttachment: ...

    def get(self, attachment_id: str) -> ChatAttachment | None: ...

    def list_by_conversation(self, conversation_id: str) -> list[ChatAttachment]: ...

    def list_orphans_before(self, cutoff: datetime, *, limit: int = 200) -> list[ChatAttachment]:
        """Attachments never tied to a conversation, uploaded before [cutoff]."""
        ...

    def delete(self, attachment_id: str) -> None: ...
