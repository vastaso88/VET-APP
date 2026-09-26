from pydantic import BaseModel

from packages.core.domain.feedback.models import (
    ChatResponseReportReason,
    ChatResponseReportStatus,
)


class CreateChatResponseReportRequest(BaseModel):
    conversation_id: str
    message_id: str
    reason: ChatResponseReportReason = "other"
    details: str | None = None


class ResolveChatResponseReportRequest(BaseModel):
    status: ChatResponseReportStatus
    resolution_note: str | None = None
    credited_bug_ref: str | None = None
