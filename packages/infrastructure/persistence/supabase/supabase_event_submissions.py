from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.event_submission_repository import (
    EventSubmissionRepository,
)
from packages.core.domain.events.regions import DEFAULT_COUNTRY
from packages.core.domain.events.submission import EventSubmission

if TYPE_CHECKING:
    from supabase import Client


class SupabaseEventSubmissionRepository(EventSubmissionRepository):
    """`event_submissions`: written and read only by the backend and by the
    moderation script (service role); the app never queries it."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "event_submissions"

    def add(self, submission: EventSubmission) -> None:
        self._client.table(self._table).insert(_row(submission)).execute()

    def count_since(self, owner_id: str, since: datetime) -> int:
        response = (
            self._client.table(self._table)
            .select("id", count="exact")  # type: ignore[arg-type]
            .eq("submitted_by", owner_id)
            .gte("created_at", since.isoformat())
            .execute()
        )
        return int(response.count or 0)

    def list_pending(self) -> list[EventSubmission]:
        response = (
            self._client.table(self._table)
            .select("*")
            .eq("status", "pending")
            .order("created_at")
            .execute()
        )
        return [EventSubmission.model_validate(row) for row in response.data or []]

    def get(self, submission_id: str) -> EventSubmission | None:
        response = (
            self._client.table(self._table).select("*").eq("id", submission_id).limit(1).execute()
        )
        if not response.data:
            return None
        return EventSubmission.model_validate(response.data[0])

    def save(self, submission: EventSubmission) -> None:
        self._client.table(self._table).upsert(_row(submission)).execute()


def _row(submission: EventSubmission) -> dict[str, Any]:
    """The country is written only when it is not the column's default, so the Italian
    suggestions keep being stored before scripts/setup/events_abroad.sql has run."""
    row = submission.model_dump(mode="json")
    if submission.country == DEFAULT_COUNTRY:
        del row["country"]
    return row
