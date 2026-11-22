import base64
import binascii
import json
from datetime import UTC, datetime

from pydantic import BaseModel

from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.services.send_chat_message import migrate_legacy_title
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.conversation.title import is_legacy_title
from packages.shared.errors.base import ValidationError

# QK-12: the list the app needs at start is light (no message bodies). The preview is
# the start of the last message, enough for the row of the chat list.
PREVIEW_MAX_CHARS = 160
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 50
_NO_ACTIVITY = datetime.fromtimestamp(0, tz=UTC)


class ListConversationsInput(BaseModel):
    owner_id: str


class ListConversationsOutput(BaseModel):
    conversations: list[Conversation]


class ConversationListItem(BaseModel):
    """One row of the chat list: everything but the messages."""

    id: str
    pet_id: str
    title: str
    # When the last message was written; None for a chat with no message yet.
    last_activity_at: datetime | None = None
    last_message_role: str | None = None
    last_message_preview: str = ""
    message_count: int = 0


class ListConversationPageInput(BaseModel):
    owner_id: str
    limit: int = DEFAULT_PAGE_SIZE
    cursor: str | None = None


class ListConversationPageOutput(BaseModel):
    items: list[ConversationListItem]
    # Opaque; None when there is no further page.
    next_cursor: str | None = None


class GetConversationInput(BaseModel):
    owner_id: str
    conversation_id: str


class GetConversationOutput(BaseModel):
    conversation: Conversation


def _activity(conversation: Conversation) -> datetime:
    if conversation.messages:
        return conversation.messages[-1].created_at
    return _NO_ACTIVITY


def _order_key(conversation: Conversation) -> tuple[datetime, str]:
    """Newest activity first, the id breaking ties: stable across calls, renames
    and deletions (the title is not part of it)."""
    return (_activity(conversation), conversation.id)


def encode_cursor(key: tuple[datetime, str]) -> str:
    payload = json.dumps({"a": key[0].isoformat(), "i": key[1]}, separators=(",", ":"))
    return base64.urlsafe_b64encode(payload.encode()).decode().rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, str]:
    try:
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4))
        data = json.loads(raw)
        activity = datetime.fromisoformat(data["a"])
        identifier = data["i"]
        if not isinstance(identifier, str):
            raise TypeError
        if activity.tzinfo is None:
            activity = activity.replace(tzinfo=UTC)
        return activity, identifier
    except (binascii.Error, ValueError, KeyError, TypeError):
        raise ValidationError("invalid_cursor") from None


def _preview(text: str) -> str:
    collapsed = " ".join(text.split())
    if len(collapsed) <= PREVIEW_MAX_CHARS:
        return collapsed
    return collapsed[: PREVIEW_MAX_CHARS - 1].rstrip() + "…"


def _item(conversation: Conversation) -> ConversationListItem:
    last = conversation.messages[-1] if conversation.messages else None
    return ConversationListItem(
        id=conversation.id,
        pet_id=conversation.pet_id,
        title=conversation.title,
        last_activity_at=last.created_at if last is not None else None,
        last_message_role=last.role if last is not None else None,
        last_message_preview=_preview(last.content) if last is not None else "",
        message_count=len(conversation.messages),
    )


class ListConversationsService:
    def __init__(self, repository: ConversationRepository) -> None:
        self._repository = repository

    def _with_current_title(self, conversation: Conversation) -> Conversation:
        if is_legacy_title(conversation.title):
            migrated = migrate_legacy_title(conversation)
            if migrated.title != conversation.title:
                # Persisted, so the next listing does not redo it.
                return self._repository.save(migrated)
        return conversation

    def execute(self, data: ListConversationsInput) -> ListConversationsOutput:
        """The whole history with every message: the format of the apps already installed
        (GET /conversations). Kept as it was."""
        return ListConversationsOutput(
            conversations=[
                self._with_current_title(conversation)
                for conversation in self._repository.list_by_owner(data.owner_id)
            ]
        )

    def list_page(self, data: ListConversationPageInput) -> ListConversationPageOutput:
        """A page of the chat list without the messages (GET /conversations/summaries).

        Order: last activity, newest first, the id as tie-break; the cursor is that key,
        so a rename or a deletion never shifts the next page. A chat that gets a new message
        while the owner is paging moves to the top and is not repeated further down."""
        limit = max(1, min(data.limit, MAX_PAGE_SIZE))
        after = decode_cursor(data.cursor) if data.cursor else None
        # Only this owner's chats are ever considered (the filter is the repository's).
        ordered = sorted(
            self._repository.list_by_owner(data.owner_id), key=_order_key, reverse=True
        )
        if after is not None:
            ordered = [c for c in ordered if _order_key(c) < after]
        page = ordered[:limit]
        next_cursor = encode_cursor(_order_key(page[-1])) if len(ordered) > limit else None
        return ListConversationPageOutput(
            items=[_item(self._with_current_title(c)) for c in page], next_cursor=next_cursor
        )

    def get_detail(self, data: GetConversationInput) -> GetConversationOutput:
        """One conversation with its messages, for the app opening it. Someone else's chat
        looks exactly like a missing one."""
        conversation = self._repository.get(data.conversation_id)
        if conversation is None or conversation.owner_id != data.owner_id:
            raise ValidationError("conversation not found")
        return GetConversationOutput(conversation=self._with_current_title(conversation))
