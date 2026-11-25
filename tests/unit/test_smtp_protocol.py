"""The SMTP sender speaks the protocol correctly and says, when it fails, whether the message can
have gone. Tested against a fake connection that records the calls: a real local server would
need a self-signed certificate, and the certificate check is never weakened to allow one."""

from __future__ import annotations

import logging
import smtplib
import socket
import ssl
from email.message import EmailMessage as MimeMessage
from typing import Any

import pytest

from packages.core.application.ports.email_sender import EmailMessage
from packages.infrastructure.email.smtp_email_sender import SmtpEmailSender

ADDRESS = "person@sandbox-mail.org"  # not reserved: the guard lets it reach the (fake) connection
MESSAGE = EmailMessage(to=ADDRESS, subject="Oggetto di prova", text="Testo di prova")


class FakeSMTP:
    """Records what the sender does. Behaviour is set on the class before each test."""

    log: list[str] = []
    contexts: list[ssl.SSLContext | None] = []
    sent: list[MimeMessage] = []
    fail_connect: BaseException | None = None
    fail_starttls: BaseException | None = None
    fail_login: BaseException | None = None
    fail_send: BaseException | None = None
    fail_quit: BaseException | None = None

    def __init__(
        self,
        host: str,
        port: int = 0,
        timeout: float | None = None,
        context: ssl.SSLContext | None = None,
        **_: Any,
    ) -> None:
        type(self).log.append(f"connect {host}:{port} timeout={timeout}")
        type(self).contexts.append(context)
        if type(self).fail_connect:
            raise type(self).fail_connect  # type: ignore[misc]

    def starttls(self, context: ssl.SSLContext | None = None) -> None:
        type(self).log.append("starttls")
        type(self).contexts.append(context)
        if type(self).fail_starttls:
            raise type(self).fail_starttls  # type: ignore[misc]

    def login(self, user: str, password: str) -> None:
        type(self).log.append(f"login {user}")
        if type(self).fail_login:
            raise type(self).fail_login  # type: ignore[misc]

    def send_message(self, message: MimeMessage) -> None:
        type(self).log.append("send_message")
        if type(self).fail_send:
            raise type(self).fail_send  # type: ignore[misc]
        type(self).sent.append(message)

    def quit(self) -> None:
        type(self).log.append("quit")
        if type(self).fail_quit:
            raise type(self).fail_quit  # type: ignore[misc]


@pytest.fixture
def fake(monkeypatch: pytest.MonkeyPatch) -> type[FakeSMTP]:
    FakeSMTP.log = []
    FakeSMTP.contexts = []
    FakeSMTP.sent = []
    for name in ("fail_connect", "fail_starttls", "fail_login", "fail_send", "fail_quit"):
        setattr(FakeSMTP, name, None)
    monkeypatch.setattr(smtplib, "SMTP", FakeSMTP)
    monkeypatch.setattr(smtplib, "SMTP_SSL", FakeSMTP)
    return FakeSMTP


def _sender(**kwargs: Any) -> SmtpEmailSender:
    return SmtpEmailSender(
        "smtp.sandbox-mail.org", 587, "user", "secret", "Quokka <q@sandbox-mail.org>", **kwargs
    )


def test_the_conversation_is_connect_starttls_login_send_quit(fake: type[FakeSMTP]) -> None:
    result = _sender().send(MESSAGE)

    assert (result.sent, result.reason) == (True, None)
    assert fake.log == [
        "connect smtp.sandbox-mail.org:587 timeout=15.0",
        "starttls",
        "login user",
        "send_message",
        "quit",
    ]


def test_the_certificate_and_the_host_name_are_always_verified(fake: type[FakeSMTP]) -> None:
    _sender().send(MESSAGE)
    _sender(use_ssl=True).send(MESSAGE)

    contexts = [context for context in fake.contexts if context is not None]
    assert len(contexts) == 2  # the STARTTLS one and the SSL one
    for context in contexts:
        assert context.verify_mode == ssl.CERT_REQUIRED
        assert context.check_hostname is True


def test_with_ssl_there_is_no_starttls(fake: type[FakeSMTP]) -> None:
    _sender(use_ssl=True).send(MESSAGE)
    assert "starttls" not in fake.log and fake.log[-2:] == ["send_message", "quit"]


def test_without_a_username_it_does_not_log_in(fake: type[FakeSMTP]) -> None:
    sender = SmtpEmailSender("smtp.sandbox-mail.org", 25, "", "", "Quokka <q@sandbox-mail.org>")
    sender.send(MESSAGE)
    assert not any(line.startswith("login") for line in fake.log)


def test_the_message_has_the_headers_of_a_plain_service_mail(fake: type[FakeSMTP]) -> None:
    _sender().send(MESSAGE)

    (mime,) = fake.sent
    assert mime["From"] == "Quokka <q@sandbox-mail.org>"
    assert mime["To"] == ADDRESS
    assert mime["Subject"] == "Oggetto di prova"
    assert mime["Date"] and mime["Message-ID"]
    assert mime["Bcc"] is None and mime["Cc"] is None
    assert mime["List-Unsubscribe"] is None  # service message: no unsubscribe header
    assert mime.get_content().strip() == "Testo di prova"
    assert mime.get_content_type() == "text/plain"


@pytest.mark.parametrize(
    ("where", "error"),
    [
        ("fail_connect", ConnectionRefusedError()),
        ("fail_connect", socket.gaierror()),
        ("fail_connect", TimeoutError()),
        ("fail_starttls", ssl.SSLCertVerificationError()),
        ("fail_starttls", smtplib.SMTPNotSupportedError()),
        ("fail_login", smtplib.SMTPAuthenticationError(535, b"no")),
    ],
)
def test_a_failure_before_the_message_is_handed_over_is_certainly_not_sent(
    fake: type[FakeSMTP], where: str, error: BaseException
) -> None:
    setattr(fake, where, error)

    result = _sender().send(MESSAGE)

    assert (result.sent, result.reason) == (False, "not_sent")
    assert "send_message" not in fake.log


def _recipients_refused(*codes: int) -> smtplib.SMTPRecipientsRefused:
    return smtplib.SMTPRecipientsRefused(
        {f"person{index}@sandbox-mail.org": (code, b"no") for index, code in enumerate(codes)}
    )


@pytest.mark.parametrize("codes", [(550,), (551,), (553,), (550, 554)])
def test_a_permanent_refusal_of_the_recipient_is_rejected_and_counts_as_tried(
    fake: type[FakeSMTP], codes: tuple[int, ...]
) -> None:
    """A 5xx on the address (no such mailbox): trying again is pointless."""
    fake.fail_send = _recipients_refused(*codes)
    result = _sender().send(MESSAGE)
    assert (result.sent, result.reason) == (False, "rejected")


@pytest.mark.parametrize("codes", [(450,), (451,), (452,), (421,), (550, 450)])
def test_a_temporary_refusal_of_the_recipient_is_not_registered_and_goes_again(
    fake: type[FakeSMTP], codes: tuple[int, ...]
) -> None:
    """A 4xx on the address is temporary; so is a mixed answer (not ALL permanent)."""
    fake.fail_send = _recipients_refused(*codes)
    result = _sender().send(MESSAGE)
    assert (result.sent, result.reason) == (False, "not_sent")


@pytest.mark.parametrize(
    "error",
    [
        smtplib.SMTPSenderRefused(553, b"sender not allowed", "q@sandbox-mail.org"),
        smtplib.SMTPSenderRefused(452, b"daily limit", "q@sandbox-mail.org"),
        smtplib.SMTPDataError(554, b"content refused"),
        smtplib.SMTPDataError(452, b"too many messages"),
        smtplib.SMTPNotSupportedError("no such feature"),
    ],
)
def test_anything_else_the_server_refuses_is_not_registered_and_goes_again(
    fake: type[FakeSMTP], error: BaseException
) -> None:
    """The sender, a daily limit, the content, a missing feature: not about the person, so it is
    tried again at every run."""
    fake.fail_send = error
    result = _sender().send(MESSAGE)
    assert (result.sent, result.reason) == (False, "not_sent")


def test_a_recipients_refused_with_no_answers_is_not_taken_for_permanent(
    fake: type[FakeSMTP],
) -> None:
    fake.fail_send = smtplib.SMTPRecipientsRefused({})
    assert _sender().send(MESSAGE).reason == "not_sent"


@pytest.mark.parametrize(
    "error", [smtplib.SMTPServerDisconnected(), TimeoutError(), ConnectionResetError(), OSError()]
)
def test_a_break_while_the_message_is_handed_over_is_uncertain(
    fake: type[FakeSMTP], error: BaseException
) -> None:
    """The server may have accepted it before the connection broke: it must not be resent."""
    fake.fail_send = error
    result = _sender().send(MESSAGE)
    assert (result.sent, result.reason) == (False, "uncertain")


def test_the_connection_is_closed_whatever_happened(fake: type[FakeSMTP]) -> None:
    fake.fail_send = smtplib.SMTPDataError(554, b"no")
    _sender().send(MESSAGE)
    assert fake.log[-1] == "quit"

    fake.log.clear()
    fake.fail_send = None
    fake.fail_login = smtplib.SMTPAuthenticationError(535, b"no")
    _sender().send(MESSAGE)
    assert fake.log[-1] == "quit"


def test_a_goodbye_that_fails_does_not_undo_a_delivery(fake: type[FakeSMTP]) -> None:
    fake.fail_quit = smtplib.SMTPServerDisconnected()
    result = _sender().send(MESSAGE)
    assert result.sent is True and len(fake.sent) == 1


def test_a_failure_logs_no_address_no_subject_no_text(
    fake: type[FakeSMTP], caplog: pytest.LogCaptureFixture
) -> None:
    fake.fail_send = smtplib.SMTPRecipientsRefused({ADDRESS: (550, ADDRESS.encode())})
    with caplog.at_level(logging.DEBUG):
        result = _sender().send(MESSAGE)

    logged = " ".join(record.getMessage() for record in caplog.records)
    for secret in (ADDRESS, "sandbox-mail", "Oggetto", "Testo", "secret"):
        assert secret not in logged
        assert secret not in repr(result)


def test_a_message_that_cannot_be_formed_never_opens_a_connection(fake: type[FakeSMTP]) -> None:
    bad = MESSAGE.model_copy(update={"subject": "Ciao\r\nBcc: someone@sandbox-mail.org"})
    result = _sender().send(bad)
    assert (result.sent, result.reason) == (False, "invalid")
    assert fake.log == []


def test_the_sender_has_no_way_to_weaken_the_certificate_check() -> None:
    source = SmtpEmailSender.send.__code__.co_names + SmtpEmailSender.build.__code__.co_names
    assert "_create_unverified_context" not in source
    assert "CERT_NONE" not in source and "check_hostname" not in source
