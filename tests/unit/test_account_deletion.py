"""The two steps of deleting an account, the purge at the end of the period, the
guard that deactivates, and the ads that disappear."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.ports.auth_provider import AuthenticatedUser, AuthSession
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.delete_account import RecentSignInRequired
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
)
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.shared.errors.base import AgeRestrictedError

NOW = datetime(2026, 11, 16, 12, 0, tzinfo=UTC)
FRESH = NOW - timedelta(minutes=1)
OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"


class _Eraser:
    def __init__(self, fail_for: set[str] | None = None) -> None:
        self.erased: list[str] = []
        self.identities: list[str] = []
        self._fail_for = fail_for or set()

    def erase_data(self, owner_id: str) -> ErasureReport:
        if owner_id in self._fail_for:
            raise RuntimeError("storage unavailable")
        self.erased.append(owner_id)
        return ErasureReport()

    def delete_identity(self, owner_id: str) -> None:
        self.identities.append(owner_id)


def _service(
    grace_days: int = 30, eraser: _Eraser | None = None
) -> tuple[AccountDeletionService, InMemoryAccountDeletionRepository, _Eraser]:
    repository = InMemoryAccountDeletionRepository()
    eraser = eraser or _Eraser()
    return AccountDeletionService(repository, eraser, grace_days), repository, eraser


def test_requesting_sets_the_day_from_the_setting_and_erases_nothing() -> None:
    for days in (1, 30, 90):
        service, _, eraser = _service(grace_days=days)
        status = service.request(OWNER, FRESH, now=NOW)

        assert status.pending and status.grace_days == days
        assert status.purge_after == NOW + timedelta(days=days)
        assert eraser.erased == []


def test_asking_again_does_not_move_the_day() -> None:
    service, _, _ = _service()
    first = service.request(OWNER, FRESH, now=NOW)
    later_now = NOW + timedelta(days=5)
    later = service.request(OWNER, later_now - timedelta(minutes=1), now=later_now)
    assert later.purge_after == first.purge_after


@pytest.mark.parametrize("signed_in", [None, NOW - timedelta(hours=2)])
def test_an_old_or_unknown_sign_in_cannot_request_or_cancel(signed_in: datetime | None) -> None:
    service, repository, _ = _service()
    with pytest.raises(RecentSignInRequired):
        service.request(OWNER, signed_in, now=NOW)
    assert repository.get(OWNER) is None

    service.request(OWNER, FRESH, now=NOW)
    with pytest.raises(RecentSignInRequired):
        service.cancel(OWNER, signed_in, now=NOW)
    assert repository.get(OWNER) is not None


def test_cancelling_removes_the_request_and_only_that_owners() -> None:
    service, repository, _ = _service()
    service.request(OWNER, FRESH, now=NOW)
    service.request(OTHER, FRESH, now=NOW)

    status = service.cancel(OWNER, FRESH, now=NOW)

    assert not status.pending
    assert repository.get(OTHER) is not None


def test_the_purge_erases_only_the_accounts_whose_period_ended() -> None:
    service, repository, eraser = _service(grace_days=30)
    service.request(OWNER, FRESH, now=NOW - timedelta(days=31))
    service.request(OTHER, FRESH, now=NOW - timedelta(days=5))

    report = service.purge_due(enabled=True, now=NOW)

    assert (report.due, report.erased, report.failed) == (1, 1, 0)
    assert eraser.erased == [OWNER] and eraser.identities == [OWNER]
    assert repository.get(OWNER) is None  # the row goes last
    assert repository.get(OTHER) is not None


def test_while_the_purge_is_off_it_only_counts() -> None:
    service, repository, eraser = _service()
    service.request(OWNER, FRESH, now=NOW - timedelta(days=40))

    report = service.purge_due(enabled=False, now=NOW)

    assert (report.enabled, report.due, report.erased) == (False, 1, 0)
    assert eraser.erased == [] and repository.get(OWNER) is not None


def test_a_failed_erase_keeps_the_account_deactivated_and_the_rest_goes_on() -> None:
    service, repository, eraser = _service(eraser=_Eraser(fail_for={OWNER}))
    service.request(OWNER, FRESH, now=NOW - timedelta(days=40))
    service.request(OTHER, FRESH, now=NOW - timedelta(days=40))

    report = service.purge_due(enabled=True, now=NOW)

    assert (report.erased, report.failed) == (1, 1)
    assert repository.get(OWNER) is not None  # tried again at the next run
    assert repository.get(OTHER) is None
    assert eraser.identities == [OTHER]


# -- the guard ---------------------------------------------------------------------


class _Inner:
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


def test_an_account_waiting_to_be_erased_can_do_nothing_but_read_and_cancel() -> None:
    deletions = InMemoryAccountDeletionRepository()
    provider = AgeGuardedAuthProvider(
        _Inner(), lambda: InMemoryAccountAgeRepository(), lambda: deletions, ttl_seconds=0
    )
    assert provider.get_current_user().id == OWNER

    deletions.create(
        AccountDeletionRequest(
            owner_id=OWNER, requested_at=NOW, purge_after=NOW + timedelta(days=30)
        )
    )
    with pytest.raises(AgeRestrictedError) as error:
        provider.get_current_user()
    assert error.value.code == "account_deactivated"
    with allow_closed_account():
        assert provider.get_current_user().id == OWNER

    deletions.delete(OWNER)
    assert provider.get_current_user().id == OWNER


# -- the ads ------------------------------------------------------------------------


def test_the_ads_of_an_account_waiting_to_be_erased_are_hidden() -> None:
    from packages.core.application.services.list_nearby_listings import (
        ListNearbyListingsInput,
        ListNearbyListingsService,
    )
    from packages.core.domain.geo.models import Coordinates
    from packages.core.domain.marketplace.models import MarketplaceListing

    class _Listings:
        def __init__(self, items: list[MarketplaceListing]) -> None:
            self._items = items

        def list_active(self, country: str | None = None) -> list[MarketplaceListing]:
            return self._items

        def list_active_in_box(
            self, box: object, category: object = None
        ) -> list[MarketplaceListing]:
            return self._items

    here = Coordinates(latitude=45.0, longitude=9.0)

    def ad(listing_id: str, owner: str) -> MarketplaceListing:
        return MarketplaceListing(
            id=listing_id,
            owner_id=owner,
            title="Trasportino",
            category="kennels_carriers",
            condition="good",
            location=here,
        )

    hidden: set[str] = {OWNER}
    service = ListNearbyListingsService(
        _Listings([ad("1", OWNER), ad("2", OTHER)]),  # type: ignore[arg-type]
        hidden_owner_ids=lambda: hidden,
    )
    query = ListNearbyListingsInput(buyer_location=here, max_distance_km=10)

    assert [item.id for item in service.execute(query).listings] == ["2"]

    hidden.clear()  # the deletion was cancelled
    assert sorted(item.id for item in service.execute(query).listings) == ["1", "2"]


# -- recovery gives the optional consents back as "not given" -------------------------


def test_after_a_recovery_the_optional_consents_are_asked_again() -> None:
    from packages.core.domain.consent.models import (
        AccountConsents,
        AccountConsentType,
        ConsentRecord,
    )
    from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
    from packages.core.domain.pet_profile.models import PetProfile
    from packages.infrastructure.persistence.in_memory_repositories import (
        InMemoryAccountConsentsRepository,
        InMemoryPetProfileRepository,
    )

    consents = InMemoryAccountConsentsRepository()
    pets = InMemoryPetProfileRepository()
    granted = ConsentRecord(granted=True, version="v1")
    consents.save(
        AccountConsents(
            owner_id=OWNER,
            consents={
                AccountConsentType.TERMS_OF_SERVICE: granted,
                AccountConsentType.MARKETING_EMAIL: granted,
                AccountConsentType.ANALYTICS: granted,
                AccountConsentType.DIAGNOSTICS: granted,
            },
        )
    )
    pets.save(
        PetProfile(
            id="p1",
            owner_id=OWNER,
            name="Brina",
            species="Cane",
            medical_record_consent=MedicalRecordConsentRecord(granted=True, version="v1"),
        )
    )
    pets.save(PetProfile(id="p2", owner_id=OTHER, name="Milo", species="Gatto"))
    repository = InMemoryAccountDeletionRepository()
    service = AccountDeletionService(repository, _Eraser(), 30, consents, pets)
    service.request(OWNER, FRESH, now=NOW)

    service.cancel(OWNER, FRESH, now=NOW)

    kept = consents.get(OWNER)
    assert kept is not None
    assert set(kept.consents) == {AccountConsentType.TERMS_OF_SERVICE}
    reset = pets.get("p1")
    assert reset is not None and reset.medical_record_consent is None


def test_the_period_cannot_be_set_above_thirty_days(monkeypatch: pytest.MonkeyPatch) -> None:
    from pydantic import ValidationError

    from packages.shared.config.settings import Settings

    monkeypatch.setenv("ACCOUNT_DELETION_GRACE_DAYS", "120")
    with pytest.raises(ValidationError):
        Settings()
    monkeypatch.setenv("ACCOUNT_DELETION_GRACE_DAYS", "30")
    assert Settings().account_deletion_grace_days == 30
