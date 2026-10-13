from typing import Literal

from pydantic import BaseModel, Field


class SendChatMessageRequest(BaseModel):
    pet_id: str
    conversation_id: str | None = None
    user_message: str
    attachment_id: str | None = None
    # Same value on a retry of the same message (see ChatMessage).
    client_message_id: str | None = Field(default=None, max_length=100)
    # Language of the reply ("it", "en", "de", "fr", "es"; "en-GB" is read as
    # "en"). Missing: the Accept-Language header, then "it".
    language: str | None = Field(default=None, max_length=20)
    response_locale: Literal["it", "en", "es"] | None = None
