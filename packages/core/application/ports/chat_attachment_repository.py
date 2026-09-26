from typing import Protocol

from packages.core.domain.conversation.attachment import ChatAttachment


class ChatAttachmentRepository(Protocol):
    def save(self, attachment: ChatAttachment) -> ChatAttachment: ...

    def get(self, attachment_id: str) -> ChatAttachment | None: ...
