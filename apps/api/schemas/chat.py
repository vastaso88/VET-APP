from pydantic import BaseModel


class SendChatMessageRequest(BaseModel):
    pet_id: str
    conversation_id: str | None = None
    user_message: str
    attachment_id: str | None = None
