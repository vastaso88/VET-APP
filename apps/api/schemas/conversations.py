from pydantic import BaseModel, Field

from apps.api.schemas.chat import MAX_USER_MESSAGE_CHARS


class RenameConversationRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class EditChatMessageRequest(BaseModel):
    # Empty is allowed when the original message has an attachment.
    user_message: str = Field(default="", max_length=MAX_USER_MESSAGE_CHARS)
    client_message_id: str | None = Field(default=None, max_length=100)
    # Same meaning as SendChatMessageRequest.language.
    language: str | None = Field(default=None, max_length=20)
