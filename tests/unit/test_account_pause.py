"""The pause: clears the 120-day clock in the same operation, ends at the next
sign-in, refuses the session that paused it, hides the ads, and is erased with
the account."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.retention import days_since_loss
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
)
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_account_pause_repository import (
    InMemoryAccountPauseRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)
from packages.shared.errors.base import AgeRestrictedError

OWNER = "11111111-1111-4111-8111-111111111111"
NOW = datetime(2026, 12, 1, 10, 0, tzinfo=UTC)


class FakeInner:
    """An inner provider whose current user signed in at [signed_in_at]."""

    def __init__(self) -> None:
        self.signed_in_at: datetime | None = NOW - timedelta(hours=1)

    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(id=OWNER, email="owner@example.com")

    def last_sign_in_at(self) -> datetime | None:
        return self.signed_in_at


class FakeSubscriptions:
    def __init__(self) -> None:
        self.calls: list[tuple[str, datetime | None]] = []

    def set_access_lost_at(self, owner_id: str, value: datetime | None) -> None:
        self.calls.append((owner_id, value))


def _service() -> tuple[AccountPauseService, InMemoryAccountPauseRepository, FakeSubscriptions]:
    repository = InMemoryAccountPauseRepository()
    subscriptions = FakeSubscriptions()
    return AccountPauseService(repository, subscriptions), repository, subscriptions  # type: ignore[arg-type]


def test_starting_a_pause_clears_the_120_day_clock_in_the_same_operation() -> None:
    service, repository, subscriptions = _service()

    service.start(OWNER, NOW)

    assert repository.is_paused(OWNER)
    assert subscriptions.calls == [(OWNER, None)]


def test_pause_on_day_60_and_return_two_years_later_is_not_790_days_lost() -> None:
    """The real repository: the clock was stamped, the pause clears it, so the
    day D that comes back is new and the 120-day job can never erase at once."""
    subscriptions = InMemorySubscriptionRepository()
    lost = NOW - timedelta(days=60)
    subscriptions.save(Subscription(owner_id=OWNER, trial_ends_at=lost))
    subscriptions.set_access_lost_at(OWNER, lost)  # D was stamped 60 days ago
    service = AccountPauseService(InMemoryAccountPauseRepository(), subscriptions)

    service.start(OWNER, NOW)

    stored = subscriptions.get(OWNER)
    assert stored is not None and stored.access_lost_at is None
    # Nothing to count from: the job has no day D for this account, so it cannot
    # find 790 days two years later.
    two_years_later = NOW + timedelta(days=730)
    assert days_since_loss(lost, two_years_later) == 790  # what the old D would have said
    assert stored.access_lost_at is None


def test_asking_twice_keeps_the_first_date() -> None:
    service, repository, _ = _service()
    service.start(OWNER, NOW)
    service.start(OWNER, NOW + timedelta(days=5))
    pause = repository.get(OWNER)
    assert pause is not None and pause.paused_at == NOW


def test_the_session_that_paused_is_refused_and_a_new_sign_in_resumes() -> None:
    service, repository, _ = _service()
    service.start(OWNER, NOW)

    # The old session: signed in before the pause began.
    assert service.resume_if_signed_in_again(OWNER, NOW - timedelta(minutes=1)) is False
    assert repository.is_paused(OWNER)
    # A new sign-in, after it.
    assert service.resume_if_signed_in_again(OWNER, NOW + timedelta(days=40)) is True
    assert not repository.is_paused(OWNER)


def test_an_unknown_sign_in_time_never_ends_the_pause() -> None:
    """Only a real sign-in ends it: a token whose time cannot be read, like a
    silent refresh, must not."""
    service, repository, _ = _service()
    service.start(OWNER, NOW)
    assert service.resume_if_signed_in_again(OWNER, None) is False
    assert repository.is_paused(OWNER)


def test_an_account_that_is_not_paused_is_always_usable() -> None:
    service, _, _ = _service()
    assert service.resume_if_signed_in_again(OWNER, NOW) is True


def _guard() -> tuple[AgeGuardedAuthProvider, FakeInner, AccountPauseService]:
    service, _, _ = _service()
    inner = FakeInner()
    guard = AgeGuardedAuthProvider(
        inner,  # type: ignore[arg-type]
        lambda: InMemoryAccountAgeRepository(),
        None,
        lambda: service,
    )
    return guard, inner, service


def test_the_guard_refuses_the_old_session_with_account_paused_and_lets_a_new_one_in() -> None:
    guard, inner, service = _guard()
    inner.signed_in_at = datetime.now(UTC) - timedelta(hours=1)
    service.start(OWNER, datetime.now(UTC))
    guard.forget(OWNER)

    with pytest.raises(AgeRestrictedError) as refused:
        guard.get_current_user()
    assert refused.value.code == "account_paused"

    # Signs in again: the pause ends before any route logic runs.
    inner.signed_in_at = datetime.now(UTC) + timedelta(minutes=1)
    assert guard.get_current_user().id == OWNER
    assert not service.is_paused(OWNER)
    # And it stays usable.
    assert guard.get_current_user().id == OWNER


def test_routes_a_paused_account_may_still_use_skip_the_pause_check() -> None:
    guard, _, service = _guard()
    service.start(OWNER, datetime.now(UTC))
    guard.forget(OWNER)
    with allow_closed_account():
        assert guard.get_current_user().id == OWNER
    assert service.is_paused(OWNER)
