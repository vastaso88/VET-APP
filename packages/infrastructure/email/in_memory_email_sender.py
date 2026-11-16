from packages.core.application.ports.email_sender import EmailMessage, EmailSender, SendResult
from packages.infrastructure.email.rules import check_message


class InMemoryEmailSender(EmailSender):
    """Tests and local development: keeps what would be sent, sends nothing."""

    def __init__(self, enabled: bool = True) -> None:
        self.enabled = enabled
        self.sent: list[EmailMessage] = []

    def send(self, message: EmailMessage) -> SendResult:
        if not self.enabled:
            return SendResult(sent=False, reason="disabled")
        problem = check_message(message)
        if problem:
            return SendResult(sent=False, reason=problem)
        self.sent.append(message)
        return SendResult(sent=True)


class DisabledEmailSender(EmailSender):
    """What production uses while EMAIL_SENDING_ENABLED is false."""

    def send(self, message: EmailMessage) -> SendResult:
        return SendResult(sent=False, reason="disabled")
