"""QK-03b: the Supabase adapter of the message keys, on a fake client (nothing leaves the
machine) that behaves like PostgREST where it matters: ``upsert(..., ignore_duplicates=True)``
returns only a row that was really inserted (an empty list on conflict), conditional updates
return the rows they changed, and a missing table raises an error with the PGRST205 / 42P01
code. The adapter must never log the text of an error: PostgREST echoes key values in it."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.message_key_repository import MessageKeysUnavailable
from packages.core.application.services.prune_chat_message_keys import (
    PruneChatMessageKeysService,
)
from packages.infrastructure.persistence.supabase.supabase_message_key_repository import (
    SupabaseMessageKeyRepository,
)

NOW = datetime(2026, 11, 22, 10, 0, 0, 123456, tzinfo=UTC)
OWNER = "owner-aaaa-1111"
CLIENT_ID = "user-5f3a9c0d1e2b"


class _ApiError(Exception):
    def __init__(self, message: str, code: str) -> None:
        super().__init__(message)
        self.code = code


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, db: _Database, operation: str, payload: Any = None, **options: Any) -> None:
        self._db = db
        self._operation = operation
        self._payload = payload
        self._options = options
        self._filters: list[Any] = []
        self._limit: int | None = None

    def select(self, *_: Any) -> _Query:
        return self

    def eq(self, column: str, value: Any) -> _Query:
        self._filters.append(lambda row: _same(row.get(column), value))
        return self

    def lt(self, column: str, value: Any) -> _Query:
        self._filters.append(lambda row: _parse(row[column]) < _parse(value))
        return self

    def is_(self, column: str, value: str) -> _Query:
        assert value == "null"
        self._filters.append(lambda row: row.get(column) is None)
        return self

    def limit(self, count: int) -> _Query:
        self._limit = count
        return self

    def execute(self) -> _Response:
        db = self._db
        db.requests.append(self._operation)
        if db.error is not None:
            raise db.error
        key = ("owner_id", "client_message_id")
        if self._operation == "upsert":
            row = dict(self._payload)
            assert self._options["ignore_duplicates"] is True
            assert self._options["on_conflict"] == "owner_id,client_message_id"
            if any(all(r[k] == row[k] for k in key) for r in db.rows):
                return _Response([])  # on conflict do nothing: nothing comes back
            row.setdefault("answered_reply_id", None)
            db.rows.append(row)
            return _Response([row])
        matching = [r for r in db.rows if all(f(r) for f in self._filters)]
        if self._operation == "select":
            return _Response(matching[: self._limit])
        if self._operation == "update":
            for row in matching:
                row.update(self._payload)
            return _Response(matching)
        if self._operation == "delete":
            db.rows = [r for r in db.rows if r not in matching]
            return _Response(matching)
        raise AssertionError(self._operation)


def _parse(value: Any) -> datetime:
    return value if isinstance(value, datetime) else datetime.fromisoformat(str(value))


def _same(stored: Any, wanted: Any) -> bool:
    if isinstance(wanted, str) and stored is not None and "T" in str(stored):
        return _parse(stored) == _parse(wanted)
    return bool(stored == wanted)


class _Table:
    def __init__(self, db: _Database) -> None:
        self._db = db

    def upsert(self, payload: dict[str, Any], **options: Any) -> _Query:
        return _Query(self._db, "upsert", payload, **options)

    def select(self, *args: Any) -> _Query:
        return _Query(self._db, "select")

    def update(self, payload: dict[str, Any]) -> _Query:
        return _Query(self._db, "update", payload)

    def delete(self) -> _Query:
        return _Query(self._db, "delete")


class _Database:
    def __init__(self) -> None:
        self.rows: list[dict[str, Any]] = []
        self.error: Exception | None = None
        self.requests: list[str] = []

    def table(self, name: str) -> _Table:
        assert name == "chat_message_keys"
        return _Table(self)


def _repo() -> tuple[SupabaseMessageKeyRepository, _Database]:
    db = _Database()
    return SupabaseMessageKeyRepository(db), db  # type: ignore[arg-type]


def test_the_first_claim_inserts_and_a_second_finds_the_key_unchanged() -> None:
    repo, db = _repo()

    assert repo.claim(OWNER, CLIENT_ID, "chat-1", NOW) is None
    seen = repo.claim(OWNER, CLIENT_ID, "chat-2", NOW + timedelta(seconds=5))

    assert seen is not None
    assert seen.conversation_id == "chat-1" and seen.answered_reply_id is None
    assert len(db.rows) == 1 and db.rows[0]["conversation_id"] == "chat-1"


def test_user_b_with_the_same_client_id_gets_a_key_of_their_own() -> None:
    repo, db = _repo()
    repo.claim(OWNER, CLIENT_ID, "chat-a", NOW)

    assert repo.claim("owner-bbbb-2222", CLIENT_ID, "chat-b", NOW) is None
    assert len(db.rows) == 2


def test_retake_is_conditional_on_the_key_as_it_was_read() -> None:
    repo, db = _repo()
    repo.claim(OWNER, CLIENT_ID, "dead", NOW)
    seen = repo.claim(OWNER, CLIENT_ID, "x", NOW)
    assert seen is not None
    later = NOW + timedelta(seconds=90)

    assert repo.retake(seen, "mine", later, require_unanswered=True) is True
    # a second taker still holds the old claimed_at: it loses
    assert repo.retake(seen, "other", later, require_unanswered=True) is False
    assert db.rows[0]["conversation_id"] == "mine"


def test_retake_of_an_unanswered_key_refuses_a_key_that_was_answered_meanwhile() -> None:
    repo, db = _repo()
    repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)
    seen = repo.claim(OWNER, CLIENT_ID, "x", NOW)
    assert seen is not None
    repo.mark_answered(OWNER, CLIENT_ID, "reply-1", NOW)  # the first copy finished

    assert repo.retake(seen, "mine", NOW + timedelta(seconds=90), require_unanswered=True) is False
    # but an answered key whose reply vanished may be taken (the data decided, not the table)
    answered = repo.claim(OWNER, CLIENT_ID, "x", NOW)
    assert answered is not None and answered.answered_reply_id == "reply-1"
    assert repo.retake(answered, "mine", NOW + timedelta(seconds=90), require_unanswered=False)
    assert db.rows[0]["answered_reply_id"] is None and db.rows[0]["conversation_id"] == "mine"


def test_release_removes_only_the_callers_own_unanswered_key() -> None:
    repo, db = _repo()
    repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)

    repo.release(OWNER, CLIENT_ID, NOW + timedelta(seconds=1))  # someone else's claim time
    assert len(db.rows) == 1
    repo.mark_answered(OWNER, CLIENT_ID, "reply-1", NOW)
    repo.release(OWNER, CLIENT_ID, NOW)  # answered: stays
    assert len(db.rows) == 1
    db.rows[0]["answered_reply_id"] = None
    repo.release(OWNER, CLIENT_ID, NOW)
    assert db.rows == []


def test_purge_removes_only_the_old_keys_and_counts_them() -> None:
    repo, db = _repo()
    repo.claim(OWNER, "old-1", "c", NOW - timedelta(days=40))
    repo.claim(OWNER, "old-2", "c", NOW - timedelta(days=31))
    repo.claim(OWNER, "recent", "c", NOW - timedelta(days=2))

    assert repo.purge_before(NOW - timedelta(days=30)) == 2
    assert [r["client_message_id"] for r in db.rows] == ["recent"]


@pytest.mark.parametrize("code", ["PGRST205", "42P01", "404"])
def test_a_missing_table_is_unavailable_and_not_asked_again_for_a_while(code: str) -> None:
    repo, db = _repo()
    db.error = _ApiError("Could not find the table 'public.chat_message_keys'", code)

    with pytest.raises(MessageKeysUnavailable):
        repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)
    asked = len(db.requests)
    with pytest.raises(MessageKeysUnavailable):
        repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)
    with pytest.raises(MessageKeysUnavailable):
        repo.mark_answered(OWNER, CLIENT_ID, "r", NOW)

    assert len(db.requests) == asked  # the pause: no round trip, no log


def test_any_other_error_is_unavailable_too_never_raised_into_the_chat() -> None:
    repo, db = _repo()
    db.error = RuntimeError("connection reset")

    with pytest.raises(MessageKeysUnavailable):
        repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)


def test_the_log_names_the_class_and_the_code_never_the_text_of_the_error(
    caplog: pytest.LogCaptureFixture,
) -> None:
    caplog.set_level(logging.DEBUG)
    repo, db = _repo()
    db.error = _ApiError(
        f"duplicate key value violates (owner_id, client_message_id)=({OWNER}, {CLIENT_ID})",
        "23505",
    )

    with pytest.raises(MessageKeysUnavailable) as raised:
        repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)

    logged = "\n".join(record.getMessage() for record in caplog.records)
    assert "_ApiError" in logged and "23505" in logged
    for secret in (OWNER, CLIENT_ID, "duplicate key"):
        assert secret not in logged
        assert secret not in str(raised.value)


def test_missing_table_log_tells_the_owner_which_migration_to_run(
    caplog: pytest.LogCaptureFixture,
) -> None:
    caplog.set_level(logging.WARNING)
    repo, db = _repo()
    db.error = _ApiError("table not found", "PGRST205")

    with pytest.raises(MessageKeysUnavailable):
        repo.claim(OWNER, CLIENT_ID, "chat-1", NOW)

    logged = "\n".join(record.getMessage() for record in caplog.records)
    assert "20261122120000_chat_message_keys.sql" in logged
    assert len([r for r in caplog.records if r.levelno >= logging.WARNING]) == 1


# --- the retention step --------------------------------------------------------------------


def test_the_prune_step_removes_old_keys() -> None:
    repo, db = _repo()
    repo.claim(OWNER, "old", "c", NOW - timedelta(days=45))
    repo.claim(OWNER, "recent", "c", NOW - timedelta(days=1))

    out = PruneChatMessageKeysService(repo).run(NOW)

    assert out.deleted == 1 and out.table_available is True
    assert [r["client_message_id"] for r in db.rows] == ["recent"]


def test_the_prune_step_answers_with_zero_while_the_table_is_missing() -> None:
    repo, db = _repo()
    db.error = _ApiError("table not found", "PGRST205")

    out = PruneChatMessageKeysService(repo).run(NOW)

    assert out.deleted == 0 and out.table_available is False


# --- the SQL ------------------------------------------------------------------------------


def test_the_schema_script_carries_the_same_sql_as_the_migration() -> None:
    from pathlib import Path

    migration = Path("supabase/migrations/20261122120000_chat_message_keys.sql").read_text(
        encoding="utf-8"
    )
    schema = Path("scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")

    assert migration.replace("\r\n", "\n") in schema.replace("\r\n", "\n")
    for required in (
        "enable row level security",
        "revoke all on public.chat_message_keys from public, anon, authenticated",
        "chat_message_keys_own",
        "primary key (owner_id, client_message_id)",
    ):
        assert required in migration
