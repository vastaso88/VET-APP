from datetime import datetime
from typing import Protocol

from packages.core.domain.events.submission import EventSubmission


class EventSubmissionRepository(Protocol):
    def add(self, submission: EventSubmission) -> None: ...

    def count_since(self, owner_id: str, since: datetime) -> int:
        """How many suggestions this owner sent since `since` (any status)."""
        ...

    def list_pending(self) -> list[EventSubmission]: ...

    def get(self, submission_id: str) -> EventSubmission | None: ...

    def save(self, submission: EventSubmission) -> None:
        """Stores the new status of a reviewed submission."""
        ...
