"""Retention for the usage ledger and the answer cache (build 33).

Call rows carry no personal data but are only useful for analysis for a
while; the per-owner message counters link an account id to a number and
go sooner; cached answers go when they expire. Idempotent: meant to run on
a schedule (pg_cron in the database, or POST /chat/maintenance from an
external scheduler — see scripts/setup/supabase_schema.sql).
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel, Field

from packages.core.application.ports.answer_cache_repository import AnswerCacheRepository
from packages.core.application.ports.chat_attachment_repository import (
    ChatAttachmentRepository,
)
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.ports.media_storage import MediaStorage

logger = logging.getLogger("vetgpt.retention")

USAGE_RETENTION_DAYS = 90
USER_COUNTER_RETENTION_DAYS = 30


class ChatUsageMaintenanceOutput(BaseModel):
    ran_at: datetime
    deleted: dict[str, int] = Field(default_factory=dict)


class ChatUsageMaintenanceService:
    def __init__(
        self,
        usage_repository: LlmUsageRepository,
        answer_cache: AnswerCacheRepository,
        *,
        usage_days: int = USAGE_RETENTION_DAYS,
        user_days: int = USER_COUNTER_RETENTION_DAYS,
        retention: ChatRetentionService | None = None,
    ) -> None:
        self._retention = retention
        self._usage_repository = usage_repository
        self._answer_cache = answer_cache
        self._usage_days = usage_days
        self._user_days = user_days

    def run(self, now: datetime | None = None) -> ChatUsageMaintenanceOutput:
        moment = now or datetime.now(UTC)
        deleted = dict(
            self._usage_repository.cleanup(
                moment.astimezone(UTC).date(),
                usage_days=self._usage_days,
                user_days=self._user_days,
            )
        )
        deleted["chat_answer_cache"] = max(
            deleted.get("chat_answer_cache", 0), self._answer_cache.purge_expired(moment)
        )
        if self._retention is not None:
            deleted.update(self._retention.run(moment))
        return ChatUsageMaintenanceOutput(ran_at=moment, deleted=deleted)


class ChatRetentionService:
    """Retention of the chat itself (security audit, 2026-10-26): a
    conversation and its files go [retention_months] after its last
    message (0 = never); a file uploaded but never sent in a message goes
    after [orphan_days]. Files first, then rows, so nothing is left in the
    storage bucket without a row pointing at it. Idempotent; one batch of
    at most 200 per run, the next run takes the rest."""

    def __init__(
        self,
        conversations: ConversationRepository,
        attachments: ChatAttachmentRepository,
        media_storage: MediaStorage,
        *,
        retention_months: int = 24,
        orphan_days: int = 7,
    ) -> None:
        self._conversations = conversations
        self._attachments = attachments
        self._media_storage = media_storage
        self._retention_months = max(0, retention_months)
        self._orphan_days = max(1, orphan_days)

    def run(self, now: datetime | None = None) -> dict[str, int]:
        moment = now or datetime.now(UTC)
        conversations_deleted = files_deleted = 0
        if self._retention_months > 0:
            # Calendar months approximated to 30.44 days: close enough for
            # a retention of years, and timezone-safe.
            cutoff = moment - timedelta(days=round(self._retention_months * 30.44))
            for conversation in self._conversations.list_inactive_before(cutoff):
                for attachment in self._attachments.list_by_conversation(conversation.id):
                    self._delete_attachment(attachment.storage_key, attachment.id)
                    files_deleted += 1
                self._conversations.delete(conversation.id)
                conversations_deleted += 1
        orphan_cutoff = moment - timedelta(days=self._orphan_days)
        for attachment in self._attachments.list_orphans_before(orphan_cutoff):
            self._delete_attachment(attachment.storage_key, attachment.id)
            files_deleted += 1
        if conversations_deleted or files_deleted:
            logger.info(
                "chat retention: %s conversations and %s files deleted",
                conversations_deleted,
                files_deleted,
            )
        return {"conversations": conversations_deleted, "chat_attachments": files_deleted}

    def _delete_attachment(self, storage_key: str, attachment_id: str) -> None:
        if storage_key:
            self._media_storage.delete(storage_key)
        self._attachments.delete(attachment_id)
