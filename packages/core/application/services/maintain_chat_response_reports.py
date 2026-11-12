from datetime import datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.domain.feedback.models import ChatResponseReport
from packages.core.domain.feedback.pseudonym import reporter_ref

# docs/compliance/07_contributi_utenti.md: a report is kept for 12 months
# after its outcome, then only counted.
DEFAULT_RETENTION = timedelta(days=365)
_TERMINAL_STATUSES = ("resolved", "wont_fix")


class ChatResponseReportMaintenanceOutput(BaseModel):
    purged: int
    legacy_pseudonymized: int


class ChatResponseReportMaintenanceService:
    """Retention and erasure for chat response reports.

    `run` is idempotent and safe to call from a scheduler: it converts any
    legacy row still carrying a clear owner id to the pseudonym, then
    deletes every report whose outcome is older than the retention period,
    leaving behind only an anonymous monthly counter.
    """

    def __init__(
        self,
        repository: ChatResponseReportRepository,
        pseudonym_salt: str,
        *,
        retention: timedelta = DEFAULT_RETENTION,
    ) -> None:
        self._repository = repository
        self._pseudonym_salt = pseudonym_salt
        self._retention = retention

    def run(self, now: datetime) -> ChatResponseReportMaintenanceOutput:
        purged = 0
        pseudonymized = 0
        for report in self._repository.list_all():
            if self._is_expired(report, now):
                self._repository.add_to_counter(
                    report.created_at.strftime("%Y-%m"), report.reason, report.status, 1
                )
                self._repository.delete(report.id)
                purged += 1
            elif report.reporter_owner_id is not None:
                self._repository.save(
                    report.model_copy(
                        update={
                            "reporter_ref": report.reporter_ref
                            or reporter_ref(report.reporter_owner_id, self._pseudonym_salt),
                            "reporter_owner_id": None,
                        }
                    )
                )
                pseudonymized += 1
        return ChatResponseReportMaintenanceOutput(
            purged=purged, legacy_pseudonymized=pseudonymized
        )

    def erase_for_owner(self, owner_id: str) -> int:
        """Deletes every report made by this owner (erasure request). No
        counter is kept: the person asked for their contribution to go."""
        ref = reporter_ref(owner_id, self._pseudonym_salt)
        mine = [
            report
            for report in self._repository.list_all()
            if report.reporter_ref == ref or report.reporter_owner_id == owner_id
        ]
        for report in mine:
            self._repository.delete(report.id)
        return len(mine)

    def _is_expired(self, report: ChatResponseReport, now: datetime) -> bool:
        return (
            report.status in _TERMINAL_STATUSES
            and report.resolved_at is not None
            and report.resolved_at + self._retention <= now
        )
