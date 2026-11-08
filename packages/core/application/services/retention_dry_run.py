"""Dry run of the data-retention job (owner decision 2026-11-08).

It answers "what would the job do right now?" and nothing else: it reads, it
counts, it never sends a message and never erases anything, and it has no
code path that could (the only collaborators are two read-only ports).
Sending and erasure stay off until Confirm email, a custom SMTP sender and
the Terms exist, and are built then.

The report holds counts and a short sample of pseudonymous references: no
e-mail, no owner id, no name, so it can be read in a log or by a scheduler.
"""

from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.subscription.retention import (
    NOTICE_DAYS,
    days_since_loss,
    due_notice_day,
    erasure_allowed,
    past_retention,
)

# One contact lookup per account without access, each a call to the auth
# provider: bounded so a big backlog cannot turn a dry run into a timeout.
MAX_CONTACT_LOOKUPS = 300
SAMPLE_SIZE = 20
_REF_SALT = "retention-dry-run"


class RetentionDryRunSample(BaseModel):
    ref: str
    days_since_loss: int
    notice_due: int | None
    reachable: bool


class RetentionDryRunReport(BaseModel):
    dry_run: bool = True
    generated_at: datetime
    # False during the public test: nobody is without access, so the clock is
    # frozen and the job would do nothing.
    clock_running: bool
    accounts_without_plan: int = 0
    trial_running: int = 0
    # Trial over and no plan, split by whether day D has been stamped yet
    # (it is stamped the first time the account is seen after the trial).
    access_lost: int = 0
    clock_not_started: int = 0
    clock_started: int = 0
    developers_excluded: int = 0
    lookups_skipped: int = 0
    # Notices that would go out now, by day after D ("0", "30", ... "119").
    notices_due: dict[str, int] = Field(
        default_factory=lambda: {str(day): 0 for day in NOTICE_DAYS}
    )
    past_retention: int = 0
    # Erasable right now = 120 days over AND the "tomorrow" notice sent at
    # least 20 hours ago. No notice is recorded yet, so this is 0 by design.
    erasable_now: int = 0
    without_reachable_address: int = 0
    unverified_address: int = 0
    sample: list[RetentionDryRunSample] = Field(default_factory=list)


class RetentionDryRunService:
    def __init__(
        self,
        subscriptions: SubscriptionRepository,
        contacts: OwnerContactLookup,
        developer_emails: frozenset[str],
        *,
        test_plan: str | None = None,
    ) -> None:
        self._subscriptions = subscriptions
        self._contacts = contacts
        self._developer_emails = developer_emails
        self._test_plan = test_plan

    def execute(self, *, now: datetime | None = None) -> RetentionDryRunReport:
        now = now or utc_now()
        report = RetentionDryRunReport(generated_at=now, clock_running=self._test_plan is None)
        if self._test_plan is not None:
            return report

        lookups = 0
        for subscription in self._subscriptions.list_without_plan():
            report.accounts_without_plan += 1
            if subscription.is_trial_active(now=now):
                report.trial_running += 1
                continue

            report.access_lost += 1
            if subscription.access_lost_at is None:
                report.clock_not_started += 1
                continue

            if lookups >= MAX_CONTACT_LOOKUPS:
                report.lookups_skipped += 1
                continue
            lookups += 1
            contact = self._contacts.get(subscription.owner_id)
            email = contact.email.strip().lower() if contact and contact.email else None
            if email is not None and email in self._developer_emails:
                report.developers_excluded += 1
                continue

            report.clock_started += 1
            reachable = contact is not None and email is not None
            if not reachable:
                report.without_reachable_address += 1
            elif contact is not None and not contact.email_confirmed:
                report.unverified_address += 1

            started = subscription.access_lost_at
            notice = due_notice_day(started, now, last_notice_day=None)
            if notice is not None:
                report.notices_due[str(notice)] += 1
            if past_retention(started, now):
                report.past_retention += 1
            if erasure_allowed(started, now, last_notice_day=None, last_notice_at=None):
                report.erasable_now += 1
            if len(report.sample) < SAMPLE_SIZE:
                report.sample.append(
                    RetentionDryRunSample(
                        ref=reporter_ref(subscription.owner_id, _REF_SALT)[:8],
                        days_since_loss=days_since_loss(started, now),
                        notice_due=notice,
                        reachable=reachable,
                    )
                )
        return report
