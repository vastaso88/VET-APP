from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage as MimeMessage
from email.utils import formatdate, make_msgid

from packages.core.application.ports.email_sender import EmailMessage, EmailSender, SendResult
from packages.infrastructure.email.rules import check_message

logger = logging.getLogger(__name__)


class SmtpEmailSender(EmailSender):
    """Any SMTP provider, standard library only. Credentials come from the
    environment. Never logs an address, a subject, a text or the provider's
    own error text (which can echo the address)."""

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
    ) -> None:
        self._host = host
        self._port = port
        self._username = username
        self._password = password
        self._sender = sender
        self._use_ssl = use_ssl
        self._timeout = timeout

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
        return mime

    def send(self, message: EmailMessage) -> SendResult:
        problem = check_message(message)
        if problem:
            return SendResult(sent=False, reason=problem)
        mime = self.build(message)
        try:
            context = ssl.create_default_context()
            if self._use_ssl:
                with smtplib.SMTP_SSL(
                    self._host, self._port, timeout=self._timeout, context=context
                ) as server:
                    self._deliver(server, mime)
            else:
                with smtplib.SMTP(self._host, self._port, timeout=self._timeout) as server:
                    server.starttls(context=context)
                    self._deliver(server, mime)
        except Exception:  # noqa: BLE001 - the text of the error can hold the address
            logger.warning("an e-mail could not be sent", exc_info=False)
            return SendResult(sent=False, reason="failed")
        return SendResult(sent=True)

    def _deliver(self, server: smtplib.SMTP, mime: MimeMessage) -> None:
        if self._username:
            server.login(self._username, self._password)
        server.send_message(mime)
