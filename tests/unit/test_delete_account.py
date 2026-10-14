"""Account deletion: nothing of the owner is left, nothing of anyone else is touched."""

from __future__ import annotations

import re
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.services.delete_account import (
    DeleteAccountInput,
    DeleteAccountService,
)
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.radar_reports.models import contributor_pseudonym
from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
    CHAT_REPORT_REF,
    HANDLED_ELSEWHERE,
    NOT_PERSONAL_TABLES,
    OWNER_TABLES,
    RADAR_PSEUDONYM_TABLES,
    SupabaseAccountEraser,
)

RADAR_KEY = "radar-test-key"
CHAT_SECRET = "chat-test-secret"
MEDIA_BUCKET = "chat-attachments"


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, db: dict[str, list[dict[str, Any]]], table: str) -> None:
        self._db = db
        self._table = table
        self._delete = False
        self._filters: list[Callable[[dict[str, Any]], bool]] = []

    def select(self, _columns: str) -> _Query:
        return self

    def delete(self) -> _Query:
        self._delete = True
        return self

    def eq(self, column: str, value: str) -> _Query:
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def in_(self, column: str, values: list[str]) -> _Query:
        self._filters.append(lambda row: row.get(column) in values)
        return self

    def execute(self) -> _Response:
        rows = self._db.setdefault(self._table, [])
        matching = [row for row in rows if all(f(row) for f in self._filters)]
        if self._delete:
            self._db[self._table] = [row for row in rows if row not in matching]
        return _Response([dict(row) for row in matching])


_Entries = list[dict[str, Any]]
_Paths = list[str]


class _Bucket:
    def __init__(self, objects: set[str]) -> None:
        self._objects = objects

    def list(self, prefix: str, options: dict[str, int] | None = None) -> _Entries:
        depth = len(prefix.split("/")) if prefix else 0
        entries: dict[str, dict[str, Any]] = {}
        for path in self._objects:
            parts = path.split("/")
            if path.startswith(prefix + "/") and len(parts) > depth:
                name = parts[depth]
                is_file = len(parts) == depth + 1
                entries[name] = {"name": name, "id": "file-id" if is_file else None}
        page = [entries[name] for name in sorted(entries)]
        window = options or {}
        start = window.get("offset", 0)
        return page[start : start + window.get("limit", len(page))]

    def remove(self, paths: _Paths) -> None:
        self._objects.difference_update(paths)


class _Storage:
    def __init__(self, buckets: dict[str, set[str]]) -> None:
        self._buckets = buckets

    def from_(self, bucket: str) -> _Bucket:
        return _Bucket(self._buckets.setdefault(bucket, set()))


class _Admin:
    def __init__(self) -> None:
        self.deleted_users: list[str] = []

    def delete_user(self, user_id: str) -> None:
        self.deleted_users.append(user_id)


class _Auth:
    def __init__(self) -> None:
        self.admin = _Admin()


class FakeSupabase:
    def __init__(self) -> None:
        self.db: dict[str, list[dict[str, Any]]] = {}
        self.buckets: dict[str, set[str]] = {}
        self.storage = _Storage(self.buckets)
        self.auth = _Auth()

    def table(self, name: str) -> _Query:
        return _Query(self.db, name)


def _seed(client: FakeSupabase, owner: str, *, tag: str) -> None:
    """One row per owned table, shaped the way the real schema keys it."""
    for table, column in OWNER_TABLES:
        client.db.setdefault(table, []).append({"id": f"{tag}-{table}", column: owner})
    client.db["pet_profiles"][-1]["id"] = f"{tag}-pet"
    client.db.setdefault("clinical_events", []).append(
        {"id": f"{tag}-event", "pet_id": f"{tag}-pet"}
    )
    client.db["chat_attachments"][-1]["storage_key"] = f"{tag}-attachment-key"
    client.db["chat_response_reports"].append(
        {"id": f"{tag}-ref-report", CHAT_REPORT_REF[1]: reporter_ref(owner, CHAT_SECRET)}
    )
    for table, column in RADAR_PSEUDONYM_TABLES:
        client.db.setdefault(table, []).append(
            {"id": f"{tag}-{table}", column: contributor_pseudonym(owner, key=RADAR_KEY)}
        )
    client.buckets.setdefault(MEDIA_BUCKET, set()).add(f"{tag}-attachment-key")
    client.buckets.setdefault("pet-photos", set()).update(
        {f"{owner}/pets/{tag}-pet/a.jpg", f"{owner}/account/avatar.jpg"}
    )
    client.buckets.setdefault("marketplace-photos", set()).add(f"{owner}/listing/1.jpg")


def _eraser(client: FakeSupabase, *, radar_key: str | None = RADAR_KEY) -> SupabaseAccountEraser:
    return SupabaseAccountEraser(
        client,  # type: ignore[arg-type]
        media_bucket=MEDIA_BUCKET,
        chat_reporter_secret=CHAT_SECRET,
        radar_pseudonym_key=radar_key,
    )


def _snapshot(client: FakeSupabase) -> tuple[Any, Any]:
    rows = {table: [dict(row) for row in rows] for table, rows in client.db.items()}
    files = {bucket: set(paths) for bucket, paths in client.buckets.items()}
    return rows, files


def test_deleting_an_account_leaves_no_data_of_that_owner_and_none_of_others_touched() -> None:
    client = FakeSupabase()
    _seed(client, "user-a", tag="a")
    _seed(client, "user-b", tag="b")
    client.db["data_sources"] = [{"id": "shared-source"}]
    client.db["events"] = [{"id": "shared-event"}]

    before_rows, before_files = _snapshot(client)
    report = DeleteAccountService(_eraser(client)).execute(DeleteAccountInput(owner_id="user-a"))

    # Nothing that mentions user A (by id, pseudonym or storage path) is left.
    pseudonyms = {
        contributor_pseudonym("user-a", key=RADAR_KEY),
        reporter_ref("user-a", CHAT_SECRET),
    }
    for table, rows in client.db.items():
        for row in rows:
            assert "user-a" not in row.values(), (table, row)
            assert pseudonyms.isdisjoint(row.values()), (table, row)
            assert row.get("pet_id") != "a-pet", (table, row)
    assert all(not path.startswith("user-a/") for path in client.buckets["pet-photos"])
    assert all(not path.startswith("user-a/") for path in client.buckets["marketplace-photos"])
    assert "a-attachment-key" not in client.buckets[MEDIA_BUCKET]

    # Every row and file of user B and the shared catalogues is exactly as before.
    for table, rows in before_rows.items():
        kept = [row for row in rows if not _mentions_a(row)]
        assert client.db[table] == kept, table
    for bucket, paths in before_files.items():
        assert client.buckets[bucket] == {
            p for p in paths if "user-a" not in p and p != "a-attachment-key"
        }

    assert client.auth.admin.deleted_users == ["user-a"]
    assert report.files_removed == 4
    assert report.rows_deleted["pet_profiles"] == 1
    assert report.rows_deleted["clinical_events"] == 1


def _mentions_a(row: dict[str, Any]) -> bool:
    values = set(row.values())
    return (
        "user-a" in values
        or row.get("pet_id") == "a-pet"
        or contributor_pseudonym("user-a", key=RADAR_KEY) in values
        or reporter_ref("user-a", CHAT_SECRET) in values
    )


def test_a_gallery_bigger_than_one_storage_page_is_fully_removed() -> None:
    client = FakeSupabase()
    _seed(client, "user-a", tag="a")
    client.buckets["pet-photos"].update({f"user-a/pets/a-pet/{n:04d}.jpg" for n in range(250)})
    client.buckets["pet-photos"].add("user-b/pets/b-pet/keep.jpg")

    report = _eraser(client).erase_data("user-a")

    assert client.buckets["pet-photos"] == {"user-b/pets/b-pet/keep.jpg"}
    assert report.files_removed == 1 + 2 + 250 + 1


def test_deleting_twice_is_harmless() -> None:
    client = FakeSupabase()
    _seed(client, "user-a", tag="a")
    service = DeleteAccountService(_eraser(client))
    service.execute(DeleteAccountInput(owner_id="user-a"))
    second = service.execute(DeleteAccountInput(owner_id="user-a"))
    assert sum(second.rows_deleted.values()) == 0
    assert second.files_removed == 0


def test_without_a_radar_key_the_other_tables_are_still_erased() -> None:
    client = FakeSupabase()
    _seed(client, "user-a", tag="a")
    _eraser(client, radar_key=None).erase_data("user-a")
    assert client.db["pet_profiles"] == []


def test_the_identity_is_kept_when_erasing_the_data_fails() -> None:
    class Failing:
        deleted: list[str] = []

        def erase_data(self, owner_id: str) -> ErasureReport:
            raise RuntimeError("database unavailable")

        def delete_identity(self, owner_id: str) -> None:
            self.deleted.append(owner_id)

    eraser = Failing()
    with pytest.raises(RuntimeError):
        DeleteAccountService(eraser).execute(DeleteAccountInput(owner_id="user-a"))
    assert eraser.deleted == []


def test_every_table_of_the_schema_is_either_erased_or_declared_not_personal() -> None:
    schema = Path("scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    tables = set(re.findall(r"create table if not exists public\.(\w+)", schema))
    covered = (
        {table for table, _ in OWNER_TABLES}
        | {table for table, _ in RADAR_PSEUDONYM_TABLES}
        | HANDLED_ELSEWHERE
        | set(NOT_PERSONAL_TABLES)
    )
    assert tables - covered == set(), (
        "New table(s) not covered by account deletion: add them to OWNER_TABLES "
        "or to NOT_PERSONAL_TABLES with the reason"
    )
    assert covered - tables == set(), "Account deletion lists a table the schema does not have"
