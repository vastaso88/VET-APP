"""Retention of the chat (security audit, 2026-10-26): conversations and
their files go after the retention period, uploads never sent go sooner,
and the job is idempotent."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from packages.core.application.services.maintain_chat_usage import (
    ChatRetentionService,
    ChatUsageMaintenanceService,
)
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
    InMemoryChatAttachmentRepository,
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
)

NOW = datetime(2026, 10, 26, 12, 0, tzinfo=UTC)


class _Storage:
    def __init__(self) -> None:
        self.files: dict[str, bytes] = {}

    def save(self, key: str, content: bytes) -> None:
        self.files[key] = content

    def read(self, key: str) -> bytes | None:
        return self.files.get(key)

    def delete(self, key: str) -> None:
        self.files.pop(key, None)


def _conversation(conversation_id: str, days_ago: int) -> Conversation:
    when = NOW - timedelta(days=days_ago)
    return Conversation(
        id=conversation_id,
        owner_id="anna",
        pet_id="p1",
        title="t",
        messages=[
            ChatMessage(role="user", content="ciao", created_at=when - timedelta(minutes=1)),
            ChatMessage(role="assistant", content="Ciao!", created_at=when),
        ],
    )


def _attachment(
    storage: _Storage, attachment_id: str, conversation_id: str | None, days_ago: int
) -> ChatAttachment:
    storage.save(attachment_id, b"bytes")
    return ChatAttachment(
        id=attachment_id,
        owner_id="anna",
        pet_id="p1",
        conversation_id=conversation_id,
        storage_key=attachment_id,
        content_type="image/jpeg",
        original_filename="f.jpg",
        created_at=NOW - timedelta(days=days_ago),
    )


def test_old_conversations_go_with_their_files_and_recent_ones_stay() -> None:
    conversations = InMemoryConversationRepository()
    attachments = InMemoryChatAttachmentRepository()
    storage = _Storage()
    conversations.save(_conversation("old", days_ago=800))
    conversations.save(_conversation("recent", days_ago=30))
    attachments.save(_attachment(storage, "a-old", "old", days_ago=800))
    attachments.save(_attachment(storage, "a-recent", "recent", days_ago=30))
    service = ChatRetentionService(
        conversations, attachments, storage, retention_months=24, orphan_days=7
    )

    deleted = service.run(NOW)

    assert deleted == {"conversations": 1, "chat_attachments": 1}
    assert conversations.get("old") is None and conversations.get("recent") is not None
    assert attachments.get("a-old") is None and attachments.get("a-recent") is not None
    assert "a-old" not in storage.files and "a-recent" in storage.files
    # Idempotent.
    assert service.run(NOW) == {"conversations": 0, "chat_attachments": 0}


def test_uploads_never_sent_in_a_message_go_after_a_week() -> None:
    conversations = InMemoryConversationRepository()
    attachments = InMemoryChatAttachmentRepository()
    storage = _Storage()
    attachments.save(_attachment(storage, "orphan-old", None, days_ago=8))
    attachments.save(_attachment(storage, "orphan-new", None, days_ago=2))

    deleted = ChatRetentionService(conversations, attachments, storage, orphan_days=7).run(NOW)

    assert deleted == {"conversations": 0, "chat_attachments": 1}
    assert attachments.get("orphan-old") is None and "orphan-old" not in storage.files
    assert attachments.get("orphan-new") is not None


def test_a_retention_of_zero_keeps_every_conversation() -> None:
    conversations = InMemoryConversationRepository()
    conversations.save(_conversation("old", days_ago=3000))

    deleted = ChatRetentionService(
        conversations, InMemoryChatAttachmentRepository(), _Storage(), retention_months=0
    ).run(NOW)

    assert deleted["conversations"] == 0
    assert conversations.get("old") is not None


def test_the_maintenance_job_reports_the_retention_counts_too() -> None:
    conversations = InMemoryConversationRepository()
    conversations.save(_conversation("old", days_ago=800))
    retention = ChatRetentionService(
        conversations, InMemoryChatAttachmentRepository(), _Storage(), retention_months=24
    )

    output = ChatUsageMaintenanceService(
        InMemoryLlmUsageRepository(), InMemoryAnswerCacheRepository(), retention=retention
    ).run(NOW)

    assert output.deleted["conversations"] == 1
    assert set(output.deleted) >= {
        "llm_usage",
        "chat_user_daily_usage",
        "chat_answer_cache",
        "conversations",
        "chat_attachments",
    }
