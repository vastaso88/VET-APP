from pydantic import BaseModel

from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.domain.feedback.models import ChatResponseReport, ChatResponseReportStatus


class ListChatResponseReportsInput(BaseModel):
    """No owner_id: this is the internal engineering-review listing (spec
    per marketing: a human confirms which reports match a shipped fix
    before any reward is credited), not an owner-scoped self-service view.
    """

    status: ChatResponseReportStatus | None = None


class ListChatResponseReportsOutput(BaseModel):
    reports: list[ChatResponseReport]


class ListChatResponseReportsService:
    def __init__(self, repository: ChatResponseReportRepository) -> None:
        self._repository = repository

    def execute(self, data: ListChatResponseReportsInput) -> ListChatResponseReportsOutput:
        reports = self._repository.list_all()
        if data.status is not None:
            reports = [report for report in reports if report.status == data.status]
        return ListChatResponseReportsOutput(reports=reports)
