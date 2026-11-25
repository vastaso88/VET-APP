from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage as MimeMessage
from email.utils import formatdate, make_msgid

from packages.core.application.ports.email_sender import (
    NOT_SENT,
    REJECTED,
    UNCERTAIN,
    EmailMessage,
    EmailSender,
    SendResult,
)
from packages.infrastructure.email.rules import check_message, check_recipient

logger = logging.getLogger(__name__)

# The server answered the message itself with a refusal that is NOT about the recipient: the
# sender, the content, a limit, a feature. None of these says that the person cannot be
# written to, so the message is not registered as tried and goes again at the next run.
_TEMPORARY_REFUSALS = (
    smtplib.SMTPSenderRefused,
    smtplib.SMTPDataError,
    smtplib.SMTPNotSupportedError,
)


class SmtpEmailSender(EmailSender):
    """Any SMTP provider, standard library only, certificate always verified. Credentials come
    from the environment. Never logs an address, a subject, a text or the provider's own error
    text (which can echo the address).

    A failure says whether the message can have gone: before the message is handed over
    (connect, TLS, sign-in) or refused by the server, it certainly did not (`not_sent`,
    `rejected`); a timeout or a dropped connection while it is being handed over may have
    delivered it (`uncertain`), and the caller must not send it again."""

    def __init__(
        self,
        host: str,
        port: int,
        username: str,
        password: str,
        sender: str,
        *,
        use_ssl: bool = False,
        timeout: float = 15.0,
        allowed_recipients: tuple[str, ...] | None = None,
    ) -> None:
        self._host = host
        self._port = port
        self._username = username
        self._password = password
        self._sender = sender
        self._use_ssl = use_ssl
        self._timeout = timeout
        # None = no allow-list; a tuple (even empty) = only those addresses.
        self._allowed_recipients = allowed_recipients

    def build(self, message: EmailMessage) -> MimeMessage:
        mime = MimeMessage()
        mime["From"] = self._sender
        mime["To"] = message.to
        mime["Subject"] = message.subject
        mime["Date"] = formatdate(localtime=False)
        mime["Message-ID"] = make_msgid()
        if message.category == "commercial" and message.unsubscribe_url:
            mime["List-Unsubscribe"] = f"<{message.unsubscribe_url}>"
            mime["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
        mime.set_content(message.text)
        if message.html:
            mime.add_alternative(message.html, subtype="html")
            html_part = mime.get_body(preferencelist=("html",))
            if html_part is not None:
                for cid, data in message.inline_images.items():
                    if data:
                        html_part.add_related(data, "image", "png", cid=f"<{cid}>")
        return mime

    def send(self, message: EmailMessage) -> SendResult:
        problem = check_message(message)
        if problem:
            return SendResult(sent=False, reason=problem)
        # Before any connection, with no way around it: reserved domains (the collaudo twin's
        # accounts are all there) and, when there is an allow-list, anyone not on it.
        problem = check_recipient(message.to, self._allowed_recipients)
        if problem:
            return SendResult(sent=False, reason=problem)
        mime = self.build(message)
        context = ssl.create_default_context()  # certificate and host name are verified
        try:
            if self._use_ssl:
                server: smtplib.SMTP = smtplib.SMTP_SSL(
                    self._host, self._port, timeout=self._timeout, context=context
                )
            else:
                server = smtplib.SMTP(self._host, self._port, timeout=self._timeout)
        except Exception:  # noqa: BLE001 - the text of the error can hold the address
            return self._failed(NOT_SENT)
        try:
            try:
                if not self._use_ssl:
                    server.starttls(context=context)
                if self._username:
                    server.login(self._username, self._password)
            except Exception:  # noqa: BLE001 - nothing was handed over yet
                return self._failed(NOT_SENT)
            try:
                server.send_message(mime)
            except smtplib.SMTPRecipientsRefused as refused:
                # Permanent only when EVERY recipient answer is a 5xx (a mailbox that does not
                # exist): then trying again is pointless. A 4xx on the recipient is temporary.
                codes = [code for code, _ in refused.recipients.values()]
                permanent = bool(codes) and all(code >= 500 for code in codes)
                return self._failed(REJECTED if permanent else NOT_SENT)
            except _TEMPORARY_REFUSALS:
                return self._failed(NOT_SENT)
            except Exception:  # noqa: BLE001 - a dropped connection or a timeout may have delivered
                return self._failed(UNCERTAIN)
        finally:
            try:
                server.quit()
            except Exception:  # noqa: BLE001 - closing is best effort
                logger.debug("smtp connection closed without a goodbye", exc_info=False)
        return SendResult(sent=True)

    @staticmethod
    def _failed(reason: str) -> SendResult:
        logger.warning("an e-mail could not be sent (%s)", reason, exc_info=False)
        return SendResult(sent=False, reason=reason)
