"""Deleting an account in two steps: deactivate now, erase when the period ends."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_consents_repository import (
    AccountConsentsRepository,
)
from packages.core.application.ports.account_deletion_repository import (
    AccountDeletionRepository,
)
from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.services.delete_account import (
    RECENT_SIGN_IN_WINDOW,
    RecentSignInRequired,
)
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.domain.account_deletion.log import DeletionReason
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.core.domain.common.entity import utc_now
from packages.core.domain.consent.models import AccountConsentType

logger = logging.getLogger(__name__)

_RESET_ON_RECOVERY = frozenset(
    {
        AccountConsentType.MARKETING_EMAIL,
        AccountConsentType.ANALYTICS,
        AccountConsentType.DIAGNOSTICS,
    }
)


class DeletionStatus(BaseModel):
    pending: bool
    requested_at: datetime | None = None
    purge_after: datetime | None = None
    grace_days: int


class PurgeReport(BaseModel):
    """Counts only."""

    enabled: bool
    due: int = 0
    erased: int = 0
    failed: int = 0


def _require_recent_sign_in(signed_in_at: datetime | None, now: datetime) -> None:
    if signed_in_at is None or now - signed_in_at > RECENT_SIGN_IN_WINDOW:
        raise RecentSignInRequired("Riaccedi per confermare l'eliminazione dell'account.")


class AccountDeletionService:
    def __init__(
        self,
        repository: AccountDeletionRepository,
        eraser: AccountEraser,
        grace_days: int,
        consents: AccountConsentsRepository | None = None,
        pets: PetProfileRepository | None = None,
        log: DeletionLogService | None = None,
    ) -> None:
        self._repository = repository
        self._eraser = eraser
        self._grace_days = grace_days
        self._consents = consents
        self._pets = pets
        self._log = log

    def status(self, owner_id: str) -> DeletionStatus:
        request = self._repository.get(owner_id)
        return DeletionStatus(
            pending=request is not None,
            requested_at=request.requested_at if request else None,
            purge_after=request.purge_after if request else None,
            grace_days=self._grace_days,
        )

    def request(
        self, owner_id: str, signed_in_at: datetime | None, now: datetime | None = None
    ) -> DeletionStatus:
        """Deactivates the account and sets the day it is erased for good.
        Asking again keeps the first date."""
        now = now or utc_now()
        _require_recent_sign_in(signed_in_at, now)
        self._repository.create(
            AccountDeletionRequest(
                owner_id=owner_id,
                requested_at=now,
                purge_after=now + timedelta(days=self._grace_days),
            )
        )
        return self.status(owner_id)

    def cancel(
        self, owner_id: str, signed_in_at: datetime | None, now: datetime | None = None
    ) -> DeletionStatus:
        """The owner changed their mind within the period. Needs a recent
        sign-in (a password reset through the e-mail link counts)."""
        now = now or utc_now()
        _require_recent_sign_in(signed_in_at, now)
        self._repository.delete(owner_id)
        self._reset_optional_consents(owner_id)
        return self.status(owner_id)

    def _reset_optional_consents(self, owner_id: str) -> None:
        """After a recovery the optional consents are "not given" again and are
        asked at first use (docs/compliance/16 §3): marketing, analytics, error
        reports and the chat's reading of each pet's medical record."""
        if self._consents is not None:
            current = self._consents.get(owner_id)
            if current is not None:
                kept = {
                    key: record
                    for key, record in current.consents.items()
                    if key not in _RESET_ON_RECOVERY
                }
                self._consents.save(current.model_copy(update={"consents": kept}))
        if self._pets is not None:
            for pet in self._pets.list_by_owner(owner_id):
                if pet.medical_record_consent is not None:
                    self._pets.save(pet.model_copy(update={"medical_record_consent": None}))

    def purge_due(self, enabled: bool, now: datetime | None = None) -> PurgeReport:
        """Erases the accounts whose period has ended, with the same eraser as
        the owner's own immediate deletion. With [enabled] False it only counts.
        The request row goes last: if anything fails the account stays
        deactivated and the next run tries again. Counts only, never ids."""
        now = now or utc_now()
        due = self._repository.list_due(now)
        report = PurgeReport(enabled=enabled, due=len(due))
        if not enabled:
            return report
        for request in due:
            try:
                if self._log is not None:
                    self._log.erase_account(
                        self._eraser, request.owner_id, DeletionReason.USER_PERIOD_END, now
                    )
                else:
                    self._eraser.erase_data(request.owner_id)
                    self._eraser.delete_identity(request.owner_id)
                self._repository.delete(request.owner_id)
                report.erased += 1
            except Exception:  # noqa: BLE001 - one failure must not stop the others
                logger.warning("could not erase an account whose period ended", exc_info=False)
                report.failed += 1
        logger.info("accounts erased at the end of their period: %d", report.erased)
        return report
