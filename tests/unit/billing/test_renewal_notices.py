"""The e-mail seven days before a yearly plan renews (owner decision of 25 November 2026).

Sending is OFF by default; these tests switch it on only on in-memory doubles. Every address is
example.com, every amount and name is invented."""

from __future__ import annotations

import json
import logging
import re
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any
from unittest.mock import MagicMock

import pytest

from packages.core.application.ports.email_sender import (
    NOT_SENT,
    REJECTED,
    UNCERTAIN,
    EmailMessage,
    SendResult,
)
from packages.core.application.ports.owner_contact_lookup import OwnerContact
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.exit_notices import ExitNoticeService
from packages.core.application.services.notice_mailer import (
    NoticeConfig,
    NoticeMailer,
    SendBudget,
)
from packages.core.application.services.renewal_notices import RenewalNoticeService
from packages.core.application.services.store_billing import StoreBillingService
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.core.domain.exit_notices.sender_lines import SIGNATURES, SMALL_LINES
from packages.core.domain.localization import SUPPORTED_LOCALES, SupportedLocale
from packages.core.domain.subscription import renewal_notice
from packages.core.domain.subscription.renewal_texts import BODIES, SUBJECTS
from packages.core.domain.subscription.store import (
    BillingPeriod,
    ProductCatalog,
    Store,
    StoreEntitlement,
    StorePrice,
    StoreState,
    VerifiedStorePurchase,
)
from packages.infrastructure.billing.fake_store import FakeStore
from packages.infrastructure.email.in_memory_email_sender import InMemoryEmailSender
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.infrastructure.persistence.in_memory_renewal_notice_log import (
    InMemoryRenewalNoticeLog,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryOwnerContactLookup,
    InMemorySubscriptionRepository,
)
from packages.infrastructure.persistence.in_memory_store_billing import (
    InMemoryStoreEntitlementRepository,
)
from packages.infrastructure.persistence.supabase.supabase_renewal_notice_log import (
    SupabaseRenewalNoticeLog,
)

REVIEWED: dict[str, dict[str, str]] = json.loads(
    (Path(__file__).parents[2] / "fixtures" / "billing_texts_2026_11_25.json").read_text(
        encoding="utf-8"
    )
)
LANGUAGES: list[SupportedLocale] = ["it", "en", "es", "de", "fr"]

OWNER_A = "11111111-1111-4111-8111-111111111111"
OWNER_B = "22222222-2222-4222-8222-222222222222"
NOW = datetime(2026, 12, 1, 10, 17, tzinfo=UTC)
RENEWS = datetime(2026, 12, 8, 21, 30, tzinfo=UTC)
PRICE = StorePrice(micros=85_990_000, currency="EUR")

CONFIG = NoticeConfig(
    login_url="https://app.example.com/accedi", privacy_url="https://example.com/privacy"
)
COMPANY = NoticeConfig(
    legal_entity="Esempio S.r.l.",
    contact="assistenza@example.com",
    login_url="https://app.example.com/accedi",
    privacy_url="https://example.com/privacy",
)


def _contact(address: str, **kwargs: object) -> OwnerContact:
    values: dict[str, object] = {
        "email": address,
        "email_confirmed": True,
        "birth_date": date(1990, 5, 20),
        "display_name": "Anna Verdi",
        "language": "it",
    }
    values.update(kwargs)
    return OwnerContact(**values)  # type: ignore[arg-type]


class World:
    def __init__(self, *, enabled: bool = True, config: NoticeConfig = CONFIG) -> None:
        self.entitlements = InMemoryStoreEntitlementRepository()
        self.google = FakeStore()
        self.apple = FakeStore()
        self.billing = StoreBillingService(
            entitlements=self.entitlements,
            subscriptions=InMemorySubscriptionRepository(),
            verifiers={Store.GOOGLE: self.google, Store.APPLE: self.apple},
            catalog=ProductCatalog(),
            account_token_secret="test-secret-not-real",
        )
        self.sender = InMemoryEmailSender()
        self.contacts = InMemoryOwnerContactLookup()
        self.contacts.register(OWNER_A, _contact("a@example.com"))
        self.contacts.register(OWNER_B, _contact("b@example.com", display_name="Bruno Neri"))
        self.mailer = NoticeMailer(self.sender, self.contacts, config, enabled)
        self.log = InMemoryRenewalNoticeLog(self.entitlements)
        self.not_allowed: set[str] = set()
        self.service = RenewalNoticeService(
            self.billing,
            self.entitlements,
            self.log,
            self.mailer,
            paid_plan_allowed=lambda owner: owner not in self.not_allowed,
        )

    def subscribe(
        self,
        owner: str = OWNER_A,
        store_id: str = "sub-a",
        *,
        store: Store = Store.GOOGLE,
        period: BillingPeriod = BillingPeriod.YEARLY,
        state: StoreState = StoreState.ACTIVE,
        auto_renew: bool = True,
        expires_at: datetime | None = RENEWS,
        price: StorePrice | None = PRICE,
        store_answer: dict[str, object] | None = None,
    ) -> StoreEntitlement:
        """One subscription bound to [owner], and what the store answers about it."""
        product = "net.quokkapet.pro" if store == Store.APPLE else "quokka_pro"
        product_id = f"{product}.{period}" if store == Store.APPLE else product
        entitlement = self.entitlements.save(
            StoreEntitlement(
                owner_id=owner,
                store=store,
                store_subscription_id=store_id,
                product_id=product_id,
                plan="pro",
                period=period,
                state=state,
                expires_at=expires_at,
                auto_renew=auto_renew,
            )
        )
        answer: dict[str, object] = {
            "store": store,
            "store_subscription_id": store_id,
            "product_id": product_id,
            "base_plan_id": str(period) if store == Store.GOOGLE else None,
            "state": state,
            "expires_at": expires_at,
            "auto_renew": auto_renew,
            "renewal_price": price,
        }
        answer.update(store_answer or {})
        fake = self.apple if store == Store.APPLE else self.google
        fake.answers[store_id] = VerifiedStorePurchase(**answer)  # type: ignore[arg-type]
        return entitlement


# --------------------------------------------------------------------- the texts


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_texts_are_the_reviewed_ones_word_for_word(language: SupportedLocale) -> None:
    assert SUBJECTS[language] == REVIEWED["renewalEmailSubject"][language]
    assert BODIES[language] == REVIEWED["renewalEmailBody"][language]
    assert SIGNATURES[language] == REVIEWED["emailSignature"][language]
    assert SMALL_LINES[language] == REVIEWED["emailSmallLine"][language]


def test_the_texts_exist_in_every_language_of_the_app() -> None:
    for table in (SUBJECTS, BODIES, SIGNATURES, SMALL_LINES):
        assert set(table) == SUPPORTED_LOCALES == set(LANGUAGES)


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_message_is_the_reviewed_body_filled_in_and_nothing_else(
    language: SupportedLocale,
) -> None:
    subject, paragraphs = renewal_notice.compose(
        language, first_name="Anna Verdi", renews_on=RENEWS, price=PRICE, store=Store.GOOGLE
    )
    expected = (
        REVIEWED["renewalEmailBody"][language]
        .removesuffix(" {titolare}, {contatto}.")
        .format(
            nome="Anna",
            data_rinnovo=renewal_notice.format_date(RENEWS, language),
            store="Google",
            prezzo=renewal_notice.format_price(PRICE, language),
        )
    )
    assert subject == REVIEWED["renewalEmailSubject"][language]
    # The greeting has its own line, so the next word takes a capital: compare without case.
    assert " ".join(paragraphs).lower() == expected.lower()
    assert paragraphs[0].endswith("Anna,") and len(paragraphs) == 3
    assert all(p[0].isupper() for p in paragraphs)
    assert "{" not in "".join(paragraphs)


@pytest.mark.parametrize("language", LANGUAGES)
def test_with_no_name_the_greeting_has_no_hole(language: SupportedLocale) -> None:
    _, paragraphs = renewal_notice.compose(
        language, first_name="  ", renews_on=RENEWS, price=PRICE, store=Store.APPLE
    )
    assert re.fullmatch(r"(Ciao|Hi|Hola|Hallo|Bonjour),", paragraphs[0])
    assert "Apple" in " ".join(paragraphs)


def test_a_name_with_braces_or_markup_stays_harmless() -> None:
    _, paragraphs = renewal_notice.compose(
        "it", first_name="{prezzo}<b>", renews_on=RENEWS, price=PRICE, store=Store.APPLE
    )
    assert paragraphs[0] == "Ciao prezzob,"


@pytest.mark.parametrize(
    ("language", "expected"),
    [
        ("it", "8 dicembre 2026"),
        ("en", "8 December 2026"),
        ("es", "8 de diciembre de 2026"),
        ("de", "8. Dezember 2026"),
        ("fr", "8 décembre 2026"),
    ],
)
def test_the_date_is_written_as_in_the_language(language: SupportedLocale, expected: str) -> None:
    assert renewal_notice.format_date(RENEWS, language) == expected


def test_the_first_of_the_month_in_french() -> None:
    assert renewal_notice.format_date(datetime(2027, 3, 1, tzinfo=UTC), "fr") == "1er mars 2027"


@pytest.mark.parametrize(
    ("micros", "currency", "language", "expected"),
    [
        (85_990_000, "EUR", "it", "85,99 €"),
        (85_990_000, "EUR", "en", "€85.99"),
        (85_990_000, "EUR", "de", "85,99 €"),
        (90_000_000, "EUR", "fr", "90,00 €"),
        (85_500_000, "USD", "en", "$85.50"),
        (85_500_000, "USD", "it", "85,50 USD"),
        (74_990_000, "GBP", "es", "74,99 £"),
        (139_990_000, "AUD", "en", "A$139.99"),
        (95_000_000, "CHF", "de", "95,00 CHF"),
        (95_000_000, "CHF", "en", "CHF 95.00"),
        (12_500_000_000, "JPY", "en", "JPY 12,500"),
        (1_234_560_000, "EUR", "it", "1.234,56 €"),
    ],
)
def test_the_amount_is_the_store_s_never_rounded(
    micros: int, currency: str, language: SupportedLocale, expected: str
) -> None:
    price = StorePrice(micros=micros, currency=currency)
    assert renewal_notice.format_price(price, language) == expected


def test_nothing_is_sold_and_there_is_no_link_or_button() -> None:
    world = World()
    world.subscribe()
    world.service.send_notices(NOW)
    message = world.sender.sent[0]
    assert message.category == "service" and message.unsubscribe_url is None
    assert message.html is not None
    assert "<a " not in message.html and "http" not in message.text
    assert "http" not in re.sub(r"<style>.*?</style>", "", message.html, flags=re.DOTALL)


# --------------------------------------------------------------------- who gets it


def test_it_goes_once_seven_days_before_and_never_twice() -> None:
    world = World()
    world.subscribe()
    first = world.service.send_notices(NOW)
    assert (first.due, first.sent) == (1, 1)
    # The same day again, hour after hour, and every day until the renewal.
    for hours in range(1, 24 * 8):
        again = world.service.send_notices(NOW + timedelta(hours=hours))
        assert again.sent == 0 and again.due == 0
    assert len(world.sender.sent) == 1
    message = world.sender.sent[0]
    assert message.to == "a@example.com"
    assert message.subject == "Il tuo piano annuale Quokka si rinnova tra 7 giorni"
    assert message.text.startswith("Ciao Anna,\n\nIl 8 dicembre 2026 il tuo piano annuale")
    assert "Google addebita 85,99 €." in message.text
    assert message.text.rstrip().endswith("Il team di Quokka")


def test_the_next_year_it_goes_again() -> None:
    world = World()
    world.subscribe()
    world.service.send_notices(NOW)
    world.subscribe(expires_at=RENEWS.replace(year=2027))
    assert world.service.send_notices(NOW.replace(year=2027)).sent == 1
    assert len(world.sender.sent) == 2


def test_a_date_the_store_moves_by_a_day_is_still_the_same_renewal() -> None:
    world = World()
    world.subscribe()
    world.service.send_notices(NOW)
    world.subscribe(expires_at=RENEWS + timedelta(days=1))
    assert world.service.send_notices(NOW + timedelta(days=1)).sent == 0
    assert len(world.sender.sent) == 1


@pytest.mark.parametrize("days", [1, 6, 8, 30])
def test_only_on_the_day_that_is_seven_days_before(days: int) -> None:
    """The subject says «in 7 days»: on any other day it would not be true."""
    world = World()
    world.subscribe(expires_at=NOW + timedelta(days=days))
    assert world.service.send_notices(NOW).due == 0
    assert world.sender.sent == []


@pytest.mark.parametrize(
    ("hour", "due"),
    [
        (datetime(2026, 11, 30, 23, 59, tzinfo=UTC), 0),
        (datetime(2026, 12, 1, 0, 0, tzinfo=UTC), 1),
        (datetime(2026, 12, 1, 23, 59, tzinfo=UTC), 1),
        (datetime(2026, 12, 2, 0, 0, tzinfo=UTC), 0),
    ],
)
def test_the_day_is_the_utc_day(hour: datetime, due: int) -> None:
    world = World()
    world.subscribe()
    assert world.service.send_notices(hour).due == due


@pytest.mark.parametrize(
    "case",
    [
        {"period": BillingPeriod.MONTHLY},
        {"auto_renew": False},
        {"auto_renew": False, "state": StoreState.CANCELED},
        {"state": StoreState.CANCELED},
        {"state": StoreState.IN_GRACE_PERIOD},
        {"state": StoreState.BILLING_RETRY},
        {"state": StoreState.ON_HOLD},
        {"state": StoreState.PAUSED},
        {"state": StoreState.PENDING},
        {"state": StoreState.EXPIRED},
        {"state": StoreState.REVOKED},
        {"state": StoreState.REFUNDED},
        {"state": StoreState.REPLACED},
        {"expires_at": None},
    ],
)
def test_never_for_monthly_cancelled_failing_or_ended_subscriptions(case: dict[str, Any]) -> None:
    world = World()
    world.subscribe(**case)
    counts = world.service.send_notices(NOW)
    assert (counts.due, counts.sent) == (0, 0)
    assert world.sender.sent == []


def test_never_for_the_trial_or_a_plan_given_by_the_team() -> None:
    """The trial has no store subscription at all; the team's test grants are not a store."""
    world = World()
    assert world.service.send_notices(NOW).due == 0
    world.entitlements.save(
        StoreEntitlement(
            owner_id=OWNER_A,
            store=Store.ADMIN_TEST,
            store_subscription_id="admin-test",
            product_id="net.quokkapet.pro.yearly",
            plan="pro",
            period=BillingPeriod.YEARLY,
            state=StoreState.ACTIVE,
            expires_at=RENEWS,
            auto_renew=True,
            environment="test",
        )
    )
    assert world.service.send_notices(NOW).due == 0
    assert world.sender.sent == []


@pytest.mark.parametrize(
    "answer",
    [
        {"auto_renew": False, "state": StoreState.CANCELED},
        {"state": StoreState.IN_GRACE_PERIOD},
        {"state": StoreState.EXPIRED},
        {"base_plan_id": "monthly"},
        {"expires_at": RENEWS + timedelta(days=40)},
        {"expires_at": None},
    ],
)
def test_what_the_store_says_now_has_the_last_word(answer: dict[str, object]) -> None:
    """The row of the server may be an hour old: whoever cancelled meanwhile gets nothing."""
    world = World()
    world.subscribe(store_answer=answer)
    counts = world.service.send_notices(NOW)
    assert counts.sent == 0 and counts.skipped_by_reason == {"not_renewing": 1}
    assert world.sender.sent == [] and world.entitlements.events == {}


def test_without_the_store_s_amount_nothing_is_sent_and_nothing_is_booked() -> None:
    world = World()
    world.subscribe(price=None)
    counts = world.service.send_notices(NOW)
    assert counts.skipped_by_reason == {"amount_unknown": 1}
    assert world.sender.sent == [] and world.entitlements.events == {}


def test_a_sandbox_purchase_is_never_written_about() -> None:
    world = World()
    world.subscribe(store_answer={"environment": "sandbox"})
    assert world.service.send_notices(NOW).skipped_by_reason == {"store_rejected": 1}
    assert world.sender.sent == []


def test_a_store_that_does_not_answer_is_asked_again_the_next_hour() -> None:
    world = World()
    world.subscribe()
    world.google.down = True
    counts = world.service.send_notices(NOW)
    assert counts.skipped_by_reason == {"store_unavailable": 1}
    world.google.down = False
    assert world.service.send_notices(NOW + timedelta(hours=1)).sent == 1


def test_a_minor_without_the_parent_s_confirmation_is_not_written_to() -> None:
    world = World()
    world.subscribe()
    world.not_allowed.add(OWNER_A)
    assert world.service.send_notices(NOW).skipped_by_reason == {"paid_plan_not_allowed": 1}
    assert world.sender.sent == []


def test_each_owner_gets_only_the_reminder_of_their_own_plan() -> None:
    """User B: the reminder of A goes to A's address only, with A's amount, and B's to B."""
    world = World()
    world.subscribe(OWNER_A, "sub-a")
    world.subscribe(
        OWNER_B,
        "sub-b",
        price=StorePrice(micros=155_990_000, currency="EUR"),
    )
    assert world.service.send_notices(NOW).sent == 2
    by_address = {message.to: message.text for message in world.sender.sent}
    assert set(by_address) == {"a@example.com", "b@example.com"}
    assert "Ciao Anna," in by_address["a@example.com"]
    assert "85,99" in by_address["a@example.com"] and "155,99" not in by_address["a@example.com"]
    assert "Ciao Bruno," in by_address["b@example.com"]
    assert "155,99" in by_address["b@example.com"]
    owners = {event["owner_id"] for event in world.entitlements.events.values()}
    assert owners == {OWNER_A, OWNER_B}


def test_b_gets_nothing_when_only_a_has_a_plan_and_cannot_release_a_s_booking() -> None:
    world = World()
    entitlement = world.subscribe(OWNER_A)
    world.service.send_notices(NOW)
    assert [message.to for message in world.sender.sent] == ["a@example.com"]
    event_id = renewal_notice.event_id(entitlement)
    world.log.release(Store.GOOGLE, event_id, OWNER_B)
    assert world.log.booked_since(Store.GOOGLE, "sub-a", NOW - timedelta(days=1))


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_language_is_the_account_s(language: SupportedLocale) -> None:
    world = World()
    world.contacts.register(OWNER_A, _contact("a@example.com", language=language))
    world.subscribe(store=Store.APPLE)
    assert world.service.send_notices(NOW).sent == 1
    message = world.sender.sent[0]
    assert message.subject == REVIEWED["renewalEmailSubject"][language]
    assert message.text.rstrip().endswith(REVIEWED["emailSignature"][language])
    assert message.html is not None and f'<html lang="{language}">' in message.html


@pytest.mark.parametrize(("stored", "subject"), [("en-GB", "Your"), ("fr_CH", "Votre")])
def test_a_regional_language_uses_its_language(stored: str, subject: str) -> None:
    world = World()
    world.contacts.register(OWNER_A, _contact("a@example.com", language=stored))
    world.subscribe()
    world.service.send_notices(NOW)
    assert world.sender.sent[0].subject.startswith(subject)


@pytest.mark.parametrize(
    ("contact", "reason"),
    [
        (_contact("a@example.com", language="pt"), "language_not_ready"),
        (_contact("a@example.com", email_confirmed=False), "unconfirmed"),
        (_contact("", email=None), "no_address"),
        (_contact("a@example.com", birth_date=date(2016, 1, 1)), "closed_by_age"),
    ],
)
def test_the_rules_of_the_exit_e_mails_hold_here_too(contact: OwnerContact, reason: str) -> None:
    world = World()
    world.contacts.register(OWNER_A, contact)
    world.subscribe()
    assert world.service.send_notices(NOW).skipped_by_reason == {reason: 1}
    assert world.sender.sent == [] and world.entitlements.events == {}


# --------------------------------------------------------------------- company and contact


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_company_shows_only_once_it_is_configured(language: SupportedLocale) -> None:
    hidden, shown = World(), World(config=COMPANY)
    for world in (hidden, shown):
        world.contacts.register(OWNER_A, _contact("a@example.com", language=language))
        world.subscribe()
        assert world.service.send_notices(NOW).sent == 1
    without, line = hidden.sender.sent[0], shown.sender.sent[0]
    assert without.html is not None and line.html is not None
    for text in (without.text, without.html):
        assert "titolare" not in text and "contatto" not in text and "S.r.l." not in text
    assert 'class="foot"' not in without.html
    expected = REVIEWED["emailSmallLine"][language].format(
        titolare="Esempio S.r.l.", contatto="assistenza@example.com"
    )
    # Once, under the signature: the body keeps no closing of its own (like the exit e-mails).
    assert line.text.rstrip().endswith(expected) and line.text.count("Esempio S.r.l.") == 1
    assert line.html.index(REVIEWED["emailSignature"][language].replace("'", "&#x27;")) < (
        line.html.index('class="foot"')
    )


def test_half_a_company_shows_nothing() -> None:
    world = World(config=NoticeConfig(**{**COMPANY.__dict__, "contact": ""}))
    world.subscribe()
    world.service.send_notices(NOW)
    assert "Esempio" not in world.sender.sent[0].text


# --------------------------------------------------------------------- off by default, failures


def test_with_sending_off_it_only_counts_and_asks_no_store() -> None:
    world = World(enabled=False)
    world.subscribe()
    calls: list[str] = []
    world.google.verify = lambda **kw: calls.append("asked")  # type: ignore[assignment,method-assign]
    counts = world.service.send_notices(NOW)
    assert (counts.due, counts.sent, counts.blocked) == (1, 0, "sending_off")
    assert calls == [] and world.sender.sent == [] and world.entitlements.events == {}


def test_with_the_wording_not_configured_nothing_goes() -> None:
    world = World(config=NoticeConfig())
    world.subscribe()
    assert world.service.send_notices(NOW).blocked == "not_configured"
    assert world.sender.sent == []


class _Answering(InMemoryEmailSender):
    def __init__(self, reason: str) -> None:
        super().__init__()
        self.reason = reason

    def send(self, message: EmailMessage) -> SendResult:
        return SendResult(sent=False, reason=self.reason)


def test_a_message_that_certainly_did_not_go_is_tried_again() -> None:
    world = World()
    world.subscribe()
    world.mailer._sender = _Answering(NOT_SENT)
    counts = world.service.send_notices(NOW)
    assert (counts.sent, counts.failed) == (0, 1) and world.entitlements.events == {}
    world.mailer._sender = world.sender
    assert world.service.send_notices(NOW + timedelta(hours=1)).sent == 1


@pytest.mark.parametrize("reason", [UNCERTAIN, REJECTED])
def test_a_message_that_may_have_gone_or_was_refused_for_good_is_never_sent_again(
    reason: str,
) -> None:
    world = World()
    world.subscribe()
    world.mailer._sender = _Answering(reason)
    world.service.send_notices(NOW)
    world.mailer._sender = world.sender
    assert world.service.send_notices(NOW + timedelta(hours=1)).sent == 0
    assert world.sender.sent == []


def test_two_runs_at_the_same_moment_send_it_once() -> None:
    """Both read «not booked yet», only one books: the other finds the row."""
    world = World()
    entitlement = world.subscribe()
    world.log.booked_since = lambda *a: False  # type: ignore[assignment,method-assign]
    world.entitlements.record_event(
        event_id=renewal_notice.event_id(entitlement),
        store=Store.GOOGLE,
        notification_type=renewal_notice.EVENT_TYPE,
        owner_id=OWNER_A,
        store_subscription_id="sub-a",
        signed_at=NOW,
        outcome="notice_booked",
    )
    counts = world.service.send_notices(NOW)
    assert counts.sent == 0 and counts.skipped_by_reason == {"already_booked": 1}


def test_one_subscription_that_breaks_does_not_stop_the_others() -> None:
    world = World()
    world.subscribe(OWNER_A, "sub-a")
    world.subscribe(OWNER_B, "sub-b")
    verify = world.google.verify

    def broken(*, store_subscription_id: str, product_id: str | None = None) -> Any:
        if store_subscription_id == "sub-a":
            raise RuntimeError("unexpected answer")
        return verify(store_subscription_id=store_subscription_id, product_id=product_id)

    world.google.verify = broken  # type: ignore[assignment,method-assign]
    counts = world.service.send_notices(NOW)
    assert (counts.sent, counts.failed) == (1, 1)
    assert [message.to for message in world.sender.sent] == ["b@example.com"]


def test_the_budget_of_the_run_is_kept() -> None:
    world = World()
    world.subscribe(OWNER_A, "sub-a")
    world.subscribe(OWNER_B, "sub-b")
    counts = world.service.send_notices(NOW, SendBudget(1))
    assert (counts.sent, counts.postponed) == (1, 1)
    assert world.service.send_notices(NOW + timedelta(hours=1), SendBudget(1)).sent == 1


def test_no_personal_data_in_the_logs_or_in_the_counts(caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.DEBUG)
    world = World()
    world.subscribe()
    world.google.down = False
    world.mailer._sender = _Answering(NOT_SENT)
    counts = world.service.send_notices(NOW)
    written = caplog.text + counts.model_dump_json()
    for secret in ("a@example.com", "Anna", OWNER_A, "sub-a", "85", "Quokka"):
        assert secret not in written


# --------------------------------------------------------------------- the run of the scheduler


def _runner(world: World, limit: int = 20) -> tuple[ExitNoticeService, Any]:
    deletions = InMemoryAccountDeletionRepository()
    deletion = AccountDeletionService(
        deletions,
        MagicMock(),
        30,
        mailer=world.mailer,
    )
    return ExitNoticeService(deletion, world.mailer, limit, world.service), deletions


def test_the_scheduler_s_run_sends_the_reminder_after_the_exit_notices() -> None:
    world = World()
    world.subscribe(OWNER_B, "sub-b")
    runner, deletions = _runner(world, limit=1)
    deletions.create(
        AccountDeletionRequest(
            owner_id=OWNER_A,
            requested_at=NOW - timedelta(minutes=5),
            purge_after=NOW + timedelta(days=30),
        )
    )
    report = runner.run(NOW)
    assert (report.deletion.sent, report.renewal.sent, report.renewal.postponed) == (1, 0, 1)
    report = runner.run(NOW + timedelta(hours=1))
    assert (report.deletion.sent, report.renewal.sent, report.alarm) == (0, 1, 0)


def test_a_renewal_read_that_fails_never_stops_the_exit_notices_and_raises_the_alarm() -> None:
    world = World()
    runner, deletions = _runner(world)
    deletions.create(
        AccountDeletionRequest(
            owner_id=OWNER_A,
            requested_at=NOW - timedelta(minutes=5),
            purge_after=NOW + timedelta(days=30),
        )
    )

    def broken(*args: object) -> list[StoreEntitlement]:
        raise RuntimeError("no such table")

    world.log.yearly_renewing_between = broken  # type: ignore[assignment,method-assign]
    report = runner.run(NOW)
    assert report.deletion.sent == 1
    assert report.renewal.blocked == "read_failed" and report.alarm == 1


def test_an_unknown_amount_is_counted_but_does_not_turn_the_job_red() -> None:
    world = World()
    world.subscribe(price=None)
    runner, _ = _runner(world)
    report = runner.run(NOW)
    assert report.renewal.skipped_by_reason == {"amount_unknown": 1} and report.alarm == 0


def test_without_store_billing_the_run_has_no_renewals() -> None:
    world = World()
    runner, _ = _runner(world)
    runner._renewal = None
    report = runner.run(NOW)
    assert report.renewal.due == 0 and report.renewal.blocked is None and report.alarm == 0


# --------------------------------------------------------------------- the database double


class _Query:
    """Records the calls of one PostgREST query and answers with [rows]."""

    def __init__(self, rows: list[dict[str, Any]], calls: list[tuple[str, tuple[Any, ...]]]):
        self._rows = rows
        self._calls = calls

    def __getattr__(self, name: str) -> Any:
        def call(*args: Any, **kwargs: Any) -> Any:
            self._calls.append((name, args))
            return MagicMock(data=self._rows) if name == "execute" else self

        return call


def _database(rows: list[dict[str, Any]]) -> tuple[Any, list[tuple[str, tuple[Any, ...]]]]:
    calls: list[tuple[str, tuple[Any, ...]]] = []
    client = MagicMock()

    def table(name: str) -> _Query:
        calls.append(("table", (name,)))
        return _Query(rows, calls)

    client.table = table
    return client, calls


def test_the_database_is_asked_only_for_yearly_active_rows_of_that_day() -> None:
    row = StoreEntitlement(
        owner_id=OWNER_A,
        store=Store.GOOGLE,
        store_subscription_id="sub-a",
        product_id="quokka_pro",
        plan="pro",
        period=BillingPeriod.YEARLY,
        state=StoreState.ACTIVE,
        expires_at=RENEWS,
        auto_renew=True,
    ).model_dump(mode="json")
    client, calls = _database([row])
    start, end = renewal_notice.renewal_day(NOW)
    found = SupabaseRenewalNoticeLog(client).yearly_renewing_between(start, end)
    assert [e.owner_id for e in found] == [OWNER_A] and renewal_notice.is_due(found[0], NOW)
    assert ("table", ("store_subscriptions",)) in calls
    assert ("eq", ("period", "yearly")) in calls and ("eq", ("state", "active")) in calls
    assert ("gte", ("expires_at", "2026-12-08T00:00:00+00:00")) in calls
    assert ("lt", ("expires_at", "2026-12-09T00:00:00+00:00")) in calls


def test_the_database_booking_is_looked_up_and_given_back_for_its_owner_only() -> None:
    client, calls = _database([{"event_id": "x"}])
    log = SupabaseRenewalNoticeLog(client)
    assert log.booked_since(Store.GOOGLE, "sub-a", NOW) is True
    assert ("eq", ("notification_type", "QUOKKA_RENEWAL_NOTICE")) in calls
    assert ("eq", ("store_subscription_id", "sub-a")) in calls
    calls.clear()
    log.release(Store.GOOGLE, "renewal-notice:abc", OWNER_A)
    assert ("table", ("store_events",)) in calls and ("delete", ()) in calls
    assert ("eq", ("owner_id", OWNER_A)) in calls
    assert ("eq", ("event_id", "renewal-notice:abc")) in calls
    empty, _ = _database([])
    assert SupabaseRenewalNoticeLog(empty).booked_since(Store.GOOGLE, "sub-a", NOW) is False


def test_the_booking_does_not_write_the_store_s_identifier_twice() -> None:
    world = World()
    entitlement = world.subscribe(store_id="a-purchase-token")
    assert "a-purchase-token" not in renewal_notice.event_id(entitlement)
    assert OWNER_A not in renewal_notice.event_id(entitlement)
