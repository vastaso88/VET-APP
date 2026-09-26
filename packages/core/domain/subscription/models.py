from datetime import datetime, timedelta

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now

TRIAL_DURATION = timedelta(days=10)


class SubscriptionPlan:
    """Plan keys the owner can pick once the trial ends. No pricing/payment
    processing here yet — see BillingDemoStore on the Flutter side."""

    FREE = "free"
    PLUS = "plus"
    PRO = "pro"

    ALL = frozenset({FREE, PLUS, PRO})


class Subscription(BaseModel):
    """Per-account trial/plan state. `plan` stays `None` while the owner is
    on the free trial; once set it never reverts to trial, even if the
    trial window is still open."""

    owner_id: str
    trial_ends_at: datetime = Field(default_factory=lambda: utc_now() + TRIAL_DURATION)
    plan: str | None = None
    created_at: datetime = Field(default_factory=utc_now)

    def is_trial_active(self, *, now: datetime | None = None) -> bool:
        return (now or utc_now()) < self.trial_ends_at

    def has_access(self, *, is_developer: bool, now: datetime | None = None) -> bool:
        """Developer allowlist accounts always have access; everyone else
        needs an active trial or a chosen plan (spec: 10 free days, no
        card, then a mandatory plan choice)."""
        if is_developer:
            return True
        return self.plan is not None or self.is_trial_active(now=now)
