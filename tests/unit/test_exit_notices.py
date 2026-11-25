"""QK-18: the e-mails of deletion and restore. Sending is OFF by default; these tests switch it on
only on in-memory doubles. Every address is example.com (the in-memory sender accepts it; the
real sender refuses it, which its own tests prove)."""

from __future__ import annotations

import logging
import re
from datetime import UTC, date, datetime, timedelta
from typing import Any, cast

import pytest

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.ports.email_sender import (
    NOT_SENT,
    UNCERTAIN,
    EmailMessage,
    SendResult,
)
from packages.core.application.ports.owner_contact_lookup import OwnerContact
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.application.services.exit_notices import ExitNoticeService
from packages.core.application.services.notice_mailer import (
    NoticeConfig,
    NoticeMailer,
    SendBudget,
)
from packages.core.domain.account_deletion import notices
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.core.domain.exit_notices import texts
from packages.infrastructure.email.in_memory_email_sender import InMemoryEmailSender
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.infrastructure.persistence.in_memory_deletion_log import (
    InMemoryDeletionLogCopy,
    InMemoryDeletionLogRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import InMemoryOwnerContactLookup

OWNER_A = "11111111-1111-4111-8111-111111111111"
OWNER_B = "22222222-2222-4222-8222-222222222222"
OWNER_C = "33333333-3333-4333-8333-333333333333"
T0 = datetime(2026, 12, 1, 10, 0, tzinfo=UTC)

CONFIG = NoticeConfig(
    legal_entity="Quokka Test S.r.l.",
    contact="support@example.com",
    login_url="https://app.example.com/accedi",
    privacy_url="https://example.com/privacy",
    proof_years=5,
)
ADULT = date(1990, 5, 20)


def _contact(address: str, **kwargs: object) -> OwnerContact:
    values: dict[str, object] = {
        "email": address,
        "email_confirmed": True,
        "birth_date": ADULT,
        "display_name": "Mario Rossi",
    }
    values.update(kwargs)
    return OwnerContact(**values)  # type: ignore[arg-type]


class World:
    """A deletion service, a mailer and the doubles behind them."""

    def __init__(
        self, *, enabled: bool = True, config: NoticeConfig = CONFIG, required: bool = False
    ) -> None:
        self.sender = InMemoryEmailSender()
        self.contacts = InMemoryOwnerContactLookup()
        self.contacts.register(OWNER_A, _contact("a@example.com", display_name="Anna Verdi"))
        self.contacts.register(OWNER_B, _contact("b@example.com", display_name="Bruno Neri"))
        self.mailer = NoticeMailer(self.sender, self.contacts, config, enabled)
        self.deletions = InMemoryAccountDeletionRepository()
        self.erased: list[str] = []
        self.contact_lookups_after_erase: list[str] = []

        outer = self

        class Eraser:
            def erase_data(self, owner_id: str) -> ErasureReport:
                outer.erased.append(owner_id)
                return ErasureReport(rows_deleted={}, files_removed=0)

            def delete_identity(self, owner_id: str) -> None:
                # The identity is gone: the address cannot be read any more.
                outer.contacts._items.pop(owner_id, None)

        self.log_repository = InMemoryDeletionLogRepository()
        log = DeletionLogService(self.log_repository, InMemoryDeletionLogCopy(), 37, 5)
        self.deletion = AccountDeletionService(
            self.deletions,
            cast(Any, Eraser()),
            30,
            log=log,
            mailer=self.mailer,
            notices_required=required,
        )
        self.runner = ExitNoticeService(self.deletion, self.mailer, 40)

    def request(self, owner: str, at: datetime = T0, days: int = 30) -> None:
        self.deletions.create(
            AccountDeletionRequest(
                owner_id=owner, requested_at=at, purge_after=at + timedelta(days=days)
            )
        )

    def subjects(self) -> list[str]:
        return [message.subject for message in self.sender.sent]

    def recipients(self) -> list[str]:
        return [message.to for message in self.sender.sent]


# --------------------------------------------------------------------- the texts


@pytest.mark.parametrize("template_id", sorted(texts.TEXTS))
def test_every_text_renders_whole_with_no_field_left(template_id: str) -> None:
    variables = {
        "saluto": texts.greeting("Mario"),
        "data": "1 dicembre 2026",
        "data_fine": "31 dicembre 2026",
        "durata": "un anno",
        "tempo_rimasto": "mancano 5 giorni",
        "anni_dopo": "Un anno dopo",
        "titolare": "Quokka Test S.r.l.",
        "contatto": "support@example.com",
        "link_recupera": "https://app.example.com/accedi",
        "link_informativa": "https://example.com/privacy",
        "anni_registro": "5",
        "mesi_pausa": "24",
    }
    subject, body = texts.render_notice(template_id, variables)

    assert "{" not in subject + body and "}" not in subject + body
    assert "<" not in body and "http://" not in body
    # The links lead to the sign-in and the notice; nothing carries an id, a token or an address.
    for link in re.findall(r"https://\S+", body):
        assert "?" not in link and "@" not in link
    assert "Mario" not in subject  # the name never goes into a subject
    # Service messages: no offer, no invitation to buy.
    for word in ("sconto", "offerta", "piano a pagamento", "abbonati"):
        assert word not in body.lower()


def test_a_text_with_a_missing_variable_is_never_sent_with_a_hole() -> None:
    with pytest.raises(texts.NoticeTextError):
        texts.render_notice("D1", {"saluto": "Ciao,"})


def test_the_greeting_is_safe_whatever_the_name_holds() -> None:
    assert texts.greeting("Mario Rossi") == "Ciao Mario,"
    assert texts.greeting(None) == "Ciao,"
    assert texts.greeting("   ") == "Ciao,"
    assert texts.greeting("{nome}\r\nBcc: x@example.com") == "Ciao nome,"
    assert texts.greeting("A" * 500).count("A") == 40


def test_dates_and_durations_read_in_italian() -> None:
    assert texts.format_date(datetime(2026, 12, 16, tzinfo=UTC)) == "16 dicembre 2026"
    # Whole years in words, months in digits.
    assert [texts.format_duration(m) for m in (1, 7, 12, 23, 24, 36, 48)] == [
        "1 mese",
        "7 mesi",
        "un anno",
        "23 mesi",
        "due anni",
        "tre anni",
        "4 anni",
    ]


# --------------------------------------------------------------------- the mailer


def test_sending_off_looks_nothing_up_and_sends_nothing() -> None:
    world = World(enabled=False)
    looked_up: list[str] = []
    real = world.contacts.get

    def spy(owner_id: str) -> OwnerContact | None:
        looked_up.append(owner_id)
        return real(owner_id)

    world.contacts.get = spy  # type: ignore[method-assign]
    world.request(OWNER_A)

    report = world.runner.run(T0)

    assert report.sending_enabled is False and report.ready is False
    assert report.deletion.due == 1 and report.deletion.sent == 0
    assert report.deletion.blocked == "sending_off"
    assert looked_up == [] and world.sender.sent == []
    # Nothing was written either: it will be due, and sent, once sending is on.
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]


def test_missing_links_block_sending_and_are_not_patched_with_a_phrase() -> None:
    for broken in (
        NoticeConfig(**{**CONFIG.__dict__, "login_url": ""}),
        NoticeConfig(**{**CONFIG.__dict__, "privacy_url": "http://example.com/privacy"}),
    ):
        world = World(config=broken)
        world.request(OWNER_A)
        report = world.runner.run(T0)
        assert report.sending_enabled is True and report.ready is False
        assert report.deletion.blocked == "not_configured"
        assert world.sender.sent == []


def test_the_company_and_the_contact_are_optional_the_signature_is_the_team() -> None:
    """Owner, 25 November: «Il team di Quokka»; the company and the contact are NOT required to
    send and appear only in a footer line, and only when both are configured."""
    bare = NoticeConfig(**{**CONFIG.__dict__, "legal_entity": "", "contact": ""})
    world = World(config=bare)
    world.request(OWNER_A)
    report = world.runner.run(T0)
    assert report.ready is True and report.deletion.sent == 1
    sent = world.sender.sent[0]
    assert sent.text.rstrip().endswith("Il team di Quokka")
    assert sent.html is not None and "Il team di Quokka" in sent.html

    full = World()
    full.request(OWNER_A)
    full.runner.run(T0)
    assert (
        full.sender.sent[0]
        .text.rstrip()
        .endswith("Quokka è un servizio di Quokka Test S.r.l. · support@example.com")
    )


@pytest.mark.parametrize(
    ("contact", "reason"),
    [
        (None, "no_contact"),
        (_contact(None), "no_address"),  # type: ignore[arg-type]
        (_contact("c@example.com", email_confirmed=False), "unconfirmed"),
        (_contact("c@example.com", birth_date=date(2018, 1, 1)), "closed_by_age"),
        (_contact("c@example.com", language="de"), "language_not_ready"),
    ],
)
def test_an_account_that_cannot_or_must_not_be_written_to_is_skipped_not_failed(
    contact: OwnerContact | None, reason: str
) -> None:
    world = World()
    if contact is not None:
        world.contacts.register(OWNER_C, contact)
    world.request(OWNER_C)

    counts = world.runner.run(T0).deletion

    assert (counts.sent, counts.failed, counts.skipped) == (0, 0, 1)
    assert counts.skipped_by_reason == {reason: 1}
    assert world.sender.sent == []
    assert world.deletions.get(OWNER_C).last_notice is None  # type: ignore[union-attr]


def test_a_minor_of_14_to_17_gets_the_same_service_texts() -> None:
    world = World()
    world.contacts.register(OWNER_C, _contact("m@example.com", birth_date=date(2011, 3, 1)))
    world.request(OWNER_C)
    world.runner.run(T0)
    assert world.subjects() == [
        "Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka"
    ]
    assert world.sender.sent[0].category == "service"


def test_the_first_name_greets_and_the_surname_stays_out() -> None:
    world = World()
    world.request(OWNER_A)
    world.runner.run(T0)
    body = world.sender.sent[0].text
    assert body.startswith("Ciao Anna,") and "Verdi" not in body


# --------------------------------------------------------------------- «Elimina»


def test_d1_then_d2_then_d3_each_once_at_its_moment() -> None:
    world = World()
    world.request(OWNER_A)

    world.runner.run(T0)
    world.runner.run(T0 + timedelta(hours=1))  # same notice, already sent
    assert world.subjects() == [
        "Abbiamo ricevuto la tua richiesta: eliminiamo il tuo account Quokka"
    ]

    world.runner.run(T0 + timedelta(days=22, hours=23))
    assert len(world.sender.sent) == 1  # day 23 not reached yet

    world.runner.run(T0 + timedelta(days=23))
    world.runner.run(T0 + timedelta(days=24))
    assert world.subjects()[-1] == "Tra 7 giorni cancelliamo il tuo account Quokka"

    world.runner.run(T0 + timedelta(days=29))
    world.runner.run(T0 + timedelta(days=29, hours=5))
    assert world.subjects()[-1] == "Domani cancelliamo il tuo account Quokka"
    assert len(world.sender.sent) == 3
    assert world.deletions.get(OWNER_A).last_notice == "tomorrow"  # type: ignore[union-attr]


def test_a_scheduler_that_was_off_sends_one_message_never_a_burst() -> None:
    world = World()
    world.request(OWNER_A)

    world.runner.run(T0 + timedelta(days=29, hours=2))

    assert world.subjects() == ["Domani cancelliamo il tuo account Quokka"]


def test_the_dates_in_the_message_are_the_real_ones() -> None:
    world = World()
    world.request(OWNER_A, at=datetime(2026, 12, 1, 10, 0, tzinfo=UTC))
    world.runner.run(T0)
    body = world.sender.sent[0].text
    assert "il 1 dicembre 2026 ci hai chiesto" in body and "il 31 dicembre 2026" in body


def test_a_failed_send_is_not_recorded_and_is_tried_again_next_run() -> None:
    world = World()
    world.request(OWNER_A)
    world.sender.enabled = False  # every send fails with "disabled": counts as skipped
    world.runner.run(T0)
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]

    class Failing(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            return SendResult(sent=False, reason=NOT_SENT)

    world.mailer._sender = Failing()  # type: ignore[attr-defined]
    counts = world.runner.run(T0 + timedelta(minutes=5)).deletion
    assert (counts.sent, counts.failed) == (0, 1)
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]

    world.mailer._sender = world.sender  # type: ignore[attr-defined]
    world.sender.enabled = True
    counts = world.runner.run(T0 + timedelta(minutes=10)).deletion
    assert counts.sent == 1 and len(world.sender.sent) == 1
    assert world.runner.run(T0 + timedelta(minutes=15)).deletion.sent == 0  # never twice


def test_a_reserved_or_unlisted_recipient_is_skipped_never_recorded() -> None:
    world = World()
    world.sender = InMemoryEmailSender(strict_recipients=True)  # applies the real guard
    world.mailer._sender = world.sender  # type: ignore[attr-defined]
    world.request(OWNER_A)  # a@example.com: reserved

    counts = world.runner.run(T0).deletion

    assert (counts.sent, counts.failed, counts.skipped) == (0, 0, 1)
    assert counts.skipped_by_reason == {"reserved_recipient": 1}
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]


def test_the_column_must_exist_before_the_first_send() -> None:
    world = World()
    world.deletions.notice_log_available = lambda: False  # type: ignore[method-assign]
    world.request(OWNER_A)

    counts = world.runner.run(T0).deletion

    assert counts.blocked == "no_notice_log" and counts.sent == 0
    assert world.sender.sent == []


# --------------------------------------------------------------------- booking before sending


class _Sender(InMemoryEmailSender):
    """A sender that answers what the test says, once per call."""

    def __init__(self, *answers: SendResult) -> None:
        super().__init__()
        self.answers = list(answers)
        self.calls = 0

    def send(self, message: EmailMessage) -> SendResult:
        self.calls += 1
        answer = self.answers.pop(0) if self.answers else SendResult(sent=True)
        if answer.sent:
            self.sent.append(message)
        return answer


def test_the_attempt_is_booked_before_the_message_goes() -> None:
    world = World()
    world.request(OWNER_A)
    seen: list[str | None] = []

    class Peeking(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            seen.append(world.deletions.get(OWNER_A).last_notice)  # type: ignore[union-attr]
            return super().send(message)

    world.mailer._sender = Peeking()  # type: ignore[attr-defined]
    world.runner.run(T0)

    assert seen == ["confirmed"]  # already booked when the sender was called


def test_two_runs_cannot_both_send_the_same_notice() -> None:
    """The second run reads the row before the first booked it, then tries to book too."""
    world = World()
    world.request(OWNER_A)
    stale = world.deletions.list_pending()[0]  # what the slower run read: last_notice None

    world.runner.run(T0)  # the first run books and sends
    assert len(world.sender.sent) == 1

    booked = world.deletions.claim_notice(OWNER_A, "confirmed", stale.last_notice, T0)
    assert booked is False  # the conditional update finds the row already booked


def test_a_booking_somebody_else_holds_means_nothing_is_sent() -> None:
    world = World()
    world.request(OWNER_A)

    def taken(owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        return False

    world.deletions.claim_notice = taken  # type: ignore[method-assign]

    counts = world.runner.run(T0).deletion

    assert counts.sent == 0 and counts.skipped_by_reason == {"already_booked": 1}
    assert world.sender.sent == []


def test_a_message_that_certainly_did_not_go_gives_the_booking_back() -> None:
    world = World()
    world.request(OWNER_A)
    sender = _Sender(SendResult(sent=False, reason=NOT_SENT))
    world.mailer._sender = sender  # type: ignore[attr-defined]

    first = world.runner.run(T0).deletion
    assert (first.failed, first.uncertain, first.sent) == (1, 0, 0)
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]

    second = world.runner.run(T0 + timedelta(minutes=5)).deletion
    assert second.sent == 1 and sender.calls == 2
    assert world.deletions.get(OWNER_A).last_notice == "confirmed"  # type: ignore[union-attr]


def test_a_refusal_for_good_keeps_the_booking_and_is_not_repeated() -> None:
    world = World()
    world.request(OWNER_A)
    sender = _Sender(SendResult(sent=False, reason="rejected"))
    world.mailer._sender = sender  # type: ignore[attr-defined]

    first = world.runner.run(T0).deletion
    world.runner.run(T0 + timedelta(minutes=5))

    assert (first.rejected, first.attempted, first.failed) == (1, 1, 0)
    assert sender.calls == 1
    assert world.deletions.get(OWNER_A).last_notice == "confirmed"  # type: ignore[union-attr]


def test_an_uncertain_outcome_keeps_the_booking_and_is_never_sent_again() -> None:
    world = World()
    world.request(OWNER_A)
    sender = _Sender(SendResult(sent=False, reason=UNCERTAIN))
    world.mailer._sender = sender  # type: ignore[attr-defined]

    first = world.runner.run(T0).deletion
    assert (first.uncertain, first.failed, first.sent) == (1, 0, 0)
    assert world.deletions.get(OWNER_A).last_notice == "confirmed"  # type: ignore[union-attr]

    world.runner.run(T0 + timedelta(minutes=5))
    world.runner.run(T0 + timedelta(hours=3))
    assert sender.calls == 1  # not tried again: it may have been delivered


def test_a_reason_nobody_planned_is_treated_as_uncertain() -> None:
    world = World()
    world.request(OWNER_A)
    sender = _Sender(SendResult(sent=False, reason="something-new"))
    world.mailer._sender = sender  # type: ignore[attr-defined]
    world.runner.run(T0)
    world.runner.run(T0 + timedelta(minutes=5))
    assert sender.calls == 1


def test_if_the_booking_cannot_be_written_nothing_is_sent_and_the_run_stops() -> None:
    world = World()

    def boom(owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        raise RuntimeError("write failed")

    world.deletions.claim_notice = boom  # type: ignore[method-assign]
    world.request(OWNER_A)
    world.request(OWNER_B)

    counts = world.runner.run(T0).deletion

    assert counts.blocked == "record_failed"
    assert world.sender.sent == []


def test_if_the_booking_cannot_be_given_back_the_run_stops() -> None:
    world = World()
    world.mailer._sender = _Sender(SendResult(sent=False, reason=NOT_SENT))  # type: ignore[attr-defined]

    def boom(
        owner_id: str, notice: str, previous: str | None, previous_at: datetime | None
    ) -> None:
        raise RuntimeError("write failed")

    world.deletions.release_notice = boom  # type: ignore[method-assign]
    world.request(OWNER_A)
    world.request(OWNER_B)

    counts = world.runner.run(T0).deletion

    assert counts.blocked == "release_failed" and counts.failed == 1


def test_a_skipped_account_books_nothing() -> None:
    world = World()
    world.contacts.register(OWNER_C, _contact("c@example.com", email_confirmed=False))
    world.request(OWNER_C)
    claimed: list[str] = []
    real = world.deletions.claim_notice

    def spy(owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        claimed.append(owner_id)
        return real(owner_id, notice, previous, at)

    world.deletions.claim_notice = spy  # type: ignore[method-assign]
    world.runner.run(T0)
    assert claimed == []


def test_the_recipient_guard_is_asked_before_booking() -> None:
    """Reserved domains cost no write: the mailer asks the guard before booking."""
    world = World()
    world.mailer._recipient_check = lambda address: "reserved_recipient"  # type: ignore[attr-defined]
    world.request(OWNER_A)

    counts = world.runner.run(T0).deletion

    assert counts.skipped_by_reason == {"reserved_recipient": 1}
    assert world.deletions.get(OWNER_A).last_notice is None  # type: ignore[union-attr]


def test_the_cap_of_a_run_postpones_the_rest_to_the_next_run() -> None:
    world = World()
    world.runner = ExitNoticeService(world.deletion, world.mailer, 1)
    world.request(OWNER_A)
    world.request(OWNER_B)

    first = world.runner.run(T0).deletion
    second = world.runner.run(T0 + timedelta(minutes=1)).deletion

    assert (first.sent, first.postponed) == (1, 1)
    assert second.sent == 1
    assert sorted(world.recipients()) == ["a@example.com", "b@example.com"]


def test_user_b_never_gets_user_as_message_and_each_has_their_own_record() -> None:
    world = World()
    world.request(OWNER_A, at=T0)
    world.request(OWNER_B, at=T0 + timedelta(days=10))

    world.runner.run(T0 + timedelta(days=10, hours=1))

    by_address = {m.to: m.text for m in world.sender.sent}
    assert set(by_address) == {"a@example.com", "b@example.com"}
    assert by_address["a@example.com"].startswith("Ciao Anna,")
    assert by_address["b@example.com"].startswith("Ciao Bruno,")
    # A is 10 days in (D1 sent once), B is brand new (D1): neither got the other's address.
    assert all("b@example.com" not in v for k, v in by_address.items() if k == "a@example.com")
    assert world.deletions.get(OWNER_A).last_notice == "confirmed"  # type: ignore[union-attr]
    assert world.deletions.get(OWNER_B).last_notice == "confirmed"  # type: ignore[union-attr]


def test_a_user_account_closed_for_age_gets_no_message_at_all() -> None:
    world = World()
    world.contacts.register(OWNER_C, _contact("kid@example.com", birth_date=date(2018, 6, 1)))
    world.request(OWNER_C)
    world.runner.run(T0)
    world.deletion.purge_due(True, T0 + timedelta(days=31))
    assert world.sender.sent == []
    assert OWNER_C in world.erased  # erased, silently


# --------------------------------------------------------------------- the closing e-mail (D4)


def test_d4_is_written_to_the_address_read_before_the_erase() -> None:
    world = World()
    world.request(OWNER_A)
    world.deletion.send_notices(T0)
    world.sender.sent.clear()

    report = world.deletion.purge_due(True, T0 + timedelta(days=31))

    assert report.erased == 1 and report.closing_sent == 1
    assert world.erased == [OWNER_A]
    assert world.recipients() == ["a@example.com"]  # although the identity is gone by then
    assert world.subjects() == ["Il tuo account Quokka è stato eliminato"]
    assert "non ti scriveremo più su questa richiesta" in world.sender.sent[0].text.lower()
    assert world.contacts.get(OWNER_A) is None  # and nothing keeps the address


def test_d4_failing_never_undoes_the_erase_and_is_not_retried() -> None:
    world = World()
    world.request(OWNER_A)

    class Failing(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            return SendResult(sent=False, reason=NOT_SENT)

    world.mailer._sender = Failing()  # type: ignore[attr-defined]
    report = world.deletion.purge_due(True, T0 + timedelta(days=31))

    assert (report.erased, report.closing_failed, report.closing_sent) == (1, 1, 0)
    assert world.deletions.get(OWNER_A) is None


def test_with_sending_off_the_purge_reads_no_address_and_writes_nothing() -> None:
    world = World(enabled=False)
    world.request(OWNER_A)
    looked_up: list[str] = []
    real = world.contacts.get

    def spy(owner_id: str) -> OwnerContact | None:
        looked_up.append(owner_id)
        return real(owner_id)

    world.contacts.get = spy  # type: ignore[method-assign]

    report = world.deletion.purge_due(True, T0 + timedelta(days=31))

    assert report.erased == 1 and report.closing_sent == 0
    assert looked_up == [] and world.sender.sent == []


def test_the_thirty_days_are_never_held_back_waiting_for_a_notice() -> None:
    world = World()
    world.request(OWNER_A)  # never notified
    report = world.deletion.purge_due(True, T0 + timedelta(days=30, minutes=1))
    assert report.erased == 1  # the legal maximum comes first


# --------------------------------------------------------------------- the restore message (R1)


def test_r1_goes_once_after_a_restore_and_never_raises() -> None:
    world = World()
    outcome = world.deletion.send_restore_notice(OWNER_A)
    assert outcome.kind == "sent"
    assert world.subjects() == ["Hai ripristinato il tuo account Quokka"]
    assert "cambia la password" in world.sender.sent[0].text

    class Exploding(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            raise RuntimeError("provider down")

    world.mailer._sender = Exploding()  # type: ignore[attr-defined]
    assert world.deletion.send_restore_notice(OWNER_A).kind == "failed"


# --------------------------------------------------------------------- «Metti in pausa»


def test_the_budget_counts_attempts_not_skips() -> None:
    budget = SendBudget(1)
    assert not budget.exhausted
    budget.spend()
    assert budget.exhausted


# --------------------------------------------------------------------- logs and answers


def test_nothing_personal_reaches_the_logs_or_the_counts(
    caplog: pytest.LogCaptureFixture,
) -> None:
    world = World()
    world.request(OWNER_A)
    world.request(OWNER_B)

    class Exploding(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            raise RuntimeError(f"cannot write to {message.to}: {message.subject}")

    world.mailer._sender = Exploding()  # type: ignore[attr-defined]
    with caplog.at_level(logging.DEBUG):
        report = world.runner.run(T0)

    logged = " ".join(record.getMessage() for record in caplog.records)
    for secret in (
        "a@example.com",
        "b@example.com",
        "Anna",
        "Bruno",
        "Abbiamo ricevuto",
        "account",
    ):
        assert secret not in logged
    dumped = str(report.model_dump())
    for secret in ("@", "Anna", "Bruno", OWNER_A, OWNER_B):
        assert secret not in dumped
    # A sender that blows up midway may have sent: counted as uncertain, never as failed.
    assert report.deletion.uncertain == 2


# ======================== QK-18, the Normativa rules (doc 18 §8.9) ========================

from packages.core.application.services.delete_account import (  # noqa: E402
    DeleteAccountInput,
    DeleteAccountService,
)
from packages.core.domain.account_deletion.log import DeletionReason  # noqa: E402
from packages.core.domain.exit_notices import timing  # noqa: E402


def _delete_service(world: World) -> DeleteAccountService:
    return DeleteAccountService(
        world.deletion._eraser,  # type: ignore[attr-defined]
        world.deletion._log,  # type: ignore[attr-defined]
        world.mailer,
    )


def _now_input(owner: str, reason: str = DeletionReason.USER_NOW) -> DeleteAccountInput:
    return DeleteAccountInput(owner_id=owner, signed_in_at=T0, now=T0, reason=reason)


# ---- D4 for «Elimina subito»


def test_elimina_subito_writes_d4_to_the_address_read_before_the_erase() -> None:
    world = World()

    _delete_service(world).execute(_now_input(OWNER_A))

    assert world.erased == [OWNER_A]
    assert world.recipients() == ["a@example.com"]
    assert world.subjects() == ["Il tuo account Quokka è stato eliminato"]


def test_the_closing_email_can_be_deferred_so_it_never_delays_the_deletion() -> None:
    world = World()
    deferred: list = []

    _delete_service(world).execute(_now_input(OWNER_A), defer=deferred.append)

    assert world.erased == [OWNER_A] and world.sender.sent == []  # erased, not yet written
    assert len(deferred) == 1
    deferred[0]()
    assert world.recipients() == ["a@example.com"]


def test_an_account_closed_for_age_never_gets_the_closing_email() -> None:
    world = World()
    world.contacts.register(OWNER_C, _contact("kid@example.com", birth_date=date(2018, 6, 1)))
    for reason in (DeletionReason.CLOSED_BY_AGE_USER, DeletionReason.CLOSED_BY_AGE_TEAM):
        _delete_service(world).execute(_now_input(OWNER_B, reason))
    _delete_service(world).execute(_now_input(OWNER_C))  # even by its own request: under 14
    assert world.sender.sent == []


def test_a_failing_closing_email_never_fails_the_deletion() -> None:
    world = World()

    class Exploding(InMemoryEmailSender):
        def send(self, message: EmailMessage) -> SendResult:
            raise RuntimeError("provider down")

    world.mailer._sender = Exploding()  # type: ignore[attr-defined]
    report = _delete_service(world).execute(_now_input(OWNER_A))
    assert report is not None and world.erased == [OWNER_A]


def test_the_closing_email_is_sent_once_and_never_repeated_or_queued() -> None:
    """D4: one send, no repeat, nothing in a queue (docs/compliance/18, final rule)."""
    for reason in (NOT_SENT, "rejected", UNCERTAIN):
        world = World()
        sender = _Sender(SendResult(sent=False, reason=reason), SendResult(sent=True))
        world.mailer._sender = sender  # type: ignore[attr-defined]
        recipient = world.mailer.recipient_for(OWNER_A, T0)
        assert not isinstance(recipient, str)

        outcome = world.mailer.deliver(recipient, "D4", {})

        assert outcome.kind == "failed" and sender.calls == 1
    assert not hasattr(NoticeMailer, "deliver_closing")


def test_a_failed_closing_email_of_the_period_end_is_counted_and_the_erase_stands() -> None:
    world = World()
    world.request(OWNER_A)
    sender = _Sender(SendResult(sent=False, reason=NOT_SENT))
    world.mailer._sender = sender  # type: ignore[attr-defined]

    report = world.deletion.purge_due(True, T0 + timedelta(days=31))

    assert (report.erased, report.closing_failed, report.closing_sent) == (1, 1, 0)
    assert sender.calls == 1


# ---- «Elimina»: nothing waits for a notice


def test_the_erase_of_elimina_never_looks_at_the_notices() -> None:
    world = World()
    world.request(OWNER_A)  # nothing was ever sent
    world.mailer._sender = _Sender(*[SendResult(sent=False, reason=NOT_SENT)] * 9)  # type: ignore[attr-defined]

    before = world.deletion.purge_due(True, T0 + timedelta(days=30) - timedelta(minutes=1))
    on_day = world.deletion.purge_due(True, T0 + timedelta(days=30))

    assert (before.erased, on_day.erased) == (0, 1)  # the day comes, notice or not
    assert world.deletions.get(OWNER_A) is None


def test_the_team_is_told_when_d1_or_d3_have_not_gone() -> None:
    world = World(enabled=False)  # nothing goes, as when the provider is down
    world.request(OWNER_A, at=T0)

    young = world.runner.run(T0 + timedelta(hours=23)).deletion
    assert young.overdue == {}

    late_d1 = world.runner.run(T0 + timedelta(hours=25)).deletion
    assert late_d1.overdue == {"D1": 1}

    late_d3 = world.runner.run(T0 + timedelta(days=29, hours=1)).deletion
    assert late_d3.overdue == {"D1": 1, "D3": 1}
    # Numbers only.
    assert "@" not in str(late_d3.model_dump())


def test_a_notice_for_a_date_that_has_come_is_not_sent() -> None:
    world = World()
    world.request(OWNER_A, at=T0)
    counts = world.deletion.send_notices(T0 + timedelta(days=30, minutes=1))
    assert counts.due == 0 and world.sender.sent == []


# ---- a notice that goes late says the true thing


def test_d3_in_time_says_tomorrow_and_on_the_day_of_the_erasure_it_is_the_plain_date() -> None:
    world = World()
    world.request(OWNER_A, at=T0)
    world.runner.run(T0 + timedelta(days=29, hours=2))  # the day before the erase
    assert world.subjects() == ["Domani cancelliamo il tuo account Quokka"]

    # An hour before the date, with the notices required the date moves to at least 20 hours
    # after the sending: it is now «domani» (1 January) and the text says so truly.
    other = World(required=True)
    other.request(OWNER_A, at=T0)
    other.deletion.send_notices(T0 + timedelta(days=29, hours=23))
    assert other.subjects() == ["Domani cancelliamo il tuo account Quokka"]
    assert "1 gennaio 2027" in other.sender.sent[0].text


def test_a_week_notice_two_days_late_is_the_plain_text_with_the_date() -> None:
    world = World()
    world.request(OWNER_A, at=T0)
    world.runner.run(T0 + timedelta(days=25))  # five days before the date, D2 not sent yet
    text = world.sender.sent[0].text
    assert world.subjects() == ["Cancelliamo il tuo account Quokka"]
    assert "il 31 dicembre 2026" in text.lower()
    assert "mancano" not in text and "domani" not in text


def test_timing_rules() -> None:
    end = datetime(2026, 12, 31, 10, 17, tzinfo=UTC)
    on = lambda days: end - timedelta(days=days)  # noqa: E731
    assert timing.template_for_moment("D3", on(1), end) == "D3"
    assert timing.template_for_moment("D3", on(2), end) == "D_LATE"
    assert timing.template_for_moment("D3", on(0), end) == "D_LATE"  # any day, even later
    assert timing.template_for_moment("D3", on(-3), end) == "D_LATE"
    assert timing.template_for_moment("D2", on(7), end) == "D2"
    assert timing.template_for_moment("D2", on(8), end) == "D_LATE"
    assert timing.template_for_moment("D2", on(6), end) == "D_LATE"
    assert timing.template_for_moment("D2", on(0), end) == "D_LATE"
    assert timing.template_for_moment("D1", on(30), end) == "D1"  # no relative words


def test_the_erasure_day_is_the_day_the_job_really_runs() -> None:
    assert timing.job_run_after(datetime(2026, 12, 31, 10, 0, tzinfo=UTC)) == datetime(
        2026, 12, 31, 10, 17, tzinfo=UTC
    )
    assert timing.job_run_after(datetime(2026, 12, 31, 10, 17, tzinfo=UTC)) == datetime(
        2026, 12, 31, 10, 17, tzinfo=UTC
    )
    # Just before midnight the first run after the date is the day after.
    assert timing.job_run_after(datetime(2026, 12, 31, 23, 30, tzinfo=UTC)) == datetime(
        2027, 1, 1, 0, 17, tzinfo=UTC
    )


def test_a_request_just_before_midnight_states_the_day_the_erase_really_runs() -> None:
    requested = datetime(2026, 12, 1, 23, 40, tzinfo=UTC)
    world = World()
    world.request(OWNER_A, at=requested)  # the date is 31 December, 23:40
    purge_after = requested + timedelta(days=30)

    # D2 is due from 24 December 23:40, but the real erasure day is 1 January: 8 days away.
    world.deletion.send_notices(purge_after - timedelta(days=7))
    assert world.subjects() == ["Cancelliamo il tuo account Quokka"]
    assert "il 1 gennaio 2027" in world.sender.sent[0].text.lower()

    # D3: from 30 December 23:40, a day before the 31st but two before the real day.
    other = World()
    other.request(OWNER_A, at=requested)
    other.deletion.send_notices(purge_after - timedelta(days=1))
    assert "il 1 gennaio 2027" in other.sender.sent[0].text.lower()
    assert "domani" not in other.sender.sent[0].text.lower()

    # In the morning of the real day it is the same day: nothing goes out, the erase takes it.
    third = World()
    third.request(OWNER_A, at=requested)
    third.deletion.send_notices(datetime(2027, 1, 1, 0, 5, tzinfo=UTC))
    assert third.sender.sent == []


def test_the_erasure_job_minute_is_the_one_of_the_scheduler_cron() -> None:
    import re
    from pathlib import Path

    workflow = Path(".github/workflows/admin-scheduler.yml").read_text(encoding="utf-8")
    match = re.search(r'cron:\s*"(\d+) \* \* \* \*"', workflow)
    assert match, "the hourly cron of the scheduler was not found"
    assert int(match.group(1)) == timing.JOB_MINUTE


def test_in_italy_the_local_day_of_the_erasure_is_never_before_the_date_in_the_text() -> None:
    """Dates are UTC; Italy is UTC+1 (winter) or UTC+2 (summer), so the local day never
    comes before the day written in the e-mail."""
    start = datetime(2026, 12, 1, 0, 0, tzinfo=UTC)
    for offset_hours in (1, 2):
        for minutes in range(0, 24 * 60, 37):
            purge_after = start + timedelta(minutes=minutes)
            real = timing.job_run_after(purge_after)
            local = real + timedelta(hours=offset_hours)
            assert local.date() >= real.date()


# ---- «Elimina» with the notices required (docs/compliance/18 §8, Normativa 23 November)

DUE = T0 + timedelta(days=30)  # the day the period ends


def _final_registered(world: World, owner: str = OWNER_A) -> None:
    """Run the notices up to and including the final one, the day before the date."""
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    world.runner.run(DUE - timedelta(days=1))
    assert world.deletions.get(owner).last_notice == "tomorrow"  # type: ignore[union-attr]


def _log_reasons(world: World) -> list[str]:
    return [entry.reason for entry in world.log_repository.list_all()]


def test_without_the_notices_required_the_account_is_erased_when_the_period_ends() -> None:
    world = World(enabled=False)
    world.request(OWNER_A)
    report = world.deletion.purge_due(True, DUE + timedelta(minutes=1))
    assert (report.erased, report.waiting, report.alarm) == (1, 0, 0)


def test_with_the_notices_required_and_sending_off_it_holds_until_the_hard_end() -> None:
    world = World(enabled=False, required=True)
    world.request(OWNER_A)

    report = world.deletion.purge_due(True, DUE + timedelta(days=6))

    assert report.erased == 0 and world.erased == []
    assert report.blocked == "sending_off" and report.alarm == 1 and report.waiting == 1
    # Even with nothing due the mistake of the setting is a thing for the team.
    empty = World(enabled=False, required=True).deletion.purge_due(True, DUE)
    assert empty.blocked == "sending_off" and empty.alarm == 1


def test_with_the_sending_off_the_hard_end_erases_with_the_reason_and_the_alarm() -> None:
    world = World(enabled=False, required=True)
    world.request(OWNER_A)

    report = world.deletion.purge_due(True, DUE + notices.MAX_WAIT_AFTER_DUE)

    assert (report.erased, report.forced, report.alarm) == (1, 1, 1)
    assert _log_reasons(world) == ["notice_not_sent"]
    assert report.closing_skipped == 1  # no D4: nothing can be sent
    # With the erasing job off nothing is erased, whatever the age.
    off = World(enabled=False, required=True)
    off.request(OWNER_A)
    assert off.deletion.purge_due(False, DUE + timedelta(days=30)).erased == 0


def test_it_is_erased_only_20_hours_after_the_final_notice_is_registered() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    _final_registered(world)
    booked = world.deletions.get(OWNER_A).last_notice_at  # type: ignore[union-attr]
    assert booked == DUE - timedelta(days=1)

    early = world.deletion.purge_due(True, DUE + timedelta(minutes=1))
    assert (early.erased, early.waiting, early.alarm) == (1, 0, 0)  # 24 hours since: fine

    # A final notice booked less than 20 hours ago holds the erase, quietly (no alarm).
    other = World(required=True)
    other.request(OWNER_A)
    other.runner.run(T0)
    other.runner.run(DUE - timedelta(days=7))
    other.runner.run(DUE - timedelta(hours=2))  # D3 late: booked two hours before the date
    held = other.deletion.purge_due(True, DUE + timedelta(hours=5))
    assert (held.erased, held.waiting, held.alarm) == (0, 1, 0)
    done = other.deletion.purge_due(True, DUE + timedelta(hours=19))
    assert done.erased == 1


def test_a_final_notice_that_failed_for_our_fault_keeps_the_account_and_is_retried() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    world.mailer._sender = _Sender(*[SendResult(sent=False, reason=NOT_SENT)] * 3)  # type: ignore[attr-defined]
    world.runner.run(DUE - timedelta(days=1))  # D3 does not go
    assert world.deletions.get(OWNER_A).last_notice == "week_left"  # type: ignore[union-attr]

    report = world.deletion.purge_due(True, DUE + timedelta(hours=3))
    assert (report.erased, report.waiting, report.alarm, report.forced) == (0, 1, 1, 0)

    # The provider is back: the final notice goes (D_LATE, the true date), then the 20 hours.
    world.mailer._sender = world.sender  # type: ignore[attr-defined]
    at = DUE + timedelta(days=2, hours=3)
    world.runner.run(at)
    # The date in the text is the real one: the first run of the job 20 hours after the sending.
    expected_day = texts.format_date(timing.job_run_after(at + timedelta(hours=20)))
    assert expected_day in world.sender.sent[-1].text
    assert world.deletion.purge_due(True, at + timedelta(hours=19)).erased == 0
    assert world.deletion.purge_due(True, at + timedelta(hours=21)).erased == 1


def test_after_the_wait_the_system_erases_by_itself_writes_why_and_raises_the_alarm() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    world.mailer._sender = _Sender(*[SendResult(sent=False, reason=NOT_SENT)] * 50)  # type: ignore[attr-defined]

    before = world.deletion.purge_due(True, DUE + notices.MAX_WAIT_AFTER_DUE - timedelta(hours=1))
    assert (before.erased, before.forced, before.alarm) == (0, 0, 1)

    report = world.deletion.purge_due(True, DUE + notices.MAX_WAIT_AFTER_DUE)

    assert (report.erased, report.forced, report.alarm) == (1, 1, 1)
    assert _log_reasons(world) == ["notice_not_sent"]
    assert report.closing_failed == 1  # D4 was tried all the same, once


def test_whoever_cannot_be_written_to_is_not_waited_for() -> None:
    cases = {
        "no_address": _contact("", email=None),
        "unconfirmed": _contact("a@example.com", email_confirmed=False),
        "language": _contact("a@example.com", language="de"),
    }
    for name, contact in cases.items():
        world = World(required=True)
        world.contacts.register(OWNER_A, contact)
        world.request(OWNER_A)
        report = world.deletion.purge_due(True, DUE + timedelta(minutes=1))
        assert (report.erased, report.waiting, report.alarm) == (1, 0, 0), name
        assert _log_reasons(world) == ["user_period_end"], name


def test_a_permanent_refusal_of_the_address_counts_as_registered() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    world.mailer._sender = _Sender(SendResult(sent=False, reason="rejected"))  # type: ignore[attr-defined]
    world.runner.run(DUE - timedelta(days=1))
    assert world.deletions.get(OWNER_A).last_notice == "tomorrow"  # type: ignore[union-attr]

    assert world.deletion.purge_due(True, DUE + timedelta(minutes=1)).erased == 1


def test_an_uncertain_outcome_counts_as_registered_and_is_never_resent() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    sender = _Sender(SendResult(sent=False, reason=UNCERTAIN))
    world.mailer._sender = sender  # type: ignore[attr-defined]
    world.runner.run(DUE - timedelta(days=1))
    world.runner.run(DUE - timedelta(hours=20))
    assert sender.calls == 1
    assert world.deletion.purge_due(True, DUE + timedelta(minutes=1)).erased == 1


def test_the_screen_shows_the_date_that_moved() -> None:
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=7))
    # In time: the planned date.
    assert world.deletion.status(OWNER_A, DUE - timedelta(days=3)).purge_after == DUE

    # Past the date and the final notice not registered: never in the past, always 20 hours on.
    late = DUE + timedelta(days=2)
    shown = world.deletion.status(OWNER_A, late).purge_after
    assert shown is not None and shown - late >= timedelta(hours=20)

    # Without the notices required nothing moves.
    plain = World()
    plain.request(OWNER_A)
    assert plain.deletion.status(OWNER_A, late).purge_after == DUE


def test_a_request_just_before_midnight_still_waits_for_its_notice() -> None:
    requested = datetime(2026, 12, 1, 23, 40, tzinfo=UTC)
    world = World(required=True)
    world.request(OWNER_A, at=requested)
    due = requested + timedelta(days=30)
    world.runner.run(requested)
    world.runner.run(due - timedelta(days=7))
    world.runner.run(due - timedelta(days=1))
    assert "Cancelliamo il tuo account Quokka" in world.subjects()  # the real day is the next one
    assert world.deletion.purge_due(True, due + timedelta(minutes=1)).erased == 1


def test_a_late_notice_in_the_slot_of_d2_does_not_stand_for_the_final_one() -> None:
    """Only the slot of D3 (D3, or D_LATE in its place) lets the erase go ahead (doc 18 §8)."""
    world = World(required=True)
    world.request(OWNER_A)
    world.runner.run(T0)
    world.runner.run(DUE - timedelta(days=3))  # D2's slot, late: D_LATE goes out in its place
    assert world.subjects()[-1] == "Cancelliamo il tuo account Quokka"
    assert world.deletions.get(OWNER_A).last_notice == "week_left"  # type: ignore[union-attr]

    world.mailer._sender = _Sender(*[SendResult(sent=False, reason=NOT_SENT)] * 5)  # type: ignore[attr-defined]
    report = world.deletion.purge_due(True, DUE + timedelta(hours=30))
    assert (report.erased, report.waiting, report.alarm) == (0, 1, 1)
