from pydantic import BaseModel

from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.domain.feedback.models import ChatResponseReport, ChatResponseReportReason
from packages.shared.errors.base import ValidationError


class ReportChatResponseInput(BaseModel):
    reporter_owner_id: str
    conversation_id: str
    message_id: str
    reason: ChatResponseReportReason = "other"
    details: str | None = None


class ReportChatResponseOutput(BaseModel):
    report: ChatResponseReport


class ReportChatResponseService:
    def __init__(
        self,
        conversation_repository: ConversationRepository,
        report_repository: ChatResponseReportRepository,
    ) -> None:
        self._conversation_repository = conversation_repository
        self._report_repository = report_repository

    def execute(self, data: ReportChatResponseInput) -> ReportChatResponseOutput:
        conversation = self._conversation_repository.get(data.conversation_id)
        if conversation is None:
            raise ValidationError("conversation not found")
        if conversation.owner_id != data.reporter_owner_id:
            raise ValidationError("conversation does not belong to this owner")

        message = next(
            (m for m in conversation.messages if m.id == data.message_id), None
        )
        if message is None:
            raise ValidationError("message not found in this conversation")
        if message.role != "assistant":
            # Reporting the app's own reply is the point; the owner's own
            # message has nothing to report.
            raise ValidationError("only an assistant reply can be reported")

        report = self._report_repository.save(
            ChatResponseReport(
                conversation_id=data.conversation_id,
                message_id=data.message_id,
                pet_id=conversation.pet_id,
                reporter_owner_id=data.reporter_owner_id,
                reason=data.reason,
                details=data.details,
                reported_answer=message.content,
            )
        )
        return ReportChatResponseOutput(report=report)
