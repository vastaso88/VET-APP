"""Pausing an account and coming back (docs/auth/02).

Starting a pause does two things in one operation: it records the pause and it
CLEARS the 120-day clock (`set_access_lost_at(owner, None)`), exactly like
choosing a plan. Without that, someone who pauses on day 60 and returns two
years later without a plan would find "790 days since the loss" and be erased on
the first run. When they return, the clock starts again from a new day D, which
the subscription stamps by itself the first time it sees the account without
access.

The pause ends at the first sign-in made AFTER it started (the guard in
AgeGuardedAuthProvider calls [resume_if_signed_in_again]). The old session that
pressed the button never ends it: its token is refused.
"""

from __future__ import annotations

import logging
from datetime import datetime

from pydantic import BaseModel

from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.account_pause_repository import AccountPauseRepository
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.domain.account_deletion.log import DeletionReason
from packages.core.domain.account_pause import notices
from packages.core.domain.account_pause.models import AccountPause
from packages.core.domain.common.entity import utc_now

logger = logging.getLogger(__name__)


class PauseExpiryReport(BaseModel):
    """Counts only."""

    enabled: bool
    due: int = 0
    waiting_for_notice: int = 0
    erased: int = 0
    failed: int = 0


class AccountPauseService:
    def __init__(
        self,
        repository: AccountPauseRepository,
        subscriptions: SubscriptionRepository,
        max_months: int = 24,
        eraser: AccountEraser | None = None,
        log: DeletionLogService | None = None,
    ) -> None:
        self._repository = repository
        self._subscriptions = subscriptions
        self._max_months = max_months
        self._eraser = eraser
        self._log = log

    @property
    def max_months(self) -> int:
        return self._max_months

    def delete_after(self, pause: AccountPause) -> datetime:
        """The day the account is erased if the owner never signs in."""
        return notices.delete_after(pause.paused_at, self._max_months)

    def start(self, owner_id: str, now: datetime | None = None) -> AccountPause:
        """Puts the account in pause and clears the 120-day clock. Asking twice
        keeps the first date."""
        now = now or utc_now()
        self._repository.create(AccountPause(owner_id=owner_id, paused_at=now))
        # Same operation, never skipped: see the module docstring.
        self._subscriptions.set_access_lost_at(owner_id, None)
        pause = self._repository.get(owner_id)
        assert pause is not None
        return pause

    def is_paused(self, owner_id: str) -> bool:
        return self._repository.is_paused(owner_id)

    def resume_if_signed_in_again(self, owner_id: str, signed_in_at: datetime | None) -> bool:
        """True when the account is (now) usable: it was not paused, or the
        caller signed in after the pause began and the pause was ended. False
        when the caller is the session that paused it (or an older one).

        An unknown sign-in time does NOT end it (docs/compliance/18 §3.2): only a
        real sign-in with the credentials may. The time is the newest `amr`
        timestamp of the token, which a token refresh does not move, so neither
        an automatic refresh nor a check made by the app can end a pause."""
        pause = self._repository.get(owner_id)
        if pause is None or not pause.active:
            return True
        if signed_in_at is None or signed_in_at <= pause.paused_at:
            return False
        self._repository.resume(owner_id, utc_now())
        logger.info("a paused account was resumed")
        return True

    def ended_pause(self, owner_id: str) -> AccountPause | None:
        """The pause that ended at the last sign-in and was not yet shown to the
        owner, or None."""
        pause = self._repository.get(owner_id)
        return pause if pause is not None and not pause.active else None

    def acknowledge_end(self, owner_id: str) -> bool:
        return self._repository.acknowledge(owner_id)

    def purge_expired(self, enabled: bool, now: datetime | None = None) -> PauseExpiryReport:
        """Erases the pauses that ran their maximum without a sign-in, with the same
        eraser as the owner's own deletion and a row in the register of deletions. With
        [enabled] False it only counts. A pause is erased only after the "tomorrow"
        notice was recorded at least 20 hours ago: one never warned is never erased.
        Counts only, never ids."""
        now = now or utc_now()
        due = [
            pause
            for pause in self._repository.list_all()
            if now >= notices.delete_after(pause.paused_at, self._max_months)
        ]
        report = PauseExpiryReport(enabled=enabled, due=len(due))
        if not enabled or self._eraser is None:
            return report
        for pause in due:
            allowed = notices.erasure_allowed(
                pause.paused_at,
                self._max_months,
                now,
                last_notice=pause.last_notice,
                last_notice_at=pause.last_notice_at,
            )
            if not allowed:
                report.waiting_for_notice += 1
                continue
            try:
                if self._log is not None:
                    self._log.erase_account(
                        self._eraser, pause.owner_id, DeletionReason.PAUSE_EXPIRED, now
                    )
                else:
                    self._eraser.erase_data(pause.owner_id)
                    self._eraser.delete_identity(pause.owner_id)
                self._repository.delete(pause.owner_id)
                report.erased += 1
            except Exception:  # noqa: BLE001 - one failure must not stop the others
                logger.warning("could not erase an expired pause", exc_info=False)
                report.failed += 1
        logger.info("paused accounts erased at the end of their period: %d", report.erased)
        return report
