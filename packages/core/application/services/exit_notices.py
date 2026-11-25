"""One scheduler call that sends every due service e-mail: the exit notices (docs/compliance/18)
and the reminder of the yearly renewals (owner decision of 25 November 2026).

One budget of e-mails for the run, the exit notices first (they have legal dates). The answer is
numbers only. With sending off (or the texts not configured) nothing is looked up and nothing is
written: it only counts what would be due.
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, computed_field

from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.notice_mailer import (
    NoticeCounts,
    NoticeMailer,
    SendBudget,
)
from packages.core.application.services.renewal_notices import RenewalNoticeService


class ExitNoticeReport(BaseModel):
    sending_enabled: bool
    ready: bool
    deletion: NoticeCounts = Field(default_factory=NoticeCounts)
    # The reminder before a yearly renewal. All zero when store billing is off.
    renewal: NoticeCounts = Field(default_factory=NoticeCounts)

    @computed_field  # type: ignore[prop-decorator]
    @property
    def alarm(self) -> int:
        """How many things the team has to look at: notices that failed through our fault or
        are overdue, and a notice log that cannot be written. The scheduler job turns red when
        it is above 0. Numbers only."""
        total = self.deletion.failed + sum(self.deletion.overdue.values()) + self.renewal.failed
        broken = {self.deletion.blocked} & {"no_notice_log", "record_failed"}
        renewal_broken = {self.renewal.blocked} & {"read_failed", "record_failed", "release_failed"}
        return total + len(broken) + len(renewal_broken)


class ExitNoticeService:
    def __init__(
        self,
        deletion: AccountDeletionService,
        mailer: NoticeMailer,
        max_per_run: int,
        renewal: RenewalNoticeService | None = None,
    ) -> None:
        self._deletion = deletion
        self._mailer = mailer
        self._max_per_run = max_per_run
        # None when store billing is off: there is no subscription to renew.
        self._renewal = renewal

    def run(self, now: datetime | None = None) -> ExitNoticeReport:
        budget = SendBudget(self._max_per_run)
        return ExitNoticeReport(
            sending_enabled=self._mailer.enabled,
            ready=self._mailer.ready,
            deletion=self._deletion.send_notices(now, budget),
            renewal=(
                self._renewal.send_notices(now, budget)
                if self._renewal is not None
                else NoticeCounts()
            ),
        )
