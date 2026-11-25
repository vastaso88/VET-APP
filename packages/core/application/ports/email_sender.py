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
    # Images the HTML shows with `cid:<name>`: sent inside the message, never fetched from a site.
    inline_images: dict[str, bytes] = Field(default_factory=dict)
    category: EmailCategory = "service"
    # Required for "commercial": where the one-click unsubscribe points (https URL).
    unsubscribe_url: str | None = Field(default=None, max_length=2000)


# Why a message did not go, when it did not. The first three say whether it can have gone
# anyway: `not_sent` and `rejected` are certain (nothing was delivered); `uncertain` is not
# (a timeout or a dropped connection while the message was handed over: it may have been
# delivered, so it must NOT be sent again). `rejected` is ONLY the permanent refusal of the
# recipient (a 5xx on the address: no such mailbox): trying again is pointless, so it counts as
# tried. Everything else that did not go (no connection, sign-in, a 4xx on the recipient, the
# sender refused, a daily limit, the content) is `not_sent`: it is tried again at the next run.
NOT_SENT = "not_sent"
REJECTED = "rejected"
UNCERTAIN = "uncertain"


class SendResult(BaseModel):
    """[sent] is True only when the provider accepted the message. [reason] is a
    short code, never text from the provider: "disabled", "invalid", "reserved_recipient",
    "recipient_not_allowed", "not_sent", "rejected" or "uncertain"."""

    sent: bool
    reason: str | None = None


class EmailSender(Protocol):
    def send(self, message: EmailMessage) -> SendResult: ...
