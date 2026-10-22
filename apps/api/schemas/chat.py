from typing import Literal

from pydantic import BaseModel, Field

# The longest message the chat accepts (also PUT …/messages/{id}, and the
# app's composer: chat_composer.dart `maxMessageLength`). 2026-10-14: with no
# limit, 200 KB of text cost ~2 s of CPU in the safety gate.
MAX_USER_MESSAGE_CHARS = 8000


class SendChatMessageRequest(BaseModel):
    pet_id: str
    conversation_id: str | None = None
    user_message: str = Field(max_length=MAX_USER_MESSAGE_CHARS)
    attachment_id: str | None = None
    # Same value on a retry of the same message (see ChatMessage).
    client_message_id: str | None = Field(default=None, max_length=100)
    # Language of the reply ("it", "en", "de", "fr", "es"; "en-GB" is read as
    # "en"). Missing: the Accept-Language header, then "it".
    language: str | None = Field(default=None, max_length=20)
    response_locale: Literal["it", "en", "es", "de", "fr"] | None = None
