from packages.core.application.ports.email_sender import EmailMessage


def check_message(message: EmailMessage) -> str | None:
    """A short reason code when the message must not go out, else None."""
    if "@" not in message.to or any(c in message.to for c in "\r\n<>, ;"):
        return "invalid"
    if any(c in message.subject for c in "\r\n"):
        return "invalid"
    if message.category == "commercial" and not (
        message.unsubscribe_url and message.unsubscribe_url.startswith("https://")
    ):
        # A commercial message without a one-click unsubscribe is never sent.
        return "invalid"
    return None
