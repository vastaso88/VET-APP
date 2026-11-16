from datetime import datetime

from packages.core.application.ports.deletion_log import DeletionLogCopy, DeletionLogRepository
from packages.core.domain.account_deletion.log import DeletionLogEntry


class InMemoryDeletionLogRepository(DeletionLogRepository):
    """Local development and tests."""

    def __init__(self) -> None:
        self._items: dict[str, DeletionLogEntry] = {}

    def begin(self, entry: DeletionLogEntry) -> None:
        self._items.setdefault(entry.owner_hash, entry)

    def complete(self, owner_hash: str, at: datetime) -> None:
        current = self._items.get(owner_hash)
        if current is not None:
            self._items[owner_hash] = current.model_copy(update={"completed_at": at})

    def list_all(self) -> list[DeletionLogEntry]:
        return list(self._items.values())

    def add_missing(self, entries: list[DeletionLogEntry]) -> int:
        added = 0
        for entry in entries:
            if entry.owner_hash not in self._items:
                self._items[entry.owner_hash] = entry
                added += 1
        return added

    def delete_older_than(self, cutoff: datetime) -> int:
        old = [key for key, item in self._items.items() if item.deleted_at < cutoff]
        for key in old:
            del self._items[key]
        return len(old)

    def lose_everything(self) -> None:
        """What a database restore does to the table (tests)."""
        self._items.clear()


class InMemoryDeletionLogCopy(DeletionLogCopy):
    def __init__(self) -> None:
        self._items: dict[str, DeletionLogEntry] = {}

    def save(self, entry: DeletionLogEntry) -> None:
        self._items.setdefault(entry.owner_hash, entry)

    def list_all(self) -> list[DeletionLogEntry]:
        return list(self._items.values())

    def delete_older_than(self, cutoff: datetime) -> int:
        old = [key for key, item in self._items.items() if item.deleted_at < cutoff]
        for key in old:
            del self._items[key]
        return len(old)
