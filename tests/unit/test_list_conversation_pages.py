"""QK-12: order and cursor of the light chat list, on the service alone."""

from datetime import UTC, datetime

import pytest

from packages.core.application.services.list_conversations import (
    MAX_PAGE_SIZE,
    ListConversationPageInput,
    ListConversationsService,
    decode_cursor,
    encode_cursor,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
)
from packages.shared.errors.base import ValidationError

SAME_MOMENT = datetime(2026, 11, 1, 9, 0, tzinfo=UTC)


def _chat(
    identifier: str, owner: str = "owner-1", at: datetime | None = SAME_MOMENT
) -> Conversation:
    messages = [ChatMessage(role="user", content="ciao", created_at=at)] if at else []
    return Conversation(id=identifier, owner_id=owner, pet_id="pet-1", title="t", messages=messages)


def _service(*chats: Conversation) -> ListConversationsService:
    repository = InMemoryConversationRepository()
    for chat in chats:
        repository.save(chat)
    return ListConversationsService(repository)


def test_chats_with_the_same_last_activity_page_in_a_stable_order_by_id() -> None:
    service = _service(_chat("a"), _chat("b"), _chat("c"), _chat("d"), _chat("e"))
    seen: list[str] = []
    cursor: str | None = None

    while True:
        page = service.list_page(
            ListConversationPageInput(owner_id="owner-1", limit=2, cursor=cursor)
        )
        seen += [item.id for item in page.items]
        cursor = page.next_cursor
        if cursor is None:
            break

    assert seen == ["e", "d", "c", "b", "a"]  # each once, no gap, no repeat


def test_other_owners_chats_never_appear_nor_move_the_cursor() -> None:
    service = _service(_chat("a"), _chat("z", owner="owner-2"))

    page = service.list_page(ListConversationPageInput(owner_id="owner-1"))

    assert [item.id for item in page.items] == ["a"]
    assert page.next_cursor is None


def test_the_page_size_is_clamped_by_the_service_too() -> None:
    chats = [_chat(f"c{n:03d}") for n in range(MAX_PAGE_SIZE + 5)]
    service = _service(*chats)

    page = service.list_page(ListConversationPageInput(owner_id="owner-1", limit=10_000))

    assert len(page.items) == MAX_PAGE_SIZE
    assert page.next_cursor is not None


def test_the_cursor_round_trips_and_a_malformed_one_is_refused() -> None:
    assert decode_cursor(encode_cursor((SAME_MOMENT, "abc"))) == (SAME_MOMENT, "abc")
    for bad in ["", "###", "e30", "bm90IGpzb24"]:
        with pytest.raises(ValidationError, match="invalid_cursor"):
            decode_cursor(bad)
