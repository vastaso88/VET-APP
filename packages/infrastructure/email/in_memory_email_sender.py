from packages.core.application.ports.email_sender import EmailMessage, EmailSender, SendResult
from packages.infrastructure.email.rules import check_message, check_recipient


class InMemoryEmailSender(EmailSender):
    """Tests and local development: keeps what would be sent, sends nothing. With
    [strict_recipients] it applies the recipient rules of the real sender (tests of
    those rules); by default it accepts example.com, which tests must use."""

    def __init__(
        self,
        enabled: bool = True,
        *,
        strict_recipients: bool = False,
        allowed_recipients: tuple[str, ...] | None = None,
    ) -> None:
        self.enabled = enabled
        self._strict = strict_recipients
        self._allowed = allowed_recipients
        self.sent: list[EmailMessage] = []

    def send(self, message: EmailMessage) -> SendResult:
        if not self.enabled:
            return SendResult(sent=False, reason="disabled")
        problem = check_message(message)
        if problem:
            return SendResult(sent=False, reason=problem)
        if self._strict:
            problem = check_recipient(message.to, self._allowed)
            if problem:
                return SendResult(sent=False, reason=problem)
        self.sent.append(message)
        return SendResult(sent=True)


class DisabledEmailSender(EmailSender):
    """What production uses while EMAIL_SENDING_ENABLED is false."""

    def send(self, message: EmailMessage) -> SendResult:
        return SendResult(sent=False, reason="disabled")
