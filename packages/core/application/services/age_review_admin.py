"""The team's tool for accounts that declared an age under the minimum.

The owner decided (9 November 2026) that nothing is erased automatically. The
duty to erase stays (art. 17(1)(d) GDPR): the team does it by hand, within 30
days of finding out or of being asked. This service is that hand: a list with
the least that is needed to act, an erase that uses the same eraser as the
owner's own account deletion, and the correction of a mistyped date.

Accounts are named by a keyed reference, never by id. The list carries no date
of birth, and the e-mail only as a hint (first letter and domain) to match the
message that an owner wrote to support. Logs say how many rows went, nothing
more."""

from __future__ import annotations

import logging
from datetime import date, datetime

from pydantic import BaseModel

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.domain.age.models import (
    OLDEST_PLAUSIBLE_AGE,
    UNDER_MINIMUM_GRACE_DAYS,
    AccountAge,
    AgeBand,
    age_on,
    band_for,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.shared.errors.base import ValidationError

logger = logging.getLogger(__name__)

_REF_SALT = "closed-by-age"


class ClosedAccount(BaseModel):
    ref: str
    closed_at: datetime
    days_closed: int
    # 30 days or more since the account was closed.
    past_deadline: bool
    # The owner wrote to say the date was a mistake: do not erase.
    correction_requested: bool
    # "a***@example.com", to recognise the sender of a message. None if unknown.
    email_hint: str | None = None


class DateCorrected(BaseModel):
    """[owner_id] is for the caller to clear its caches; it is never sent to the portal."""

    band: str
    owner_id: str


class ErasureOutcome(BaseModel):
    """Numbers only."""

    rows_deleted: int
    files_removed: int


def email_hint(email: str | None) -> str | None:
    if not email or "@" not in email:
        return None
    local, _, domain = email.partition("@")
    return f"{local[:1]}***@{domain}" if local else None


class AgeReviewAdminService:
    def __init__(
        self,
        repository: AccountAgeRepository,
        contacts: OwnerContactLookup,
        eraser: AccountEraser,
        secret: str,
    ) -> None:
        self._repository = repository
        self._contacts = contacts
        self._eraser = eraser
        self._secret = f"{secret}:{_REF_SALT}"

    def ref_of(self, owner_id: str) -> str:
        return reporter_ref(owner_id, self._secret)

    # -- reading ----------------------------------------------------------------

    def _closed(self, today: date) -> list[AccountAge]:
        return [
            record
            for record in self._repository.list_all()
            if band_for(record.birth_date, today) == AgeBand.UNDER_MINIMUM
        ]

    def _find(self, ref: str, today: date) -> AccountAge | None:
        for record in self._closed(today):
            if self.ref_of(record.owner_id) == ref:
                return record
        return None

    def closed_accounts(self, now: datetime | None = None) -> list[ClosedAccount]:
        now = now or utc_now()
        accounts = []
        for record in self._closed(now.date()):
            days = max(0, (now - record.declared_at).days)
            contact = self._contacts.get(record.owner_id)
            accounts.append(
                ClosedAccount(
                    ref=self.ref_of(record.owner_id),
                    closed_at=record.declared_at,
                    days_closed=days,
                    past_deadline=days >= UNDER_MINIMUM_GRACE_DAYS,
                    correction_requested=record.correction_requested_at is not None,
                    email_hint=email_hint(contact.email if contact else None),
                )
            )
        # Oldest first: those closest to (or past) the 30 days.
        return sorted(accounts, key=lambda item: item.closed_at)

    # -- acting -----------------------------------------------------------------

    def erase(self, ref: str, confirm: str, now: datetime | None = None) -> ErasureOutcome | None:
        """Erases a closed account with the same eraser as the owner's own
        deletion. None when no closed account has that reference. [confirm]
        must repeat the reference: a click on the wrong row is not enough."""
        now = now or utc_now()
        record = self._find(ref, now.date())
        if record is None:
            return None
        if confirm != ref:
            raise ValidationError("confirmation does not match")
        if record.correction_requested_at is not None:
            raise ValidationError("a correction was requested: resolve it first")

        report = self._eraser.erase_data(record.owner_id)
        self._eraser.delete_identity(record.owner_id)
        outcome = ErasureOutcome(
            rows_deleted=sum(report.rows_deleted.values()), files_removed=report.files_removed
        )
        # Only the numbers are written down.
        logger.info(
            "closed-by-age account erased by the team: rows=%d files=%d",
            outcome.rows_deleted,
            outcome.files_removed,
        )
        return outcome

    def correct_birth_date(
        self, ref: str, birth_date: date, now: datetime | None = None
    ) -> DateCorrected | None:
        """Support's correction of a mistyped date (right to rectification).
        None when no closed account has that reference."""
        now = now or utc_now()
        record = self._find(ref, now.date())
        if record is None:
            return None
        years = age_on(birth_date, now.date())
        if years < 0 or years > OLDEST_PLAUSIBLE_AGE:
            raise ValidationError("birth_date is not plausible")
        updated = self._repository.replace_birth_date(record.owner_id, birth_date)
        if updated is None:
            return None
        logger.info("a declared date of birth was corrected by support")
        return DateCorrected(
            band=band_for(updated.birth_date, now.date()), owner_id=updated.owner_id
        )

    def set_correction_requested(
        self, ref: str, requested: bool, now: datetime | None = None
    ) -> bool:
        now = now or utc_now()
        record = self._find(ref, now.date())
        if record is None:
            return False
        self._repository.set_correction_requested(record.owner_id, now if requested else None)
        return True
