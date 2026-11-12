"""Data retention (owner decision 2026-11-08): the calendar, and the day-D clock
kept by the subscription status. Nothing here sends or erases anything."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionOutput,
    GetOrCreateSubscriptionService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.retention import (
    NOTICE_DAYS,
    RETENTION_DAYS,
    data_kept_until,
    days_since_loss,
    due_notice_day,
    erasure_allowed,
    past_retention,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)

D = datetime(2026, 1, 10, 9, 0, tzinfo=UTC)


def _later(days: float) -> datetime:
    return D + timedelta(days=days)


# --- the calendar -----------------------------------------------------------


def test_the_calendar_is_the_one_the_owner_decided() -> None:
    assert RETENTION_DAYS == 120
    assert NOTICE_DAYS == (0, 30, 60, 90, 106, 113, 117, 119)
    # 14, 7, 3 and 1 days before the erasure.
    assert [RETENTION_DAYS - day for day in NOTICE_DAYS[-4:]] == [14, 7, 3, 1]


def test_the_data_is_kept_until_day_d_plus_120() -> None:
    assert data_kept_until(D) == D + timedelta(days=120)


@pytest.mark.parametrize("day", NOTICE_DAYS)
def test_each_notice_is_due_on_its_day_and_not_the_day_before(day: int) -> None:
    assert due_notice_day(D, _later(day), last_notice_day=None) == day
    index = NOTICE_DAYS.index(day)
    if index > 0:
        # The day before, the previous notice (already sent) is the latest one.
        previous = NOTICE_DAYS[index - 1]
        assert due_notice_day(D, _later(day - 1), last_notice_day=previous) is None


def test_a_notice_already_sent_is_not_due_again() -> None:
    assert due_notice_day(D, _later(30), last_notice_day=30) is None
    assert due_notice_day(D, _later(45), last_notice_day=30) is None


def test_a_job_that_was_off_sends_one_notice_not_a_burst() -> None:
    # Switched on at day 100 with nothing ever sent: only the latest due notice.
    assert due_notice_day(D, _later(100), last_notice_day=None) == 90
    # Switched on at day 119 with nothing sent: just the "tomorrow" one.
    assert due_notice_day(D, _later(119.5), last_notice_day=None) == 119


def test_days_never_go_negative() -> None:
    assert days_since_loss(D, D - timedelta(days=3)) == 0


def test_retention_is_over_exactly_at_120_days() -> None:
    assert not past_retention(D, _later(119.99))
    assert past_retention(D, _later(120))


def test_erasure_needs_the_tomorrow_notice_sent_at_least_20_hours_ago() -> None:
    now = _later(120)
    long_ago = now - timedelta(hours=21)
    assert erasure_allowed(D, now, last_notice_day=119, last_notice_at=long_ago)
    # Warned too recently (the job was switched on late): wait.
    assert not erasure_allowed(D, now, last_notice_day=119, last_notice_at=now - timedelta(hours=2))
    # Never warned: never erased, whatever its age.
    assert not erasure_allowed(D, _later(400), last_notice_day=None, last_notice_at=None)
    # An earlier notice is not the "tomorrow" one.
    assert not erasure_allowed(D, now, last_notice_day=117, last_notice_at=long_ago)
    # Before the 120 days nothing is erased even if everything was sent.
    assert not erasure_allowed(D, _later(119.9), last_notice_day=119, last_notice_at=_later(118.5))


# --- the clock kept by the subscription status ------------------------------


def _service(
    repository: InMemorySubscriptionRepository,
    *,
    developers: frozenset[str] = frozenset(),
    test_plan: str | None = None,
) -> GetOrCreateSubscriptionService:
    return GetOrCreateSubscriptionService(repository, developers, test_plan=test_plan)


def _status(
    service: GetOrCreateSubscriptionService, email: str = "owner@example.com"
) -> GetOrCreateSubscriptionOutput:
    return service.execute(GetOrCreateSubscriptionInput(owner_id="owner-a", email=email))


def _expired(repository: InMemorySubscriptionRepository) -> None:
    repository.save(Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=1)))


def test_an_account_with_access_has_no_clock_and_no_date() -> None:
    repository = InMemorySubscriptionRepository()
    out = _status(_service(repository))

    assert out.has_access is True
    assert out.data_kept_until is None
    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is None


def test_the_clock_starts_the_first_time_an_expired_account_is_seen() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)
    before = utc_now()

    out = _status(_service(repository))

    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is not None
    assert stored.access_lost_at >= before
    assert out.has_access is False
    assert out.data_kept_until == stored.access_lost_at + timedelta(days=120)


def test_the_clock_is_not_restarted_by_later_visits() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)
    service = _service(repository)
    _status(service)
    first = repository.get("owner-a")
    assert first is not None

    _status(service)
    _status(service)

    again = repository.get("owner-a")
    assert again is not None and again.access_lost_at == first.access_lost_at


def test_the_clock_is_never_taken_from_the_trial_end_date() -> None:
    """A trial that ended months ago must not start with 120 days already gone
    (the end of a public test would otherwise find accounts due for erasure)."""
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=200)))

    out = _status(_service(repository))

    assert out.data_kept_until is not None
    assert out.data_kept_until > utc_now() + timedelta(days=119)


def test_choosing_a_plan_stops_the_clock() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)
    service = _service(repository)
    _status(service)

    stored = repository.get("owner-a")
    assert stored is not None
    repository.save(stored.model_copy(update={"plan": "plus"}))
    out = _status(service)

    after = repository.get("owner-a")
    assert after is not None and after.access_lost_at is None
    assert out.has_access is True
    assert out.data_kept_until is None


def test_a_developer_never_has_a_clock_even_with_an_old_stamp() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)
    repository.set_access_lost_at("owner-a", utc_now() - timedelta(days=5))

    out = _status(
        _service(repository, developers=frozenset({"dev@example.com"})), "Dev@Example.com"
    )

    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is None
    assert out.has_access is True
    assert out.data_kept_until is None


def test_during_the_public_test_the_clock_is_frozen_and_reset() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)

    # Nobody is without access during the test: no stamp is made...
    out = _status(_service(repository, test_plan="pro"))
    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is None
    assert out.test_period is True
    assert out.data_kept_until is None

    # ...and one that was already running is cleared, so the end of the test
    # starts the four months afresh instead of counting the test period.
    repository.set_access_lost_at("owner-a", utc_now() - timedelta(days=100))
    _status(_service(repository, test_plan="pro"))
    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is None

    # When the test ends the account is expired again and D is today.
    out = _status(_service(repository))
    assert out.data_kept_until is not None
    assert out.data_kept_until > utc_now() + timedelta(days=119)


class _FailingClock(InMemorySubscriptionRepository):
    """A database that does not have the column yet."""

    def set_access_lost_at(self, owner_id: str, value: datetime | None) -> None:
        raise RuntimeError("column access_lost_at does not exist")


def test_a_failing_clock_never_changes_what_the_account_may_do() -> None:
    repository = _FailingClock()
    _expired(repository)
    out = _status(_service(repository))
    assert out.has_access is False
    assert out.data_kept_until is None

    fresh = _FailingClock()
    out = _status(_service(fresh))
    assert out.has_access is True


def test_saving_the_subscription_never_touches_the_clock() -> None:
    repository = InMemorySubscriptionRepository()
    _expired(repository)
    _status(_service(repository))
    stored = repository.get("owner-a")
    assert stored is not None and stored.access_lost_at is not None

    repository.save(Subscription(owner_id="owner-a", trial_ends_at=utc_now() - timedelta(days=1)))

    again = repository.get("owner-a")
    assert again is not None and again.access_lost_at == stored.access_lost_at
