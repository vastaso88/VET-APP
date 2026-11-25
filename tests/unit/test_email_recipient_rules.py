"""The recipient guard (QK-18): reserved domains never receive mail, not even in production, and
an optional allow-list narrows it further. Checked before any connection is opened."""

from __future__ import annotations

import smtplib
from typing import Any

import pytest

from packages.core.application.ports.email_sender import EmailMessage
from packages.infrastructure.email.in_memory_email_sender import InMemoryEmailSender
from packages.infrastructure.email.rules import check_recipient, is_reserved_domain
from packages.infrastructure.email.smtp_email_sender import SmtpEmailSender


def _message(to: str) -> EmailMessage:
    return EmailMessage(to=to, subject="Oggetto", text="Testo")


@pytest.mark.parametrize(
    "address",
    [
        "a@example.com",
        "a@example.org",
        "a@example.net",
        "a@sub.example.com",
        "a@deep.sub.example.net",
        "A@Example.COM",
        "a@example.com.",
        "a@casa.test",
        "a@mail.invalid",
        "a@pc.localhost",
        "a@nome.example",
    ],
)
def test_reserved_domains_are_always_refused(address: str) -> None:
    assert is_reserved_domain(address)
    assert check_recipient(address) == "reserved_recipient"


@pytest.mark.parametrize(
    "address",
    [
        "a@notexample.com",  # a label that merely ends the same way
        "a@example.com.evil.org",  # example.com only as a prefix
        "a@myexample.org",
        "a@quokka-owner.it",
        "b@quokka-owner.it",
    ],
)
def test_ordinary_domains_pass_the_reserved_check(address: str) -> None:
    assert not is_reserved_domain(address)
    assert check_recipient(address) is None


def test_the_allow_list_narrows_it_to_exactly_those_addresses() -> None:
    allowed = ("Owner@Quokka-Owner.it ", "second@quokka-owner.it")
    assert check_recipient("owner@quokka-owner.it", allowed) is None
    assert check_recipient("SECOND@quokka-owner.it", allowed) is None
    assert check_recipient("third@quokka-owner.it", allowed) == "recipient_not_allowed"
    assert check_recipient("owner@quokka-owner.it.evil.org", allowed) == "recipient_not_allowed"


def test_no_allow_list_means_no_extra_limit_and_an_empty_one_allows_nobody() -> None:
    assert check_recipient("anyone@quokka-owner.it", None) is None
    assert check_recipient("anyone@quokka-owner.it", ()) == "recipient_not_allowed"


def test_reserved_domains_win_over_the_allow_list() -> None:
    assert check_recipient("a@example.com", ("a@example.com",)) == "reserved_recipient"


def test_the_real_sender_refuses_before_opening_any_connection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def forbidden(*args: Any, **kwargs: Any) -> None:
        raise AssertionError("a connection was opened")

    monkeypatch.setattr(smtplib, "SMTP", forbidden)
    monkeypatch.setattr(smtplib, "SMTP_SSL", forbidden)
    sender = SmtpEmailSender("smtp.sandbox-mail.org", 587, "u", "p", "Quokka <q@sandbox-mail.org>")

    for address in ("a@example.com", "a@x.example.org", "a@z.test"):
        result = sender.send(_message(address))
        assert (result.sent, result.reason) == (False, "reserved_recipient")


def test_the_real_sender_with_an_allow_list_refuses_the_others_before_connecting(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def forbidden(*args: Any, **kwargs: Any) -> None:
        raise AssertionError("a connection was opened")

    monkeypatch.setattr(smtplib, "SMTP", forbidden)
    sender = SmtpEmailSender(
        "smtp.sandbox-mail.org",
        587,
        "u",
        "p",
        "Quokka <q@sandbox-mail.org>",
        allowed_recipients=("owner@quokka-owner.it",),
    )

    result = sender.send(_message("someone@quokka-owner.it"))

    assert (result.sent, result.reason) == (False, "recipient_not_allowed")


def test_the_real_sender_has_no_switch_to_turn_the_guard_off() -> None:
    parameters = SmtpEmailSender.__init__.__code__.co_varnames
    assert not any(
        "reserved" in name or "bypass" in name or "unsafe" in name for name in parameters
    )


def test_the_test_double_accepts_example_com_unless_asked_to_be_strict() -> None:
    assert InMemoryEmailSender().send(_message("a@example.com")).sent is True
    strict = InMemoryEmailSender(strict_recipients=True)
    assert strict.send(_message("a@example.com")).reason == "reserved_recipient"
    assert strict.sent == []
