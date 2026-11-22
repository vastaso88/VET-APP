from datetime import datetime
from typing import Protocol

from pydantic import BaseModel


class MessageKeysUnavailable(Exception):
    """The shared store of message keys cannot be used right now (the table is not there yet,
    the database does not answer). Never fatal: the chat falls back to the in-process lock."""


class MessageKey(BaseModel):
    """One message of the app, reserved before the model is called (QK-03b).

    Only ids and dates: no text, no e-mail, no name."""

    owner_id: str
    client_message_id: str
    conversation_id: str
    claimed_at: datetime
    answered_reply_id: str | None = None
    # claimed_at exactly as the store returned it, sent back unchanged by [retake].
    claimed_at_raw: str | None = None


class MessageKeyRepository(Protocol):
    """A lock that survives across serverless instances. It is only a lock: whether a message
    was answered is always decided from the stored conversation, never from this table."""

    def claim(
        self, owner_id: str, client_message_id: str, conversation_id: str, now: datetime
    ) -> MessageKey | None:
        """Reserves the message. None = reserved now by the caller; otherwise the key that
        was already there (nothing is changed)."""
        ...

    def retake(
        self,
        key: MessageKey,
        conversation_id: str,
        now: datetime,
        *,
        require_unanswered: bool,
    ) -> bool:
        """Takes over [key] (as read) for the caller, only if nobody changed it meanwhile:
        one conditional update on its claimed_at (and, when [require_unanswered], on
        answered_reply_id still being null). True = the caller owns it now."""
        ...

    def mark_answered(
        self, owner_id: str, client_message_id: str, reply_id: str, claimed_at: datetime
    ) -> None: ...

    def release(self, owner_id: str, client_message_id: str, claimed_at: datetime) -> None:
        """Drops the caller's own reservation if it is still unanswered (the request failed)."""
        ...

    def purge_before(self, cutoff: datetime) -> int:
        """Removes the keys claimed before [cutoff] (retention). Returns how many."""
        ...
