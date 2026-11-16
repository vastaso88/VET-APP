from datetime import datetime
from typing import Protocol

from packages.core.domain.account_deletion.log import DeletionLogEntry


class DeletionLogRepository(Protocol):
    """The register in the database (written only by the backend)."""

    def begin(self, entry: DeletionLogEntry) -> None:
        """Stores the entry, incomplete. A second attempt for the same account
        does not duplicate it (unique fingerprint)."""
        ...

    def complete(self, owner_hash: str, at: datetime) -> None: ...

    def list_all(self) -> list[DeletionLogEntry]: ...

    def add_missing(self, entries: list[DeletionLogEntry]) -> int:
        """Adds the entries not already there (reloading from the copy after a
        database restore). Returns how many were added."""
        ...

    def delete_older_than(self, cutoff: datetime) -> int: ...


class DeletionLogCopy(Protocol):
    """The same register kept OUTSIDE the database, in a private bucket that
    only the service role reaches: a database restore brings the table back in
    time but not this copy."""

    def save(self, entry: DeletionLogEntry) -> None: ...

    def list_all(self) -> list[DeletionLogEntry]: ...

    def delete_older_than(self, cutoff: datetime) -> int: ...
