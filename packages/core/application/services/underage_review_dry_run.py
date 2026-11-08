from datetime import timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.domain.age.models import UNDER_MINIMUM_GRACE_DAYS, AgeBand, band_for
from packages.core.domain.common.entity import utc_now


class UnderageReviewReport(BaseModel):
    """Counts only. No ids, no dates: the report is about how many accounts."""

    dry_run: bool = True
    closed_accounts: int = 0
    # Closed for longer than the grace period: these are the ones the review
    # would erase once someone switches it on.
    past_grace_period: int = 0
    grace_days: int = UNDER_MINIMUM_GRACE_DAYS


class UnderageReviewDryRunService:
    """What the 30-day review of accounts that declared an age under the
    minimum would do. It reads and counts. There is no erase path here on
    purpose: the erasure stays off until the Orchestrator switches it on
    (same posture as the data-retention dry run)."""

    def __init__(self, repository: AccountAgeRepository) -> None:
        self._repository = repository

    def execute(self) -> UnderageReviewReport:
        now = utc_now()
        grace_cutoff = now - timedelta(days=UNDER_MINIMUM_GRACE_DAYS)
        report = UnderageReviewReport()
        for record in self._repository.list_declared_before(now + timedelta(seconds=1)):
            if band_for(record.birth_date, now.date()) != AgeBand.UNDER_MINIMUM:
                continue
            report.closed_accounts += 1
            if record.declared_at < grace_cutoff:
                report.past_grace_period += 1
        return report
