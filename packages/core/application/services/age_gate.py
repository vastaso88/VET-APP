from datetime import date, datetime

from pydantic import BaseModel

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.domain.age.models import (
    OLDEST_PLAUSIBLE_AGE,
    AccountAge,
    AgeBand,
    age_on,
    band_for,
)
from packages.core.domain.common.entity import utc_now
from packages.shared.errors.base import AgeRestrictedError, ValidationError


class AgeStatus(BaseModel):
    """What the app may know: the band and what it unlocks. Never the date."""

    band: str
    marketplace_allowed: bool
    # Paid plans: an adult freely, a declared minor only after confirming a
    # parent's authorisation, an unknown age not before declaring it.
    guardian_required: bool
    guardian_confirmed: bool
    paid_plan_allowed: bool


def _status(band: str, guardian_confirmed: bool) -> AgeStatus:
    guardian_required = band == AgeBand.MINOR
    return AgeStatus(
        band=band,
        marketplace_allowed=band == AgeBand.ADULT,
        guardian_required=guardian_required,
        guardian_confirmed=guardian_confirmed,
        paid_plan_allowed=band == AgeBand.ADULT or (guardian_required and guardian_confirmed),
    )


class AgeGateService:
    """Declared age, the blocks that follow from it, and nothing else."""

    def __init__(self, repository: AccountAgeRepository) -> None:
        self._repository = repository

    def status(self, owner_id: str, today: date | None = None) -> AgeStatus:
        record = self._repository.get(owner_id)
        today = today or utc_now().date()
        band = band_for(record.birth_date if record else None, today)
        return _status(band, bool(record and record.guardian_ok_at))

    def declare(self, owner_id: str, birth_date: date, now: datetime | None = None) -> AgeStatus:
        """Stores the date once. An age under the minimum is stored too: it
        is what keeps the account closed (and lets the 30-day review find it)."""
        now = now or utc_now()
        age = age_on(birth_date, now.date())
        if age < 0 or age > OLDEST_PLAUSIBLE_AGE:
            raise ValidationError("birth_date is not plausible")
        created = self._repository.create(
            AccountAge(owner_id=owner_id, birth_date=birth_date, declared_at=now)
        )
        if not created:
            raise AgeRestrictedError("age_already_declared")
        return self.status(owner_id, now.date())

    def confirm_guardian(self, owner_id: str, now: datetime | None = None) -> AgeStatus:
        status = self.status(owner_id)
        if status.band == AgeBand.UNKNOWN:
            raise AgeRestrictedError("age_required")
        if status.band != AgeBand.MINOR:
            raise ValidationError("a parent's authorisation applies only to a declared minor")
        self._repository.mark_guardian_ok(owner_id, now or utc_now())
        return self.status(owner_id)

    def require_marketplace(self, owner_id: str) -> None:
        status = self.status(owner_id)
        if status.band == AgeBand.UNKNOWN:
            raise AgeRestrictedError("age_required")
        if not status.marketplace_allowed:
            raise AgeRestrictedError("marketplace_adults_only")

    def require_paid_plan(self, owner_id: str) -> None:
        status = self.status(owner_id)
        if status.band == AgeBand.UNKNOWN:
            raise AgeRestrictedError("age_required")
        if not status.paid_plan_allowed:
            raise AgeRestrictedError("guardian_required")
