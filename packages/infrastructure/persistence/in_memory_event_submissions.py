from datetime import datetime

from packages.core.application.ports.event_submission_repository import (
    EventSubmissionRepository,
)
from packages.core.domain.events.submission import EventSubmission


class InMemoryEventSubmissionRepository(EventSubmissionRepository):
    def __init__(self) -> None:
        self._items: dict[str, EventSubmission] = {}

    def add(self, submission: EventSubmission) -> None:
        self._items[submission.id] = submission

    def count_since(self, owner_id: str, since: datetime) -> int:
        return sum(
            1 for s in self._items.values() if s.submitted_by == owner_id and s.created_at >= since
        )

    def list_pending(self) -> list[EventSubmission]:
        return sorted(
            (s for s in self._items.values() if s.status == "pending"),
            key=lambda s: s.created_at,
        )

    def get(self, submission_id: str) -> EventSubmission | None:
        return self._items.get(submission_id)

    def save(self, submission: EventSubmission) -> None:
        self._items[submission.id] = submission
