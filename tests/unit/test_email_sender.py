"""The one e-mail door: off by default, never leaks, honours the category."""

from __future__ import annotations

import logging
import smtplib
from typing import Any

import pytest

from packages.bootstrap.container import ApplicationContainer as Container
from packages.core.application.ports.email_sender import EmailMessage
from packages.infrastructure.email.in_memory_email_sender import (
    DisabledEmailSender,
    InMemoryEmailSender,
)
from packages.infrastructure.email.smtp_email_sender import SmtpEmailSender
from packages.shared.config.settings import Settings

SERVICE = EmailMessage(to="owner@example.com", subject="Ciao", text="Testo")
COMMERCIAL = EmailMessage(
    to="owner@example.com",
    subject="Ciao",
    text="Testo",
    category="commercial",
    unsubscribe_url="https://example.com/unsubscribe/abc",
)


def test_disabled_sender_sends_nothing() -> None:
    result = DisabledEmailSender().send(SERVICE)
    assert (result.sent, result.reason) == (False, "disabled")


def test_in_memory_sender_keeps_what_it_would_send_and_can_be_switched_off() -> None:
    sender = InMemoryEmailSender()
    assert sender.send(SERVICE).sent
    assert sender.sent == [SERVICE]
    sender.enabled = False
    assert sender.send(SERVICE).reason == "disabled"
    assert len(sender.sent) == 1


@pytest.mark.parametrize(
    "bad",
    [
        SERVICE.model_copy(update={"to": "no-at-sign"}),
        SERVICE.model_copy(update={"to": "a@example.com\r\nBcc: b@example.com"}),
        SERVICE.model_copy(update={"subject": "x\r\nBcc: b@example.com"}),
        COMMERCIAL.model_copy(update={"unsubscribe_url": None}),
        COMMERCIAL.model_copy(update={"unsubscribe_url": "http://example.com/u"}),
    ],
)
def test_a_malformed_or_unsubscribeless_message_is_refused(bad: EmailMessage) -> None:
    result = InMemoryEmailSender().send(bad)
    assert (result.sent, result.reason) == (False, "invalid")


def _smtp() -> SmtpEmailSender:
    return SmtpEmailSender(
        "smtp.example.com", 587, "user", "secret", "Quokka <no-reply@example.com>"
    )


def test_a_commercial_message_carries_a_one_click_unsubscribe_and_a_service_one_does_not() -> None:
    commercial = _smtp().build(COMMERCIAL)
    assert commercial["List-Unsubscribe"] == "<https://example.com/unsubscribe/abc>"
    assert commercial["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click"
    assert _smtp().build(SERVICE)["List-Unsubscribe"] is None


def test_a_failure_returns_a_code_and_logs_neither_the_address_nor_the_text(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    address = (
        "person@sandbox-mail.org"  # not reserved: the guard lets it reach the (fake) connection
    )

    class Boom:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            raise smtplib.SMTPRecipientsRefused({address: (550, address.encode())})

    monkeypatch.setattr(smtplib, "SMTP", Boom)
    with caplog.at_level(logging.DEBUG):
        result = _smtp().send(SERVICE.model_copy(update={"to": address}))

    assert (result.sent, result.reason) == (False, "not_sent")
    logged = " ".join(record.getMessage() for record in caplog.records)
    assert address not in logged and "Testo" not in logged and "Ciao" not in logged
    assert address not in repr(result)


def test_wiring_is_off_by_default_and_a_real_provider_needs_its_settings() -> None:
    container = Container(Settings(_env_file=None))  # type: ignore[call-arg]
    assert isinstance(container.email_sender, DisabledEmailSender)

    on = {"email_sending_enabled": True, "persistence_backend": "supabase"}
    container.settings = container.settings.model_copy(update=on)
    # Switched on but no provider configured: still off.
    assert isinstance(container._build_email_sender(), DisabledEmailSender)

    container.settings = container.settings.model_copy(
        update={"smtp_host": "smtp.example.com", "email_from": "no-reply@example.com"}
    )
    assert isinstance(container._build_email_sender(), SmtpEmailSender)


def test_an_html_message_carries_its_logo_inside_it_never_as_a_link() -> None:
    """The quokka of the exit e-mails travels in the message (multipart/related, `cid:`)."""
    from email import message_from_bytes

    from packages.infrastructure.email.logo import quokka_head_png

    sender = SmtpEmailSender(
        host="smtp.example.com", port=587, username="u", password="p", sender="noreply@example.com"
    )
    mime = sender.build(
        EmailMessage(
            to="a@example.com",
            subject="Oggetto",
            text="testo",
            html='<p>ciao</p><img src="cid:quokka-logo">',
            inline_images={"quokka-logo": quokka_head_png()},
        )
    )
    parsed = message_from_bytes(mime.as_bytes())
    kinds = [part.get_content_type() for part in parsed.walk()]
    assert "multipart/related" in kinds and "image/png" in kinds
    image = next(part for part in parsed.walk() if part.get_content_type() == "image/png")
    assert image["Content-ID"] == "<quokka-logo>"
    assert image.get_payload(decode=True) == quokka_head_png()
