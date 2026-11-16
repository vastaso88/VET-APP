"""One door for every e-mail the app sends (deletion, pause, the 120-day notices).

Rules that hold for every implementation:
- Nothing about a message is ever logged or put in an error: no address, no
  subject, no text, no counts.
- [category] is "service" (about the person's own account or request, needs no
  consent) or "commercial" (needs a consent in force; carries a one-click
  unsubscribe). The caller decides the category; the sender only honours it.
- Sending is OFF unless EMAIL_SENDING_ENABLED is true (owner rule): off, nothing
  leaves and the result says so.
"""

from typing import Literal, Protocol

from pydantic import BaseModel, Field

EmailCategory = Literal["service", "commercial"]


class EmailMessage(BaseModel):
    to: str = Field(min_length=3, max_length=254)
    subject: str = Field(min_length=1, max_length=200)
    text: str = Field(min_length=1, max_length=20000)
    html: str | None = Field(default=None, max_length=100000)
    category: EmailCategory = "service"
    # Required for "commercial": where the one-click unsubscribe points (https URL).
    unsubscribe_url: str | None = Field(default=None, max_length=2000)


class SendResult(BaseModel):
    """[sent] is True only when the provider accepted the message. [reason] is a
    short code, never text from the provider: "disabled", "invalid", "failed"."""

    sent: bool
    reason: str | None = None


class EmailSender(Protocol):
    def send(self, message: EmailMessage) -> SendResult: ...
