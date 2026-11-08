"""The retention dry run: it reports what the job would do and does nothing."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from packages.core.application.ports.owner_contact_lookup import OwnerContact
from packages.core.application.services.account_data_counts import AccountDataCounter
from packages.core.application.services.retention_dry_run import (
    MAX_CONTACT_LOOKUPS,
    SAMPLE_SIZE,
    RetentionDryRunService,
)
from packages.core.domain.consent.models import (
    AccountConsents,
    AccountConsentType,
    ConsentRecord,
)
from packages.core.domain.dog_walk.models import WalkSession
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.retention_notices import AccountDataCounts
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryClinicalEventRepository,
    InMemoryDogWalkRepository,
    InMemoryOwnerContactLookup,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
    InMemorySubscriptionRepository,
)

NOW = datetime(2026, 6, 1, 12, 0, tzinfo=UTC)
CONFIRMED = OwnerContact(email="someone@example.com", email_confirmed=True)
ADULT = OwnerContact(email="adult@example.com", email_confirmed=True, birth_date=date(1990, 5, 20))
MINOR = OwnerContact(email="minor@example.com", email_confirmed=True, birth_date=date(2010, 5, 20))
UNDER_MINIMUM = OwnerContact(
    email="child@example.com", email_confirmed=True, birth_date=date(2018, 5, 20)
)


class _Setup:
    def __init__(self, developers: frozenset[str] = frozenset()) -> None:
        self.subscriptions = InMemorySubscriptionRepository()
        self.contacts = InMemoryOwnerContactLookup()
        self.consents = InMemoryAccountConsentsRepository()
        self.pets = InMemoryPetProfileRepository()
        self.events = InMemoryClinicalEventRepository()
        self.reminders = InMemoryReminderRepository()
        self.walks = InMemoryDogWalkRepository()
        self.developers = developers

    def marketing(self, owner_id: str, granted: bool = True) -> None:
        record = ConsentRecord(granted=granted, version="v1")
        self.consents.save(
            AccountConsents(
                owner_id=owner_id, consents={AccountConsentType.MARKETING_EMAIL: record}
            )
        )

    def data(
        self,
        owner_id: str,
        *,
        animals: int,
        documents: int,
        reminders: int,
        walks: int = 0,
        discarded_walks: int = 0,
    ) -> None:
        """[animals] pets; the documents, reminders and walks hang on the first."""
        self.walks_for(owner_id, walks, discarded_walks)
        for index in range(animals):
            pet = self.pets.save(PetProfile(owner_id=owner_id, name=f"pet{index}", species="dog"))
            if index > 0:
                continue
            for _ in range(documents):
                self.events.save(ClinicalEvent(pet_id=pet.id))
            for _ in range(reminders):
                self.reminders.save(
                    Reminder(owner_id=owner_id, pet_id=pet.id, title="t", due_date=date(2026, 7, 1))
                )

    def walks_for(self, owner_id: str, completed: int, discarded: int = 0) -> None:
        for _ in range(completed):
            self.walks.save(WalkSession(owner_id=owner_id, pet_id="pet-x", status="completed"))
        for _ in range(discarded):
            self.walks.save(WalkSession(owner_id=owner_id, pet_id="pet-x", status="discarded"))

    def lapsed(
        self, owner_id: str, days_ago: int | None, contact: OwnerContact | None = CONFIRMED
    ) -> None:
        """An account whose trial is over; [days_ago] is when day D was
        stamped (None = never stamped, the account was not seen since)."""
        self.subscriptions.save(
            Subscription(owner_id=owner_id, trial_ends_at=NOW - timedelta(days=400))
        )
        if days_ago is not None:
            self.subscriptions.set_access_lost_at(owner_id, NOW - timedelta(days=days_ago))
        if contact is not None:
            self.contacts.register(owner_id, contact)

    def service(self, test_plan: str | None = None) -> RetentionDryRunService:
        return RetentionDryRunService(
            self.subscriptions,
            self.contacts,
            self.developers,
            self.consents,
            AccountDataCounter(self.pets, self.events, self.reminders, self.walks),
            test_plan=test_plan,
        )


def test_an_empty_database_gives_an_empty_report() -> None:
    report = _Setup().service().execute(now=NOW)

    assert report.dry_run is True
    assert report.clock_running is True
    assert report.accounts_without_plan == 0
    assert all(count == 0 for count in report.notices_due.values())


def test_it_counts_trials_and_accounts_whose_clock_has_not_started() -> None:
    setup = _Setup()
    setup.subscriptions.save(
        Subscription(owner_id="in-trial", trial_ends_at=NOW + timedelta(days=3))
    )
    setup.subscriptions.save(Subscription(owner_id="plan", plan="pro"))
    setup.lapsed("never-seen", None)

    report = setup.service().execute(now=NOW)

    assert report.accounts_without_plan == 2  # the plan holder is not listed
    assert report.trial_running == 1
    assert report.access_lost == 1
    assert report.clock_not_started == 1
    assert report.clock_started == 0


def test_it_lists_the_notice_each_account_would_get() -> None:
    setup = _Setup()
    setup.lapsed("a", 0)
    setup.lapsed("b", 31)
    setup.lapsed("c", 62)
    setup.lapsed("d", 100)  # switched on late: only the latest due notice (90)
    setup.lapsed("e", 119)

    report = setup.service().execute(now=NOW)

    assert report.clock_started == 5
    assert report.notices_due["0"] == 1
    assert report.notices_due["30"] == 1
    assert report.notices_due["60"] == 1
    assert report.notices_due["90"] == 1
    assert report.notices_due["119"] == 1
    assert report.notices_due["106"] == 0


def test_nobody_is_erasable_because_no_notice_is_recorded_yet() -> None:
    setup = _Setup()
    setup.lapsed("old", 300)

    report = setup.service().execute(now=NOW)

    assert report.past_retention == 1
    assert report.erasable_now == 0


def test_it_counts_unreachable_and_unverified_addresses() -> None:
    setup = _Setup()
    setup.lapsed("ok", 10)
    setup.lapsed("unverified", 10, OwnerContact(email="x@example.com", email_confirmed=False))
    setup.lapsed("no-email", 10, OwnerContact(email=None, email_confirmed=False))
    setup.lapsed("gone", 10, contact=None)

    report = setup.service().execute(now=NOW)

    assert report.clock_started == 4
    assert report.without_reachable_address == 2
    assert report.unverified_address == 1


def test_developers_are_left_out_whatever_the_case_of_their_address() -> None:
    setup = _Setup(developers=frozenset({"dev@example.com"}))
    setup.lapsed("dev", 10, OwnerContact(email="Dev@Example.com", email_confirmed=True))
    setup.lapsed("other", 10)

    report = setup.service().execute(now=NOW)

    assert report.developers_excluded == 1
    assert report.clock_started == 1


def test_during_the_public_test_it_does_nothing() -> None:
    setup = _Setup()
    setup.lapsed("a", 200)

    report = setup.service(test_plan="pro").execute(now=NOW)

    assert report.clock_running is False
    assert report.accounts_without_plan == 0
    assert report.notices_due["0"] == 0
    assert report.sample == []


def test_it_changes_nothing() -> None:
    setup = _Setup()
    setup.lapsed("a", 119)
    setup.lapsed("b", 130)
    before = {owner: setup.subscriptions.get(owner) for owner in ("a", "b")}

    setup.service().execute(now=NOW)
    setup.service().execute(now=NOW)

    assert {owner: setup.subscriptions.get(owner) for owner in ("a", "b")} == before


def test_the_report_holds_no_personal_data() -> None:
    setup = _Setup()
    setup.lapsed(
        "owner-uuid-1234", 10, OwnerContact(email="mario.rossi@example.com", email_confirmed=True)
    )

    dumped = setup.service().execute(now=NOW).model_dump_json()

    assert "mario" not in dumped
    assert "example.com" not in dumped
    assert "owner-uuid-1234" not in dumped


def test_the_sample_is_bounded_and_the_lookups_too() -> None:
    setup = _Setup()
    total = MAX_CONTACT_LOOKUPS + 5
    for index in range(total):
        setup.lapsed(f"owner-{index}", 10)

    report = setup.service().execute(now=NOW)

    assert report.clock_started == MAX_CONTACT_LOOKUPS
    assert report.lookups_skipped == 5
    assert len(report.sample) == SAMPLE_SIZE


# --- which e-mail each account would get -------------------------------------


def test_everybody_gets_the_service_notice_without_a_consent_and_a_declared_adult() -> None:
    setup = _Setup()
    setup.lapsed("no-consent", 10, ADULT)
    setup.lapsed("consent-age-unknown", 10, CONFIRMED)
    setup.marketing("consent-age-unknown")
    setup.lapsed("consent-withdrawn", 10, ADULT)
    setup.marketing("consent-withdrawn", granted=False)

    report = setup.service().execute(now=NOW)

    assert report.service_notices == 3
    assert report.commercial_notices == 0
    assert report.with_marketing_consent == 1
    # Consent given, age not declared: blocked, and the report says so.
    assert report.commercial_blocked_by_age == 1


def test_the_commercial_notice_needs_both_a_consent_and_a_declared_adult() -> None:
    setup = _Setup()
    setup.lapsed("adult", 10, ADULT)
    setup.marketing("adult")
    setup.data("adult", animals=2, documents=3, reminders=1)

    report = setup.service().execute(now=NOW)

    assert report.commercial_notices == 1
    assert report.service_notices == 0
    assert report.age_adult == 1
    assert report.sample[0].variant == "commercial"


def test_a_declared_minor_never_gets_the_commercial_notice_and_gets_the_note() -> None:
    setup = _Setup()
    setup.lapsed("minor", 10, MINOR)
    setup.marketing("minor")

    report = setup.service().execute(now=NOW)

    assert report.commercial_notices == 0
    assert report.age_minor == 1
    assert report.commercial_blocked_by_age == 1
    assert report.sample[0].variant == "service"
    assert report.sample[0].minor_note is True


def test_an_account_under_14_is_counted_apart_and_gets_no_notice() -> None:
    """Closed account with its own 30-day procedure (owner decision relayed by
    the Orchestrator, 2026-11-09): outside this sequence altogether."""
    setup = _Setup()
    setup.lapsed("child", 125, UNDER_MINIMUM)  # even past the 120 days
    setup.marketing("child")

    report = setup.service().execute(now=NOW)

    assert report.age_under_minimum == 1
    assert report.accounts_without_plan == 1
    assert report.clock_started == 0
    assert report.service_notices == 0
    assert report.commercial_notices == 0
    assert all(count == 0 for count in report.notices_due.values())
    assert report.past_retention == 0
    assert report.erasable_now == 0
    assert report.without_reachable_address == 0
    assert report.age_adult == report.age_minor == report.age_unknown == 0
    assert report.sample == []


def test_an_under_14_account_does_not_hide_the_others() -> None:
    setup = _Setup()
    setup.lapsed("child", 10, UNDER_MINIMUM)
    setup.lapsed("adult", 10, ADULT)
    setup.lapsed("teen", 10, MINOR)

    report = setup.service().execute(now=NOW)

    assert report.age_under_minimum == 1
    assert report.clock_started == 2
    assert report.service_notices == 2
    assert len(report.sample) == 2


def test_an_account_whose_age_is_not_known_gets_no_note_and_no_commercial_notice() -> None:
    setup = _Setup()
    setup.lapsed("unknown", 10, CONFIRMED)

    report = setup.service().execute(now=NOW)

    assert report.age_unknown == 1
    assert report.sample[0].variant == "service"
    assert report.sample[0].minor_note is False


def test_the_commercial_text_quotes_only_what_the_account_really_holds() -> None:
    setup = _Setup()
    # Day 30 (E2): the text quotes reminders and records as counts.
    setup.lapsed("rich", 31, ADULT)
    setup.marketing("rich")
    setup.data("rich", animals=2, documents=3, reminders=4, walks=1)
    setup.lapsed("only-pets", 31, ADULT)
    setup.marketing("only-pets")
    setup.data("only-pets", animals=1, documents=0, reminders=0)

    report = setup.service().execute(now=NOW)

    by_contents = {tuple(item.contents): item for item in report.sample}
    rich = by_contents[("animals", "reminders", "documents", "walks")]
    assert rich.counts_cited == ["reminders", "documents"]
    only_pets = by_contents[("animals",)]
    assert only_pets.counts_cited == []
    assert report.downgraded_nothing_to_cite == 0


def test_walks_are_counted_and_a_discarded_walk_is_not() -> None:
    setup = _Setup()
    setup.lapsed("walker", 10, ADULT)
    setup.marketing("walker")
    # No animals, no records, no reminders: only walks are left to quote.
    setup.data("walker", animals=0, documents=0, reminders=0, walks=2, discarded_walks=3)

    report = setup.service().execute(now=NOW)

    assert report.commercial_notices == 1
    assert report.sample[0].contents == ["walks"]


def test_only_discarded_walks_leave_nothing_to_quote() -> None:
    setup = _Setup()
    setup.lapsed("walker", 10, ADULT)
    setup.marketing("walker")
    setup.data("walker", animals=0, documents=0, reminders=0, walks=0, discarded_walks=2)

    report = setup.service().execute(now=NOW)

    assert report.commercial_notices == 0
    assert report.service_notices == 1
    assert report.downgraded_nothing_to_cite == 1


def test_an_account_with_nothing_true_to_quote_gets_the_service_notice() -> None:
    """Rule 9: consent and adult age, but nothing in the account to say."""
    setup = _Setup()
    setup.lapsed("empty", 10, ADULT)
    setup.marketing("empty")

    report = setup.service().execute(now=NOW)

    assert report.commercial_notices == 0
    assert report.service_notices == 1
    assert report.downgraded_nothing_to_cite == 1
    assert report.sample[0].variant == "service"
    assert report.sample[0].contents == []


class _BrokenReminders(InMemoryReminderRepository):
    def list_by_owner(self, owner_id: str) -> list[Reminder]:
        raise RuntimeError("database down")


class _BrokenWalks(InMemoryDogWalkRepository):
    def list_by_owner(self, owner_id: str) -> list[WalkSession]:
        raise RuntimeError("database down")


def _with_broken(setup: _Setup, counter: AccountDataCounter) -> RetentionDryRunService:
    return RetentionDryRunService(
        setup.subscriptions, setup.contacts, setup.developers, setup.consents, counter
    )


def test_unreadable_counts_are_unknown_never_zero_or_guessed() -> None:
    setup = _Setup()
    setup.lapsed("adult", 10, ADULT)
    setup.marketing("adult")
    setup.data("adult", animals=1, documents=1, reminders=1, walks=1)

    for counter in (
        AccountDataCounter(setup.pets, setup.events, _BrokenReminders(), setup.walks),
        AccountDataCounter(setup.pets, setup.events, setup.reminders, _BrokenWalks()),
    ):
        report = _with_broken(setup, counter).execute(now=NOW)

        assert report.counts_unavailable == 1
        assert report.downgraded_nothing_to_cite == 1
        assert report.service_notices == 1
        assert report.sample[0].contents == []


class _CountingCounter(AccountDataCounter):
    calls = 0

    def count(self, owner_id: str) -> AccountDataCounts | None:
        _CountingCounter.calls += 1
        return super().count(owner_id)


def test_counts_are_read_only_for_accounts_that_get_the_commercial_notice() -> None:
    setup = _Setup()
    setup.lapsed("service-only", 10, ADULT)
    setup.data("service-only", animals=1, documents=1, reminders=1)
    _CountingCounter.calls = 0
    service = RetentionDryRunService(
        setup.subscriptions,
        setup.contacts,
        setup.developers,
        setup.consents,
        _CountingCounter(setup.pets, setup.events, setup.reminders, setup.walks),
    )

    service.execute(now=NOW)

    assert _CountingCounter.calls == 0


def test_the_sequence_stops_as_soon_as_the_account_chooses_a_plan() -> None:
    setup = _Setup()
    setup.lapsed("subscribed", 50, ADULT)
    setup.marketing("subscribed")
    assert setup.service().execute(now=NOW).clock_started == 1

    stored = setup.subscriptions.get("subscribed")
    assert stored is not None
    # Even with day D still stamped (the status was not read since).
    setup.subscriptions.save(stored.model_copy(update={"plan": "plus"}))

    report = setup.service().execute(now=NOW)

    assert report.accounts_without_plan == 0
    assert report.clock_started == 0
    assert all(count == 0 for count in report.notices_due.values())


def test_downloading_the_data_does_not_stop_the_sequence() -> None:
    """Owner decision of 2026-11-08: only subscribing stops the clock. The
    export leaves no trace on the subscription, so nothing can stop it."""
    setup = _Setup()
    setup.lapsed("exported", 10, ADULT)

    assert setup.service().execute(now=NOW).clock_started == 1


def test_the_report_quotes_no_name_no_number_and_no_birth_date() -> None:
    setup = _Setup()
    setup.lapsed("owner-uuid-9", 10, ADULT)
    setup.marketing("owner-uuid-9")
    setup.data("owner-uuid-9", animals=3, documents=7, reminders=5)

    dumped = setup.service().execute(now=NOW).model_dump_json()

    assert "pet0" not in dumped
    assert "1990" not in dumped
    assert "adult@example.com" not in dumped
    for number in ('"animals":3', '"documents":7', '"reminders":5'):
        assert number not in dumped
