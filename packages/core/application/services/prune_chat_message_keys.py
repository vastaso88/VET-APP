"""Retention of the chat message keys (QK-03b): a key is a lock for the minutes a message is
being answered; after 30 days it is only a row. Meant for the hourly job
(POST /admin/lifecycle/prune-chat-message-keys). Idempotent. When the table is not there yet
(the SQL is applied by the owner) it removes nothing and says so: the job must not go red."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.message_key_repository import (
    MessageKeyRepository,
    MessageKeysUnavailable,
)

CHAT_MESSAGE_KEY_RETENTION_DAYS = 30


class PruneChatMessageKeysOutput(BaseModel):
    ran_at: datetime
    deleted: int = 0
    # False when the table is not available (not created yet, or the database did not answer).
    table_available: bool = True


class PruneChatMessageKeysService:
    def __init__(
        self,
        keys: MessageKeyRepository,
        *,
        days: int = CHAT_MESSAGE_KEY_RETENTION_DAYS,
    ) -> None:
        self._keys = keys
        self._days = max(1, days)

    def run(self, now: datetime | None = None) -> PruneChatMessageKeysOutput:
        moment = now or datetime.now(UTC)
        try:
            deleted = self._keys.purge_before(moment - timedelta(days=self._days))
        except MessageKeysUnavailable:
            return PruneChatMessageKeysOutput(ran_at=moment, deleted=0, table_available=False)
        return PruneChatMessageKeysOutput(ran_at=moment, deleted=deleted)
