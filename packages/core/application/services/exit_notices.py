"""One scheduler call that sends every due exit notice (docs/compliance/18).

The deletion notices of one run, within one budget of e-mails. The answer is numbers only.
With sending off (or the texts not configured) nothing is looked up and nothing is written:
it only counts what would be due.
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


class ExitNoticeReport(BaseModel):
    sending_enabled: bool
    ready: bool
    deletion: NoticeCounts = Field(default_factory=NoticeCounts)

    @computed_field  # type: ignore[prop-decorator]
    @property
    def alarm(self) -> int:
        """How many things the team has to look at: notices that failed through our fault or
        are overdue, and a notice log that cannot be written. The scheduler job turns red when
        it is above 0. Numbers only."""
        total = self.deletion.failed + sum(self.deletion.overdue.values())
        broken = {self.deletion.blocked} & {"no_notice_log", "record_failed"}
        return total + len(broken)


class ExitNoticeService:
    def __init__(
        self,
        deletion: AccountDeletionService,
        mailer: NoticeMailer,
        max_per_run: int,
    ) -> None:
        self._deletion = deletion
        self._mailer = mailer
        self._max_per_run = max_per_run

    def run(self, now: datetime | None = None) -> ExitNoticeReport:
        budget = SendBudget(self._max_per_run)
        return ExitNoticeReport(
            sending_enabled=self._mailer.enabled,
            ready=self._mailer.ready,
            deletion=self._deletion.send_notices(now, budget),
        )
