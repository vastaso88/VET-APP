"""Declared age: bands, one-time declaration, Mercatino and paid-plan blocks,
the closed account, and the 30-day review (dry run)."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.auth_provider import AuthenticatedUser, AuthSession
from packages.core.application.services.age_gate import AgeGateService
from packages.core.application.services.underage_review_dry_run import (
    UnderageReviewDryRunService,
)
from packages.core.domain.age.models import AccountAge, AgeBand, band_for
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
)
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.supabase.supabase_owner_contact_lookup import (
    SupabaseOwnerContactLookup,
)
from packages.shared.errors.base import AgeRestrictedError, ValidationError

TODAY = date(2026, 11, 8)
NOW = datetime(2026, 11, 8, 12, 0, tzinfo=UTC)
OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"


def _born(years: int, *, days_short: int = 0) -> date:
    """Born so that the owner is [years] old on TODAY, [days_short] days short of it."""
    return date(TODAY.year - years, TODAY.month, TODAY.day) + timedelta(days=days_short)


@pytest.mark.parametrize(
    ("birth", "band"),
    [
        (None, AgeBand.UNKNOWN),
        (_born(14, days_short=1), AgeBand.UNDER_MINIMUM),  # 14th birthday tomorrow
        (_born(14), AgeBand.MINOR),  # 14th birthday today
        (_born(18, days_short=1), AgeBand.MINOR),  # 18th birthday tomorrow
        (_born(18), AgeBand.ADULT),  # 18th birthday today
        (_born(40), AgeBand.ADULT),
    ],
)
def test_bands_change_exactly_on_the_birthdays(birth: date | None, band: str) -> None:
    assert band_for(birth, TODAY) == band


def _gate() -> tuple[AgeGateService, InMemoryAccountAgeRepository]:
    repository = InMemoryAccountAgeRepository()
    return AgeGateService(repository), repository


def test_a_date_can_be_declared_once_and_never_overwritten() -> None:
    gate, _ = _gate()
    assert gate.declare(OWNER, _born(30), now=NOW).band == AgeBand.ADULT

    with pytest.raises(AgeRestrictedError) as error:
        gate.declare(OWNER, _born(15), now=NOW)

    assert error.value.code == "age_already_declared"
    assert gate.status(OWNER, TODAY).band == AgeBand.ADULT


@pytest.mark.parametrize("birth", [TODAY + timedelta(days=1), date(1800, 1, 1)])
def test_an_impossible_date_is_refused(birth: date) -> None:
    gate, repository = _gate()
    with pytest.raises(ValidationError):
        gate.declare(OWNER, birth, now=NOW)
    assert repository.get(OWNER) is None


def test_the_status_never_carries_the_date() -> None:
    gate, _ = _gate()
    status = gate.declare(OWNER, _born(16), now=NOW)
    assert "birth" not in status.model_dump_json().lower()


def test_the_mercatino_is_for_declared_adults_only() -> None:
    gate, _ = _gate()
    with pytest.raises(AgeRestrictedError, match="age_required"):
        gate.require_marketplace(OWNER)

    gate.declare(OTHER, _born(16), now=NOW)
    with pytest.raises(AgeRestrictedError, match="marketplace_adults_only"):
        gate.require_marketplace(OTHER)

    gate.declare(OWNER, _born(30), now=NOW)
    gate.require_marketplace(OWNER)


def test_a_paid_plan_needs_a_declared_age_and_a_minor_needs_a_parents_ok() -> None:
    gate, _ = _gate()
    with pytest.raises(AgeRestrictedError, match="age_required"):
        gate.require_paid_plan(OWNER)

    gate.declare(OWNER, _born(16), now=NOW)
    with pytest.raises(AgeRestrictedError, match="guardian_required"):
        gate.require_paid_plan(OWNER)

    status = gate.confirm_guardian(OWNER)
    assert status.guardian_confirmed and status.paid_plan_allowed
    gate.require_paid_plan(OWNER)

    gate.declare(OTHER, _born(40), now=NOW)
    gate.require_paid_plan(OTHER)


def test_the_parents_ok_applies_only_to_a_declared_minor() -> None:
    gate, _ = _gate()
    with pytest.raises(AgeRestrictedError, match="age_required"):
        gate.confirm_guardian(OWNER)
    gate.declare(OWNER, _born(30), now=NOW)
    with pytest.raises(ValidationError):
        gate.confirm_guardian(OWNER)


def test_one_owners_declaration_does_not_touch_another() -> None:
    gate, repository = _gate()
    gate.declare(OWNER, _born(16), now=NOW)
    gate.confirm_guardian(OWNER)

    assert gate.status(OTHER).band == AgeBand.UNKNOWN
    assert repository.get(OTHER) is None
    with pytest.raises(AgeRestrictedError, match="age_required"):
        gate.confirm_guardian(OTHER)


# -- the closed account ---------------------------------------------------------


class _Inner:
    """The real provider's stand-in: always the same signed-in owner."""

    def get_current_user(self) -> AuthenticatedUser:
        return AuthenticatedUser(id=OWNER, email="a@example.com")

    def update_preferred_locale(self, locale: Any) -> AuthenticatedUser:
        return self.get_current_user()

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        raise NotImplementedError

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        return None

    def last_sign_in_at(self) -> datetime | None:
        return datetime.now(UTC)


class _Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def _guarded(
    repository: InMemoryAccountAgeRepository, clock: _Clock | None = None
) -> AgeGuardedAuthProvider:
    return AgeGuardedAuthProvider(_Inner(), lambda: repository, clock=clock or _Clock())


def _declare_under_minimum(repository: InMemoryAccountAgeRepository) -> None:
    today = datetime.now(UTC).date()
    repository.create(
        AccountAge(
            owner_id=OWNER,
            birth_date=today.replace(year=today.year - 10),
            declared_at=datetime.now(UTC),
        )
    )


def test_an_account_under_the_minimum_age_can_do_nothing_but_read_its_status_and_delete() -> None:
    repository = InMemoryAccountAgeRepository()
    provider = _guarded(repository)
    assert provider.get_current_user().id == OWNER  # no declaration: open

    _declare_under_minimum(repository)
    provider.forget(OWNER)

    with pytest.raises(AgeRestrictedError) as error:
        provider.get_current_user()
    assert error.value.code == "under_minimum_age"

    with allow_closed_account():
        assert provider.get_current_user().id == OWNER


def test_the_closed_state_is_cached_for_a_minute_and_forgotten_on_demand() -> None:
    repository = InMemoryAccountAgeRepository()
    clock = _Clock()
    provider = _guarded(repository, clock)
    provider.get_current_user()  # cached as open
    _declare_under_minimum(repository)

    provider.get_current_user()  # still the cached answer
    clock.now = 61
    with pytest.raises(AgeRestrictedError):
        provider.get_current_user()


def test_a_failing_age_lookup_does_not_lock_anyone_out() -> None:
    class Broken:
        def get(self, owner_id: str) -> Any:
            raise RuntimeError("table missing")

    provider = AgeGuardedAuthProvider(
        _Inner(),
        lambda: Broken(),  # type: ignore[arg-type,return-value]
    )
    assert provider.get_current_user().id


# -- the 30-day review (dry run) ---------------------------------------------------


def test_the_review_counts_closed_accounts_and_those_past_the_grace_period() -> None:
    repository = InMemoryAccountAgeRepository()
    today = datetime.now(UTC).date()
    child = today.replace(year=today.year - 10)
    for owner, declared in (
        ("a", datetime.now(UTC) - timedelta(days=40)),
        ("b", datetime.now(UTC) - timedelta(days=3)),
    ):
        repository.create(AccountAge(owner_id=owner, birth_date=child, declared_at=declared))
    repository.create(
        AccountAge(
            owner_id="c",
            birth_date=today.replace(year=today.year - 30),
            declared_at=datetime.now(UTC) - timedelta(days=90),
        )
    )

    report = UnderageReviewDryRunService(repository).execute()

    assert (report.closed_accounts, report.past_grace_period) == (2, 1)
    assert report.dry_run is True
    assert OWNER not in report.model_dump_json()


# -- Pricing reads the declared age from the table, not from user metadata ----------


class _Rows:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows

    def select(self, *_a: Any) -> _Query:
        return self

    def eq(self, *_a: Any) -> _Query:
        return self

    def limit(self, *_a: Any) -> _Query:
        return self

    def execute(self) -> _Rows:
        return _Rows(self._rows)


class _User:
    email = "a@example.com"
    email_confirmed_at = "2026-01-01"
    # What an owner can write into their own account — it must be ignored.
    user_metadata = {"birth_date": "1980-01-01"}


class _ClientWithAge:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows
        self.auth = type(
            "Auth",
            (),
            {
                "admin": type(
                    "Admin",
                    (),
                    {"get_user_by_id": lambda _s, _i: type("R", (), {"user": _User()})()},
                )()
            },
        )()

    def table(self, name: str) -> _Query:
        assert name == "account_age"
        return _Query(self._rows)


def test_the_declared_age_comes_from_the_table_and_metadata_is_ignored() -> None:
    declared = SupabaseOwnerContactLookup(_ClientWithAge([{"birth_date": "2012-05-01"}]))  # type: ignore[arg-type]
    assert declared.get(OWNER).birth_date == date(2012, 5, 1)  # type: ignore[union-attr]

    nothing_declared = SupabaseOwnerContactLookup(_ClientWithAge([]))  # type: ignore[arg-type]
    assert nothing_declared.get(OWNER).birth_date is None  # type: ignore[union-attr]
