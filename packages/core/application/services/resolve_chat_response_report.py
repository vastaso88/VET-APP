from pydantic import BaseModel

from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.feedback.models import ChatResponseReport, ChatResponseReportStatus
from packages.shared.errors.base import ValidationError

_TERMINAL_STATUSES: tuple[ChatResponseReportStatus, ...] = ("resolved", "wont_fix")


class ResolveChatResponseReportInput(BaseModel):
    report_id: str
    status: ChatResponseReportStatus
    resolution_note: str | None = None
    credited_bug_ref: str | None = None


class ResolveChatResponseReportOutput(BaseModel):
    report: ChatResponseReport


class ResolveChatResponseReportService:
    """Whoever ships a fix marks which report(s) it corresponds to (spec
    per marketing: human review at fix time, not automatic) — this is that
    marking step. `credited_bug_ref` stays null until this is called with
    it set, which is also the eventual hook for a future billing flow to
    find reports owed a reward.
    """

    def __init__(self, repository: ChatResponseReportRepository) -> None:
        self._repository = repository

    def execute(self, data: ResolveChatResponseReportInput) -> ResolveChatResponseReportOutput:
        report = self._repository.get(data.report_id)
        if report is None:
            raise ValidationError("report not found")

        is_terminal = data.status in _TERMINAL_STATUSES
        updated = report.model_copy(
            update={
                "status": data.status,
                "resolved_at": utc_now() if is_terminal else report.resolved_at,
                "resolution_note": data.resolution_note,
                "credited_bug_ref": data.credited_bug_ref,
            }
        )
        return ResolveChatResponseReportOutput(report=self._repository.save(updated))
