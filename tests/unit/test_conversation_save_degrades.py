"""A conversation is saved even when the live table lacks a state column.

Production 2026-11-16: ``awaiting_anamnesis`` had no column, every save failed
with PGRST204 after the model had answered, and the owner lost the answer.
The chat's own state can be left out (with a warning naming the column); the
messages, the owner and the pet never.
"""

from __future__ import annotations

import logging
from typing import Any

import pytest

from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseConversationRepository,
)


class _MissingColumns(Exception):
    pass


class _Table:
    def __init__(self, client: _Client) -> None:
        self._client = client
        self._payload: dict[str, Any] = {}

    def upsert(self, payload: dict[str, Any]) -> _Table:
        self._payload = dict(payload)
        return self

    def execute(self) -> None:
        self._client.attempts.append(self._payload)
        for column in self._client.missing:
            if column in self._payload:
                raise _MissingColumns(
                    "{'code': 'PGRST204', 'message': \"Could not find the '"
                    + column
                    + "' column of 'conversations' in the schema cache\"}"
                )
        self._client.saved = self._payload


class _Client:
    def __init__(self, *missing: str) -> None:
        self.missing = missing
        self.attempts: list[dict[str, Any]] = []
        self.saved: dict[str, Any] | None = None

    def table(self, name: str) -> _Table:
        assert name == "conversations"
        return _Table(self)


def _conversation() -> Conversation:
    return Conversation(
        owner_id="owner-1",
        pet_id="pet-1",
        title="Zoppia",
        messages=[
            ChatMessage(role="user", content="zoppica"),
            ChatMessage(role="assistant", content="ok"),
        ],
        awaiting_anamnesis=True,
        escalate_next_health=True,
    )


def test_a_complete_schema_saves_everything_in_one_write() -> None:
    client = _Client()
    SupabaseConversationRepository(client).save(_conversation())  # type: ignore[arg-type]

    assert len(client.attempts) == 1
    assert client.saved is not None
    assert client.saved["awaiting_anamnesis"] is True
    assert "last_message_at" in client.saved


def test_missing_state_columns_are_left_out_with_a_warning_and_the_answer_is_saved(
    caplog: pytest.LogCaptureFixture,
) -> None:
    client = _Client("awaiting_anamnesis", "escalate_next_health", "last_message_at")

    with caplog.at_level(logging.WARNING):
        SupabaseConversationRepository(client).save(_conversation())  # type: ignore[arg-type]

    assert client.saved is not None
    assert [m["content"] for m in client.saved["messages"]] == ["zoppica", "ok"]
    for column in ("awaiting_anamnesis", "escalate_next_health", "last_message_at"):
        assert column not in client.saved
        assert f"conversations.{column} missing" in caplog.text
    assert len(client.attempts) == 4  # one retry per missing column, no more
    assert "zoppica" not in caplog.text  # no message text in the logs


@pytest.mark.parametrize("column", ["messages", "owner_id", "pet_id", "title"])
def test_a_missing_core_column_still_fails(column: str) -> None:
    client = _Client(column)
    with pytest.raises(_MissingColumns):
        SupabaseConversationRepository(client).save(_conversation())  # type: ignore[arg-type]
    assert client.saved is None


def test_any_other_error_is_raised_unchanged() -> None:
    class _Down(_Client):
        def table(self, name: str) -> _Table:
            raise ConnectionError("network down")

    with pytest.raises(ConnectionError):
        SupabaseConversationRepository(_Down()).save(_conversation())  # type: ignore[arg-type]
