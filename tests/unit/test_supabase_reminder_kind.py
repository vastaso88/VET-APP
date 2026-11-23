"""reminders.kind is NOT NULL with the default 'custom' on the live table (2026-11-23).

A column with a default takes it only when the key is left out: an explicit null is refused.
`Reminder.kind` is optional (a reminder created through the API has none), so the repository
must not send `kind: null`. Synthetic data only."""

from datetime import date
from typing import Any

from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseReminderRepository,
)


class _Upsert:
    def __init__(self, sent: list[dict[str, Any]], payload: dict[str, Any]) -> None:
        self._sent, self._payload = sent, payload

    def execute(self) -> None:
        self._sent.append(self._payload)


class _Table:
    def __init__(self, sent: list[dict[str, Any]]) -> None:
        self._sent = sent

    def upsert(self, payload: dict[str, Any]) -> _Upsert:
        return _Upsert(self._sent, payload)


class _Client:
    def __init__(self) -> None:
        self.sent: list[dict[str, Any]] = []

    def table(self, name: str) -> _Table:
        assert name == "reminders"
        return _Table(self.sent)


def _reminder(**fields: Any) -> Reminder:
    return Reminder(
        id="r1",
        owner_id="owner-a",
        pet_id="pet-a",
        title="Vaccino",
        due_date=date(2026, 12, 1),
        **fields,
    )


def test_a_reminder_without_a_kind_is_saved_without_the_kind_key() -> None:
    client = _Client()

    SupabaseReminderRepository(client).save(_reminder())  # type: ignore[arg-type]

    (payload,) = client.sent
    assert "kind" not in payload  # the database default ('custom') applies
    assert payload["title"] == "Vaccino" and payload["due_date"] == "2026-12-01"
    assert payload["owner_id"] == "owner-a" and payload["is_done"] is False


def test_a_reminder_with_a_kind_keeps_it() -> None:
    client = _Client()

    SupabaseReminderRepository(client).save(_reminder(kind="course"))  # type: ignore[arg-type]

    assert client.sent[0]["kind"] == "course"
