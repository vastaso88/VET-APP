"""The shared reservation of a chat message (QK-03b), on public.chat_message_keys.

Two requests with the same client_message_id served by two serverless instances at the same
moment used to answer twice. The first to insert the key owns the message; the other waits and
then finds the stored answer (see message_claims.py). Only ids and dates are stored.

The table may not exist yet (the SQL is applied by the owner), or the database may not answer:
every failure here becomes MessageKeysUnavailable, remembered for a few minutes so that a
message does not pay a failing round trip and a log line each time, and the chat goes on with
the lock inside the process. Logs name the class of the error and its code, never its text:
PostgREST echoes key values (the owner id) in its messages.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.message_key_repository import (
    MessageKey,
    MessageKeysUnavailable,
)
from packages.infrastructure.persistence.supabase.missing_table import is_missing_table

if TYPE_CHECKING:
    from supabase import Client

_logger = logging.getLogger(__name__)

# Seconds a missing table / a failing database is not asked again.
_MISSING_TABLE_PAUSE = 300.0
_OTHER_ERROR_PAUSE = 60.0


def _is_unavailable_table(error: BaseException) -> bool:
    if is_missing_table(error):
        return True
    # A 404 from the REST layer (the table or the route is not there).
    return str(getattr(error, "code", "")) == "404" or getattr(error, "status", None) == 404


class SupabaseMessageKeyRepository:
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "chat_message_keys"
        self._paused_until = 0.0

    # --- failures -------------------------------------------------------------------------

    def _guard(self) -> None:
        if time.monotonic() < self._paused_until:
            raise MessageKeysUnavailable("paused after an earlier failure")

    def _fail(self, error: Exception) -> MessageKeysUnavailable:
        missing = _is_unavailable_table(error)
        self._paused_until = time.monotonic() + (
            _MISSING_TABLE_PAUSE if missing else _OTHER_ERROR_PAUSE
        )
        # The class and the code only: never str(error).
        _logger.warning(
            "chat_message_keys unavailable (%s, code=%s, %s): falling back to the in-process lock",
            type(error).__name__,
            getattr(error, "code", None),
            "table missing: run supabase/migrations/20261122120000_chat_message_keys.sql"
            if missing
            else "will retry later",
        )
        return MessageKeysUnavailable(type(error).__name__)

    # --- the port -------------------------------------------------------------------------

    def _row(self, owner_id: str, client_message_id: str) -> dict[str, Any] | None:
        response = (
            self._client.table(self._table)
            .select("owner_id,client_message_id,conversation_id,claimed_at,answered_reply_id")
            .eq("owner_id", owner_id)
            .eq("client_message_id", client_message_id)
            .limit(1)
            .execute()
        )
        rows = cast(list[dict[str, Any]], response.data or [])
        return rows[0] if rows else None

    @staticmethod
    def _key(row: dict[str, Any]) -> MessageKey:
        return MessageKey(
            owner_id=str(row["owner_id"]),
            client_message_id=str(row["client_message_id"]),
            conversation_id=str(row.get("conversation_id") or ""),
            claimed_at=datetime.fromisoformat(str(row["claimed_at"])),
            answered_reply_id=row.get("answered_reply_id"),
            claimed_at_raw=str(row["claimed_at"]),
        )

    def claim(
        self, owner_id: str, client_message_id: str, conversation_id: str, now: datetime
    ) -> MessageKey | None:
        self._guard()
        try:
            # insert ... on conflict do nothing: only a row that was really inserted comes back.
            inserted = (
                self._client.table(self._table)
                .upsert(
                    {
                        "owner_id": owner_id,
                        "client_message_id": client_message_id,
                        "conversation_id": conversation_id,
                        "claimed_at": now.isoformat(),
                    },
                    on_conflict="owner_id,client_message_id",
                    ignore_duplicates=True,
                )
                .execute()
            )
            if inserted.data:
                return None
            row = self._row(owner_id, client_message_id)
        except Exception as exc:  # noqa: BLE001 - any failure falls back, see the module doc
            raise self._fail(exc) from None
        # The key vanished between the two calls (released): the caller asks again.
        return (
            self._key(row)
            if row is not None
            else self.claim(owner_id, client_message_id, conversation_id, now)
        )

    def retake(
        self,
        key: MessageKey,
        conversation_id: str,
        now: datetime,
        *,
        require_unanswered: bool,
    ) -> bool:
        self._guard()
        try:
            query = (
                self._client.table(self._table)
                .update(
                    {
                        "conversation_id": conversation_id,
                        "claimed_at": now.isoformat(),
                        "answered_reply_id": None,
                    }
                )
                .eq("owner_id", key.owner_id)
                .eq("client_message_id", key.client_message_id)
                # exactly as read, so only the key the caller saw can be taken
                .eq("claimed_at", key.claimed_at_raw or key.claimed_at.isoformat())
            )
            if require_unanswered:
                query = query.is_("answered_reply_id", "null")
            response = query.execute()
        except Exception as exc:  # noqa: BLE001
            raise self._fail(exc) from None
        return bool(response.data)

    def mark_answered(
        self, owner_id: str, client_message_id: str, reply_id: str, claimed_at: datetime
    ) -> None:
        self._guard()
        try:
            (
                self._client.table(self._table)
                .update({"answered_reply_id": reply_id})
                .eq("owner_id", owner_id)
                .eq("client_message_id", client_message_id)
                .eq("claimed_at", claimed_at.isoformat())
                .execute()
            )
        except Exception as exc:  # noqa: BLE001
            raise self._fail(exc) from None

    def release(self, owner_id: str, client_message_id: str, claimed_at: datetime) -> None:
        self._guard()
        try:
            (
                self._client.table(self._table)
                .delete()
                .eq("owner_id", owner_id)
                .eq("client_message_id", client_message_id)
                .eq("claimed_at", claimed_at.isoformat())
                .is_("answered_reply_id", "null")
                .execute()
            )
        except Exception as exc:  # noqa: BLE001
            raise self._fail(exc) from None

    def purge_before(self, cutoff: datetime) -> int:
        self._guard()
        try:
            response = (
                self._client.table(self._table)
                .delete()
                .lt("claimed_at", cutoff.isoformat())
                .execute()
            )
        except Exception as exc:  # noqa: BLE001
            raise self._fail(exc) from None
        return len(response.data or [])
