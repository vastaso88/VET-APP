"""EMAIL_ALLOWED_RECIPIENTS: absent and empty are DIFFERENT cases, and any doubt closes the door.

- variable absent  -> no allow-list: EMAIL_SENDING_ENABLED alone decides;
- variable present -> an allow-list is in force; empty or unreadable allows nobody."""

from __future__ import annotations

import smtplib
from pathlib import Path
from typing import Any

import pytest

from packages.bootstrap.container import ApplicationContainer
from packages.core.application.ports.email_sender import EmailMessage
from packages.infrastructure.email.rules import check_recipient, parse_allowed_recipients
from packages.infrastructure.email.smtp_email_sender import SmtpEmailSender
from packages.shared.config.settings import Settings

GOOD = "owner@quokka-owner.it"


def _message(to: str) -> EmailMessage:
    return EmailMessage(to=to, subject="Oggetto", text="Testo")


# ------------------------------------------------------------------------- the parsing


def test_absent_means_there_is_no_allow_list() -> None:
    assert parse_allowed_recipients(None) is None


@pytest.mark.parametrize("raw", ["", "   ", ",", " , , ", "\n"])
def test_present_but_empty_allows_nobody(raw: str) -> None:
    assert parse_allowed_recipients(raw) == ()


@pytest.mark.parametrize(
    "raw",
    [
        "not-an-address",
        f"{GOOD}, not-an-address",  # one bad entry closes the whole list
        "owner@",
        "@quokka-owner.it",
        "owner@localhost",
        "a@b@quokka-owner.it",
        "Owner <owner@quokka-owner.it>",
        f"{GOOD};second@quokka-owner.it",
        f"{GOOD} second@quokka-owner.it",
        "'owner@quokka-owner.it'",
    ],
)
def test_an_unreadable_value_allows_nobody(raw: str) -> None:
    assert parse_allowed_recipients(raw) == ()


def test_a_clean_list_is_read_without_case_or_spaces() -> None:
    assert parse_allowed_recipients(" Owner@Quokka-Owner.it ,second@quokka-owner.it,") == (
        GOOD,
        "second@quokka-owner.it",
    )


def test_an_empty_list_refuses_even_a_valid_address() -> None:
    assert check_recipient(GOOD, parse_allowed_recipients("")) == "recipient_not_allowed"
    assert check_recipient(GOOD, parse_allowed_recipients(None)) is None


# ------------------------------------------------------------------------- the setting


def test_the_setting_keeps_absent_and_empty_apart(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("EMAIL_ALLOWED_RECIPIENTS", raising=False)
    assert Settings(_env_file=None).email_allowed_recipients is None  # type: ignore[call-arg]

    monkeypatch.setenv("EMAIL_ALLOWED_RECIPIENTS", "")
    assert Settings(_env_file=None).email_allowed_recipients == ""  # type: ignore[call-arg]

    monkeypatch.setenv("EMAIL_ALLOWED_RECIPIENTS", GOOD)
    assert Settings(_env_file=None).email_allowed_recipients == GOOD  # type: ignore[call-arg]


# ------------------------------------------------------------------------- the wiring


def _production_sender(allowed: str | None) -> SmtpEmailSender:
    container = ApplicationContainer(Settings(_env_file=None))  # type: ignore[call-arg]
    container.settings = container.settings.model_copy(
        update={
            "email_sending_enabled": True,
            "persistence_backend": "supabase",
            "smtp_host": "smtp.sandbox-mail.org",
            "email_from": "q@sandbox-mail.org",
            "email_allowed_recipients": allowed,
        }
    )
    sender = container._build_email_sender()
    assert isinstance(sender, SmtpEmailSender)
    return sender


@pytest.fixture
def no_connection(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    opened: list[str] = []

    class Recording:
        def __init__(self, host: str, *args: Any, **kwargs: Any) -> None:
            opened.append(host)
            raise ConnectionRefusedError()  # nothing is ever contacted

    monkeypatch.setattr(smtplib, "SMTP", Recording)
    monkeypatch.setattr(smtplib, "SMTP_SSL", Recording)
    return opened


def test_with_no_variable_only_the_switch_decides(no_connection: list[str]) -> None:
    sender = _production_sender(None)

    # Any ordinary address is let through to the connection (which here refuses to open) ...
    result = sender.send(_message("anyone@quokka-owner.it"))
    assert (result.sent, result.reason) == (False, "not_sent")
    assert no_connection == ["smtp.sandbox-mail.org"]
    # ... but a reserved domain never is.
    assert sender.send(_message("a@example.com")).reason == "reserved_recipient"


@pytest.mark.parametrize("allowed", ["", "   ,  ", "not-an-address"])
def test_with_the_variable_empty_or_unreadable_nothing_goes_out(
    no_connection: list[str], allowed: str
) -> None:
    sender = _production_sender(allowed)

    for address in (GOOD, "anyone@quokka-owner.it"):
        result = sender.send(_message(address))
        assert (result.sent, result.reason) == (False, "recipient_not_allowed")
    assert no_connection == []  # not even a connection


def test_with_a_list_only_those_addresses_reach_the_connection(no_connection: list[str]) -> None:
    sender = _production_sender(GOOD)

    assert sender.send(_message(GOOD)).reason == "not_sent"  # reached the (refusing) connection
    assert sender.send(_message("other@quokka-owner.it")).reason == "recipient_not_allowed"
    assert no_connection == ["smtp.sandbox-mail.org"]


# ------------------------------------------------------------------------- the documentation


def test_the_example_env_file_says_how_the_two_cases_differ() -> None:
    text = Path(".env.example").read_text(encoding="utf-8")
    lines = [line.strip() for line in text.splitlines()]
    # The variable is NOT set in the example: copying the file must not close the door by accident.
    assert "EMAIL_ALLOWED_RECIPIENTS=" not in lines
    assert "# EMAIL_ALLOWED_RECIPIENTS=" in lines
    note = text[
        text.index("EMAIL_ALLOWED_RECIPIENTS") - 700 : text.index("EMAIL_ALLOWED_RECIPIENTS")
    ]
    for phrase in ("absent", "empty", "nothing"):
        assert phrase in note.lower()
