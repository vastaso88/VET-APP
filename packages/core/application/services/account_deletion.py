"""Deleting an account in two steps: deactivate now, erase when the period ends."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from functools import partial

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
from packages.core.application.services.notice_mailer import (
    SENT,
    NoticeCounts,
    NoticeMailer,
    NoticeOutcome,
    Recipient,
    SendBudget,
    deliver_booked,
)
from packages.core.domain.account_deletion import notices
from packages.core.domain.account_deletion.log import DeletionReason
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.core.domain.common.entity import utc_now
from packages.core.domain.consent.models import AccountConsentType
from packages.core.domain.exit_notices import timing
from packages.core.domain.exit_notices.texts import format_date

logger = logging.getLogger(__name__)

# The template of each notice of the sequence (packages/core/domain/exit_notices/texts.py).
_TEMPLATES = {
    notices.CONFIRMED: "D1",
    notices.WEEK_LEFT: "D2",
    notices.TOMORROW: "D3",
}

# What to do with an account whose period has ended, with the notices required.
_ERASE = "erase"
_WAIT_QUIET = "wait_quiet"  # the 20 hours after the final notice
_WAIT_ALARM = "wait_alarm"  # the final notice is not registered: our fault, the team is told
_FORCED = "forced"  # the wait is over: erase, say why

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
    # The closing e-mail (D4), after the erase: numbers only.
    closing_sent: int = 0
    closing_skipped: int = 0
    closing_failed: int = 0
    # With notices required: accounts kept waiting (for the 20 hours after the final notice,
    # or because it is not registered yet), erased after the wait with no notice, and why
    # the job did not run. [alarm] is how many things the team has to look at; the
    # scheduler job turns red when it is above 0. Numbers only.
    waiting: int = 0
    forced: int = 0
    alarm: int = 0
    blocked: str | None = None


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
        mailer: NoticeMailer | None = None,
        notices_required: bool = False,
    ) -> None:
        self._repository = repository
        self._eraser = eraser
        self._grace_days = grace_days
        self._consents = consents
        self._pets = pets
        self._log = log
        self._mailer = mailer
        self._notices_required = notices_required

    def status(self, owner_id: str, now: datetime | None = None) -> DeletionStatus:
        request = self._repository.get(owner_id)
        return DeletionStatus(
            pending=request is not None,
            requested_at=request.requested_at if request else None,
            purge_after=self._real_date(request, now or utc_now()) if request else None,
            grace_days=self._grace_days,
        )

    def _real_date(self, request: AccountDeletionRequest, now: datetime) -> datetime:
        """The date the account will really be erased, which the screen shows. With notices
        required it is never earlier than 20 hours after the final notice (or after now, while
        that notice is not registered yet): a late notice moves it, by at most the wait."""
        if not self._notices_required:
            return request.purge_after
        final = notices.final_notice(request.requested_at, request.purge_after)
        if request.last_notice == final and request.last_notice_at is not None:
            earliest = request.last_notice_at + timing.MIN_GAP_AFTER_LAST_WARNING
        elif now >= request.purge_after:
            earliest = now + timing.MIN_GAP_AFTER_LAST_WARNING
        else:
            return request.purge_after
        return timing.job_run_after(max(request.purge_after, earliest))

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
        # Guard: with the notices required but unable to go (sending off, half configured, no
        # notice log) nothing is erased before the hard end of the wait, and the alarm is red at
        # every run. Then the request is erased all the same with the reason `notice_not_sent`: it
        # cannot stay still for ever for a fault of ours.
        blocked = self._notices_blocked() if self._notices_required else None
        if blocked is not None:
            report.blocked = blocked
            # Each waiting or forced request adds its own; with none due the mistake still counts.
            report.alarm = 0 if due else 1
            logger.warning("exit notices cannot go out: %s", blocked)
        for request in due:
            # The address is read BEFORE the identity goes (and kept only for the one send).
            who = "blocked" if blocked else self._who_before_erase(request.owner_id, now)
            recipient = who if isinstance(who, Recipient) else None
            reason = DeletionReason.USER_PERIOD_END
            if self._notices_required:
                if blocked is not None:
                    verdict = (
                        _FORCED
                        if now >= request.purge_after + notices.MAX_WAIT_AFTER_DUE
                        else _WAIT_ALARM
                    )
                else:
                    verdict = self._verdict(request, who, now)
                if verdict == _WAIT_QUIET:
                    report.waiting += 1
                    continue
                if verdict == _WAIT_ALARM:
                    report.waiting += 1
                    report.alarm += 1
                    continue
                if verdict == _FORCED:
                    reason = DeletionReason.NOTICE_NOT_SENT
            try:
                if self._log is not None:
                    self._log.erase_account(self._eraser, request.owner_id, reason, now)
                else:
                    self._eraser.erase_data(request.owner_id)
                    self._eraser.delete_identity(request.owner_id)
                self._repository.delete(request.owner_id)
                report.erased += 1
                if reason == DeletionReason.NOTICE_NOT_SENT:
                    report.forced += 1
                    report.alarm += 1
                self._send_closing(recipient, report)
            except Exception:  # noqa: BLE001 - one failure must not stop the others
                logger.warning("could not erase an account whose period ended", exc_info=False)
                report.failed += 1
        logger.info("accounts erased at the end of their period: %d", report.erased)
        return report

    # -- e-mail notices (docs/compliance/18 §5) ---------------------------------------------

    def _notices_blocked(self) -> str | None:
        if self._mailer is None:
            return "no_mailer"
        if not self._mailer.ready:
            return self._mailer.blocked_reason or "sending_off"
        if not self._repository.notice_log_available():
            return "no_notice_log"
        return None

    def _who_before_erase(self, owner_id: str, now: datetime) -> Recipient | str:
        """The person to write to, or the reason there is nobody (kept only for this run)."""
        if self._mailer is None or not self._mailer.ready:
            return "sending_off"
        try:
            return self._mailer.recipient_for(owner_id, now)
        except Exception:  # noqa: BLE001 - the erase goes on without it
            return "no_contact"

    def _verdict(self, request: AccountDeletionRequest, who: Recipient | str, now: datetime) -> str:
        """With the notices required: erase, wait quietly, wait with the alarm, or erase
        after the wait with no notice (docs/compliance/18 §8)."""
        if isinstance(who, str):
            # Nobody to write to (no or unconfirmed address, another language, closed by age,
            # the allow-list): there is nothing to repair, so nothing to wait for.
            return _ERASE
        final = notices.final_notice(request.requested_at, request.purge_after)
        if request.last_notice == final:
            booked = request.last_notice_at
            if booked is None or now - booked >= timing.MIN_GAP_AFTER_LAST_WARNING:
                return _ERASE
            return _WAIT_QUIET
        if now >= request.purge_after + notices.MAX_WAIT_AFTER_DUE:
            return _FORCED
        return _WAIT_ALARM

    def _send_closing(self, recipient: Recipient | None, report: PurgeReport) -> None:
        """D4, once, right after the erase: the address is not kept, so there is no retry."""
        if recipient is None or self._mailer is None:
            report.closing_skipped += 1
            return
        outcome = self._mailer.deliver(recipient, "D4", {})
        if outcome.kind == SENT:
            report.closing_sent += 1
        elif outcome.kind == "skipped":
            report.closing_skipped += 1
        else:
            report.closing_failed += 1

    def send_notices(
        self, now: datetime | None = None, budget: SendBudget | None = None
    ) -> NoticeCounts:
        """D1, D2 and D3 for the requests waiting. Only the latest one that is due and not
        yet sent goes out (never a burst of old ones); [last_notice] is written only after a
        successful send, so a failed or skipped one is looked at again next run and none goes
        twice. With sending off (or the texts not configured) it only counts. Numbers only."""
        now = now or utc_now()
        counts = NoticeCounts()
        due: list[tuple[AccountDeletionRequest, str]] = []
        for request in self._repository.list_pending():
            self._count_overdue(request, now, counts)
            final = notices.final_notice(request.requested_at, request.purge_after)
            if now >= request.purge_after:
                # The date is here. Without the notices required the erase takes it and a
                # notice would say something untrue. With them required the erase waits for
                # the final notice, so that one still goes (D_LATE: the true date).
                if not self._notices_required or request.last_notice == final:
                    continue
                kind: str | None = final
            else:
                kind = notices.due_waiting_notice(
                    request.requested_at, request.purge_after, now, request.last_notice
                )
            if kind is not None:
                due.append((request, kind))
        counts.due = len(due)
        mailer = self._mailer
        if mailer is None or not mailer.ready:
            counts.blocked = mailer.blocked_reason if mailer else "sending_off"
            return counts
        if not due:
            return counts
        if not self._repository.notice_log_available():
            counts.blocked = "no_notice_log"
            return counts
        budget = budget or SendBudget(len(due))
        for request, kind in due:
            if budget.exhausted:
                counts.postponed += 1
                continue
            # The day the erasure job really runs once the date has come (hourly, at a fixed
            # minute); for the final notice at least 20 hours after it goes out. In time: the
            # text as written. Late: the plain date, on any day.
            erasure = timing.effective_erasure(request.purge_after, now, _TEMPLATES[kind])
            template = timing.template_for_moment(_TEMPLATES[kind], now, erasure)
            keep_going = deliver_booked(
                mailer,
                request.owner_id,
                now,
                template,
                {
                    "data": format_date(request.requested_at),
                    "data_fine": format_date(erasure),
                },
                book=partial(
                    self._repository.claim_notice,
                    request.owner_id,
                    kind,
                    request.last_notice,
                    now,
                ),
                release=partial(
                    self._repository.release_notice,
                    request.owner_id,
                    kind,
                    request.last_notice,
                    request.last_notice_at,
                ),
                counts=counts,
                budget=budget,
            )
            if not keep_going:
                break
        return counts

    @staticmethod
    def _count_overdue(
        request: AccountDeletionRequest, now: datetime, counts: NoticeCounts
    ) -> None:
        """For the team, as numbers (docs/compliance/18 §8.9): D1 not gone within 24 hours of
        the request, D3 not gone by the day before the erasure. The erase itself never
        waits for them: the 30 days are the legal maximum."""
        if request.last_notice is None and now - request.requested_at > timedelta(hours=24):
            counts.overdue["D1"] = counts.overdue.get("D1", 0) + 1
        if (
            now >= request.purge_after - timedelta(days=1)
            and request.last_notice != notices.TOMORROW
        ):
            counts.overdue["D3"] = counts.overdue.get("D3", 0) + 1

    def send_restore_notice(self, owner_id: str) -> NoticeOutcome:
        """R1, the security message after a restore. One attempt, no retry (there is no row
        to retry from); never raises, so it can run after the answer has been sent."""
        if self._mailer is None:
            return NoticeOutcome("skipped", "sending_off")
        return self._mailer.send_to_owner(owner_id, "R1", {})
