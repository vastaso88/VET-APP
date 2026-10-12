"""Editing a message the owner already sent (build 28).

As in other chat apps: the edited message replaces the original and
everything after it — later messages and replies — is dropped; the
assistant then answers again from the edited message. There are no
alternative versions to switch between.

The answer goes through exactly the same path as a new message
(SendChatMessageService.respond_in): consent to the medical record, source
relevance, anonymisation, and `client_message_id` so a "Riprova" after a
timeout returns the answer already produced instead of editing twice.
"""

from __future__ import annotations

from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import (
    ChatMessage,
    Conversation,
    ConversationSnapshot,
)
from packages.core.domain.conversation.title import title_from_message
from packages.shared.errors.base import ValidationError


class EditChatMessageInput(BaseModel):
    owner_id: str
    conversation_id: str
    # The server's id of the message, or the app's own id for it
    # (client_message_id): a message sent in this session is known to the
    # app only by the latter until the history is reloaded.
    message_id: str
    # May be empty when the original message has an attachment: the
    # attachment is kept, the text is dropped.
    user_message: str = ""
    # The app's id for the edited message; the same on a retry.
    client_message_id: str | None = None
    owner_display_name: str | None = None


class EditChatMessageService:
    def __init__(
        self, repository: ConversationRepository, send_service: SendChatMessageService
    ) -> None:
        self._repository = repository
        self._send_service = send_service

    def execute(self, data: EditChatMessageInput) -> SendChatMessageOutput:
        conversation = self._repository.get(data.conversation_id)
        if conversation is None or conversation.owner_id != data.owner_id:
            raise ValidationError("conversation not found")

        request = SendChatMessageInput(
            owner_id=data.owner_id,
            pet_id=conversation.pet_id,
            conversation_id=conversation.id,
            user_message=data.user_message.strip(),
            owner_display_name=data.owner_display_name,
            client_message_id=data.client_message_id,
        )
        # A retry of an edit that was already applied: the edited message is
        # in the conversation with this client id (and the original is gone),
        # so hand back its answer instead of editing a second time.
        replay = self._send_service.already_answered(request)
        if replay is not None:
            return replay

        index = _user_message_index(conversation, data.message_id)
        if index is None:
            raise ValidationError("message not found")
        original = conversation.messages[index]
        if not request.user_message and not original.attachment_id:
            raise ValidationError("user_message must not be empty")

        edited = _truncated_before(conversation, index)
        edited.title = _title_after_edit(conversation, index, original, request.user_message)
        request = request.model_copy(update={"attachment_id": original.attachment_id})
        return self._send_service.respond_in(edited, request)


def _user_message_index(conversation: Conversation, message_id: str) -> int | None:
    for index, message in enumerate(conversation.messages):
        if message.role == "user" and message_id in (message.id, message.client_message_id):
            return index
    return None


def _truncated_before(conversation: Conversation, index: int) -> Conversation:
    """The conversation as it stood just before message [index]: later
    messages dropped and the working state put back to what it was after
    the last reply that is kept (stored on that reply)."""
    kept = conversation.messages[:index]
    edited = conversation.model_copy(deep=True, update={"messages": kept})
    last_reply = next((m for m in reversed(kept) if m.role == "assistant"), None)
    edited.restore(
        last_reply.state_after
        if last_reply is not None and last_reply.state_after is not None
        # No reply kept (the first message was edited), or replies stored
        # before snapshots existed: the state a new conversation starts in.
        else ConversationSnapshot()
    )
    return edited


def _title_after_edit(
    conversation: Conversation, index: int, original: ChatMessage, new_text: str
) -> str:
    """The automatic title follows the first message when that message is
    edited; a title the owner gave (anything else) is never touched."""
    is_first = not any(m.role == "user" for m in conversation.messages[:index])
    if is_first and new_text and conversation.title == title_from_message(original.content):
        return title_from_message(new_text)
    return conversation.title
