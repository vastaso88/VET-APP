from pydantic import BaseModel, Field

from packages.core.domain.feedback.models import (
    ChatResponseReportReason,
    ChatResponseReportStatus,
)


class CreateChatResponseReportRequest(BaseModel):
    conversation_id: str = Field(max_length=128)
    message_id: str = Field(max_length=128)
    reason: ChatResponseReportReason = "other"
    details: str | None = Field(default=None, max_length=1000)


class ResolveChatResponseReportRequest(BaseModel):
    status: ChatResponseReportStatus
    resolution_note: str | None = Field(default=None, max_length=2000)
    credited_bug_ref: str | None = Field(default=None, max_length=200)
