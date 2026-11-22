"""The reservation of a chat message across serverless instances (QK-03b).

The lock inside one process (send_chat_message._InFlightMessages) does not stop the same
message from being answered twice when two instances receive it at the same moment. Before the
model is called, the message is reserved in a shared table; a duplicate finds the reservation,
waits, and then finds the stored answer.

Rules this class keeps, in this order of importance:

1. The table is a LOCK, never the source of a replay. Whether a message was answered is always
   decided from the stored conversation (``find_replay``, a fresh read every time). A key that
   says "answered" while nothing is stored (the reply was cut by an edit, the chat was deleted,
   the answer was saved but the key was not marked) is taken over at once, never waited on.
2. A reservation without an answer that is younger than [ORPHAN_SECONDS] belongs to a request
   that is probably still running: wait for it, at most the caller's [wait_seconds], then answer
   anyway (as the in-process lock does) rather than hang the app. An older one belongs to a
   request that died: it is taken over with a conditional update, so of several takers one wins.
3. Whatever goes wrong with the table (missing, unreachable, any error) means "no reservation":
   the chat goes on with the in-process lock only. Nothing here may raise into the chat.
4. A request that fails after reserving drops its own reservation, so a retry does not wait.

Edits of a message (EditChatMessageService) do not go through this; see QK-03b_esito.md.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import TypeVar

from packages.core.application.ports.message_key_repository import MessageKeyRepository

logger = logging.getLogger("vetgpt.message_claims")

T = TypeVar("T")

# A reservation with no answer older than this is an orphan. The model call, with its retries,
# is bounded well below it (the answer path gives up after a few tens of seconds).
ORPHAN_SECONDS = 60.0
POLL_SECONDS = 1.0


@dataclass(frozen=True)
class MessageClaim:
    """The caller's own reservation (what it must mark answered or release)."""

    owner_id: str
    client_message_id: str
    claimed_at: datetime


def _utc_now() -> datetime:
    return datetime.now(UTC)


class MessageClaims:
    def __init__(
        self,
        keys: MessageKeyRepository,
        *,
        clock: Callable[[], datetime] = _utc_now,
        sleep: Callable[[float], None] = time.sleep,
        orphan_seconds: float = ORPHAN_SECONDS,
        poll_seconds: float = POLL_SECONDS,
    ) -> None:
        self._keys = keys
        self._clock = clock
        self._sleep = sleep
        self._orphan_seconds = orphan_seconds
        self._poll_seconds = poll_seconds

    def acquire(
        self,
        owner_id: str,
        client_message_id: str,
        conversation_id: str,
        find_replay: Callable[[], T | None],
        *,
        wait_seconds: float,
    ) -> tuple[T | None, MessageClaim | None]:
        """(replay, None) when the message was already answered; (None, claim) when the caller
        owns it and must answer; (None, None) when no reservation could be made or kept (table
        unavailable, or the first copy took longer than [wait_seconds]): the caller answers
        without one."""
        deadline = self._clock().timestamp() + wait_seconds
        while True:
            now = self._clock()
            try:
                existing = self._keys.claim(owner_id, client_message_id, conversation_id, now)
            except Exception as exc:  # noqa: BLE001 - see rule 3
                logger.debug("message claim unavailable (%s)", type(exc).__name__)
                return None, None
            if existing is None:
                return None, MessageClaim(owner_id, client_message_id, now)
            # Somebody has it. The conversation decides whether it was answered (rule 1).
            replay = find_replay()
            if replay is not None:
                return replay, None
            now = self._clock()
            try:
                taken: bool | None = None
                if existing.answered_reply_id is not None:
                    # "Answered" but nothing stored: nothing to wait for.
                    taken = self._keys.retake(
                        existing, conversation_id, now, require_unanswered=False
                    )
                elif (now - existing.claimed_at).total_seconds() >= self._orphan_seconds:
                    taken = self._keys.retake(
                        existing, conversation_id, now, require_unanswered=True
                    )
            except Exception as exc:  # noqa: BLE001
                logger.debug("message claim unavailable (%s)", type(exc).__name__)
                return None, None
            if taken:
                return None, MessageClaim(owner_id, client_message_id, now)
            if now.timestamp() >= deadline:
                return None, None
            self._sleep(self._poll_seconds)

    def answered(self, claim: MessageClaim, reply_id: str) -> None:
        try:
            self._keys.mark_answered(
                claim.owner_id, claim.client_message_id, reply_id, claim.claimed_at
            )
        except Exception as exc:  # noqa: BLE001 - the key is only a lock; the answer is stored
            logger.debug("message claim not marked (%s)", type(exc).__name__)

    def release(self, claim: MessageClaim) -> None:
        try:
            self._keys.release(claim.owner_id, claim.client_message_id, claim.claimed_at)
        except Exception as exc:  # noqa: BLE001
            logger.debug("message claim not released (%s)", type(exc).__name__)
