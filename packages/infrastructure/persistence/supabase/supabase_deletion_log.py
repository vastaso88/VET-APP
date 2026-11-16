from __future__ import annotations

import json
from datetime import UTC, date, datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.application.ports.deletion_log import DeletionLogCopy, DeletionLogRepository
from packages.core.domain.account_deletion.log import DeletionLogEntry

if TYPE_CHECKING:
    from supabase import Client

TABLE = "account_deletion_log"
_PAGE = 100


def _to_entry(row: dict[str, Any]) -> DeletionLogEntry:
    completed = row.get("completed_at")
    return DeletionLogEntry(
        owner_hash=str(row["owner_hash"]),
        deleted_at=datetime.fromisoformat(str(row["deleted_at"])),
        reason=str(row["reason"]),
        completed_at=datetime.fromisoformat(str(completed)) if completed else None,
    )


def _row(entry: DeletionLogEntry) -> dict[str, Any]:
    return {
        "owner_hash": entry.owner_hash,
        "deleted_at": entry.deleted_at.isoformat(),
        "reason": entry.reason,
        "completed_at": entry.completed_at.isoformat() if entry.completed_at else None,
    }


class SupabaseDeletionLogRepository(DeletionLogRepository):
    """The register table. Only the service role reaches it (row-level security
    on, no policy). Nothing here is ever logged."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def begin(self, entry: DeletionLogEntry) -> None:
        self._client.table(TABLE).upsert(
            _row(entry), on_conflict="owner_hash", ignore_duplicates=True
        ).execute()

    def complete(self, owner_hash: str, at: datetime) -> None:
        self._client.table(TABLE).update({"completed_at": at.isoformat()}).eq(
            "owner_hash", owner_hash
        ).execute()

    def list_all(self) -> list[DeletionLogEntry]:
        rows = cast(
            list[dict[str, Any]], self._client.table(TABLE).select("*").execute().data or []
        )
        return [_to_entry(row) for row in rows]

    def add_missing(self, entries: list[DeletionLogEntry]) -> int:
        if not entries:
            return 0
        response = (
            self._client.table(TABLE)
            .upsert(
                [_row(entry) for entry in entries],
                on_conflict="owner_hash",
                ignore_duplicates=True,
            )
            .execute()
        )
        # Ignored duplicates return no row: what comes back is what was added.
        return len(response.data or [])

    def delete_older_than(self, cutoff: datetime) -> int:
        response = self._client.table(TABLE).delete().lt("deleted_at", cutoff.isoformat()).execute()
        return len(response.data or [])


class SupabaseStorageDeletionLogCopy(DeletionLogCopy):
    """One small JSON object per entry in a private bucket, named
    `<day>_<fingerprint>.json`: no race between two deletions, and the day is in
    the name, so pruning does not have to read every object. The bucket has no
    storage policy: only the service role reaches it."""

    def __init__(self, client: Client, bucket: str) -> None:
        self._client = client
        self._bucket = bucket

    @staticmethod
    def _name(entry: DeletionLogEntry) -> str:
        return f"{entry.deleted_at.astimezone(UTC).date().isoformat()}_{entry.owner_hash}.json"

    def save(self, entry: DeletionLogEntry) -> None:
        body = json.dumps(
            {
                "owner_hash": entry.owner_hash,
                "deleted_at": entry.deleted_at.isoformat(),
                "reason": entry.reason,
            }
        ).encode()
        self._client.storage.from_(self._bucket).upload(
            self._name(entry),
            body,
            {"content-type": "application/json", "upsert": "true"},
        )

    def _names(self) -> list[str]:
        names: list[str] = []
        offset = 0
        while True:
            page = cast(
                list[dict[str, Any]],
                self._client.storage.from_(self._bucket).list(
                    "", {"limit": _PAGE, "offset": offset}
                ),
            )
            names.extend(
                str(item["name"]) for item in page or [] if str(item["name"]).endswith(".json")
            )
            if len(page or []) < _PAGE:
                return names
            offset += _PAGE

    def list_all(self) -> list[DeletionLogEntry]:
        entries: list[DeletionLogEntry] = []
        for name in self._names():
            raw = self._client.storage.from_(self._bucket).download(name)
            data = json.loads(raw)
            entries.append(
                DeletionLogEntry(
                    owner_hash=str(data["owner_hash"]),
                    deleted_at=datetime.fromisoformat(str(data["deleted_at"])),
                    reason=str(data["reason"]),
                )
            )
        return entries

    def delete_older_than(self, cutoff: datetime) -> int:
        old = []
        cutoff_day = cutoff.astimezone(UTC).date()
        for name in self._names():
            try:
                day = date.fromisoformat(name.split("_", 1)[0])
            except ValueError:
                continue
            if day < cutoff_day:
                old.append(name)
        if old:
            self._client.storage.from_(self._bucket).remove(old)
        return len(old)
