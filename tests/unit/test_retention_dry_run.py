"""The retention dry run: it reports what the job would do and does nothing."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from packages.core.application.ports.owner_contact_lookup import OwnerContact
from packages.core.application.services.retention_dry_run import (
    MAX_CONTACT_LOOKUPS,
    SAMPLE_SIZE,
    RetentionDryRunService,
)
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryOwnerContactLookup,
    InMemorySubscriptionRepository,
)

NOW = datetime(2026, 6, 1, 12, 0, tzinfo=UTC)
CONFIRMED = OwnerContact(email="someone@example.com", email_confirmed=True)


class _Setup:
    def __init__(self, developers: frozenset[str] = frozenset()) -> None:
        self.subscriptions = InMemorySubscriptionRepository()
        self.contacts = InMemoryOwnerContactLookup()
        self.developers = developers

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
            self.subscriptions, self.contacts, self.developers, test_plan=test_plan
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
