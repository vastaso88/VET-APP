from pydantic import BaseModel, Field


class SendChatMessageRequest(BaseModel):
    pet_id: str
    conversation_id: str | None = None
    user_message: str
    attachment_id: str | None = None
    # Same value on a retry of the same message (see ChatMessage).
    client_message_id: str | None = Field(default=None, max_length=100)
