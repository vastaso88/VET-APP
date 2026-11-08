from datetime import datetime, timedelta

from pydantic import BaseModel, Field, field_validator

from packages.core.domain.common.entity import utc_now

TRIAL_DURATION = timedelta(days=14)


class SubscriptionPlan:
    """Plan keys the owner can pick once the trial ends (there is no free
    plan: after the trial an owner without a plan only reaches their own
    data). No pricing/payment processing here yet — see BillingDemoStore on
    the Flutter side."""

    PLUS = "plus"
    PRO = "pro"
    ULTRA = "ultra"

    ALL = frozenset({PLUS, PRO, ULTRA})


class Subscription(BaseModel):
    """Per-account trial/plan state. `plan` stays `None` while the owner is
    on the free trial; once set it never reverts to trial, even if the
    trial window is still open."""

    owner_id: str
    trial_ends_at: datetime = Field(default_factory=lambda: utc_now() + TRIAL_DURATION)
    plan: str | None = None
    created_at: datetime = Field(default_factory=utc_now)
    # The day D the account was first seen without access (retention.py): the
    # start of the four months its data is kept. Set and cleared only through
    # `SubscriptionRepository.set_access_lost_at`, never by `save`.
    access_lost_at: datetime | None = None

    @field_validator("plan", mode="before")
    @classmethod
    def _unknown_plan_is_no_plan(cls, value: object) -> object:
        """Rows saved when a "free" plan existed (or any key that is not a
        current plan) read as "no plan": trial if it is still open, expired
        otherwise. Reading them must never fail."""
        if value is None or value in SubscriptionPlan.ALL:
            return value
        return None

    def is_trial_active(self, *, now: datetime | None = None) -> bool:
        return (now or utc_now()) < self.trial_ends_at

    def has_access(self, *, is_developer: bool, now: datetime | None = None) -> bool:
        """Developer allowlist accounts always have access; everyone else
        needs an active trial or a chosen plan (spec: 14 free days, no
        card, then a mandatory plan choice)."""
        if is_developer:
            return True
        return self.plan is not None or self.is_trial_active(now=now)
