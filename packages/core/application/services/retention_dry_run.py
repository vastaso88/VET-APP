"""Dry run of the data-retention job (owner decision 2026-11-08).

It answers "what would the job do right now?" and nothing else: it reads, it
counts, it never sends a message and never erases anything, and it has no
code path that could (the collaborators are read-only ports).
Sending and erasure stay off until Confirm email, a custom SMTP sender and
the Terms exist, and are built then.

For every account it also works out which e-mail it would get (service S, or
commercial P only with a consent in force and a declared adult) and which
kinds of data P would quote, from real counts (animals, reminders, records of
the medical record, walks); with nothing true to quote it gets S (rule 9). The sequence stops by
construction when the account chooses a plan: it is no longer listed. Having
downloaded the data does NOT stop it (owner decision of 2026-11-08; doc 12
says otherwise, flagged to the Orchestrator).

The report holds counts and a short sample of pseudonymous references: no
e-mail, no owner id, no name, no per-account number, so it can be read in a
log or by a scheduler.
"""

from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.application.ports.account_consents_repository import (
    AccountConsentsRepository,
)
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.services.account_data_counts import AccountDataCounter
from packages.core.domain.age.models import AgeBand, band_for
from packages.core.domain.common.entity import utc_now
from packages.core.domain.consent.models import AccountConsentType
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.core.domain.subscription.retention import (
    NOTICE_DAYS,
    days_since_loss,
    due_notice_day,
    erasure_allowed,
    past_retention,
)
from packages.core.domain.subscription.retention_notices import (
    COMMERCIAL,
    AccountDataCounts,
    NoticePlan,
    plan_notice,
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
    # "service" or "commercial", the sentence for a minor, {elenco_contenuti}
    # (the kinds of data the account really holds) and the counts the notice
    # would quote: kinds only, never the numbers.
    variant: str = "service"
    minor_note: bool = False
    contents: list[str] = Field(default_factory=list)
    counts_cited: list[str] = Field(default_factory=list)


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
    # Which e-mail each account would get.
    service_notices: int = 0
    commercial_notices: int = 0
    with_marketing_consent: int = 0
    # Age band from the declared date of birth (the backend's account_age
    # table). Without a declared adult age an account never gets the
    # commercial version. Accounts under 14 (closed, with their own 30-day
    # procedure) are counted here and nowhere else: no notice, no clock, no
    # erasure from this job.
    age_adult: int = 0
    age_under_minimum: int = 0
    age_minor: int = 0
    age_unknown: int = 0
    commercial_blocked_by_age: int = 0
    # Consent and adult age present, but nothing true to quote (no animals,
    # reminders, records or walks, or the counts could not be read): rule 9,
    # they get the service notice. Counted in service_notices too.
    downgraded_nothing_to_cite: int = 0
    counts_unavailable: int = 0
    sample: list[RetentionDryRunSample] = Field(default_factory=list)


class RetentionDryRunService:
    def __init__(
        self,
        subscriptions: SubscriptionRepository,
        contacts: OwnerContactLookup,
        developer_emails: frozenset[str],
        consents: AccountConsentsRepository,
        data_counter: AccountDataCounter,
        *,
        test_plan: str | None = None,
    ) -> None:
        self._subscriptions = subscriptions
        self._contacts = contacts
        self._developer_emails = developer_emails
        self._consents = consents
        self._data_counter = data_counter
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

            band = band_for(contact.birth_date if contact else None, now.date())
            if band == AgeBand.UNDER_MINIMUM:
                # Closed accounts (declared age under 14) follow their own
                # 30-day procedure: no notice, no clock, no erasure here.
                report.age_under_minimum += 1
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

            plan = self._plan(report, subscription.owner_id, notice, band)
            if len(report.sample) < SAMPLE_SIZE:
                report.sample.append(
                    RetentionDryRunSample(
                        ref=reporter_ref(subscription.owner_id, _REF_SALT)[:8],
                        days_since_loss=days_since_loss(started, now),
                        notice_due=notice,
                        reachable=reachable,
                        variant=plan.variant,
                        minor_note=plan.minor_note,
                        contents=plan.contents,
                        counts_cited=plan.counts_cited,
                    )
                )
        return report

    def _plan(
        self,
        report: RetentionDryRunReport,
        owner_id: str,
        notice: int | None,
        band: str,
    ) -> NoticePlan:
        """Which e-mail this account would get, and what it may quote."""
        if band == AgeBand.ADULT:
            report.age_adult += 1
        elif band == AgeBand.MINOR:
            report.age_minor += 1
        else:
            report.age_unknown += 1

        consent = self._marketing_consent(owner_id)
        if consent:
            report.with_marketing_consent += 1
            if band != AgeBand.ADULT:
                report.commercial_blocked_by_age += 1

        # Counts are read only for accounts that would get the commercial
        # text, the only one that quotes them.
        counts: AccountDataCounts | None = None
        if consent and band == AgeBand.ADULT:
            counts = self._data_counter.count(owner_id)
            if counts is None:
                report.counts_unavailable += 1

        plan = plan_notice(
            notice if notice is not None else NOTICE_DAYS[0],
            marketing_consent=consent,
            age_band=band,
            counts=counts,
        )
        if plan.variant == COMMERCIAL:
            report.commercial_notices += 1
        else:
            report.service_notices += 1
        if plan.nothing_to_cite:
            report.downgraded_nothing_to_cite += 1
        return plan

    def _marketing_consent(self, owner_id: str) -> bool:
        """A commercial consent in force: the latest decision is "granted".
        Anything unreadable counts as no consent."""
        try:
            record = self._consents.get(owner_id)
        except Exception:  # noqa: BLE001 - when in doubt, no commercial e-mail
            return False
        if record is None:
            return False
        decision = record.consents.get(AccountConsentType.MARKETING_EMAIL)
        return decision is not None and decision.granted
