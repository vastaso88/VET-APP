import logging
from datetime import datetime

from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    PlanLimits,
    effective_limits,
)
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.retention import data_kept_until

logger = logging.getLogger(__name__)


class GetOrCreateSubscriptionInput(BaseModel):
    owner_id: str
    email: str


class GetOrCreateSubscriptionOutput(BaseModel):
    subscription: Subscription
    is_developer: bool
    has_access: bool
    # What this owner is allowed right now; None = no limits (developer).
    limits: PlanLimits | None = None
    # The limits of every plan, so the app shows the same numbers the
    # backend enforces without keeping a copy of them.
    plan_limits: dict[str, PlanLimits] = LIMITS_BY_PLAN
    # True while the deployment runs a public test (SUBSCRIPTION_TEST_PLAN):
    # the plan above is the test plan, not something the owner chose or paid.
    test_period: bool = False
    # Only for an owner whose access is over: when their data is erased if
    # nothing changes (four months after the access was lost). None otherwise.
    data_kept_until: datetime | None = None


class GetOrCreateSubscriptionService:
    """Starts the 14-day free trial (spec: no card required) on first
    lookup, and reports whether the owner currently has access — always
    true for the developer allowlist, otherwise trial-or-plan.

    [test_plan] is the deployment's public-test switch: when it names a
    plan, every owner is reported on that plan with access and its limits,
    whatever the stored row says. The plan is only reported, never saved, so
    switching the test off puts every account back exactly where it was.

    It also keeps the retention clock (retention.py): the first time an
    account is seen without access its day D is stamped, and it is cleared
    when the account has access again. During the public test nobody is
    without access, so the clock is cleared and does not run; the end of the
    test starts it afresh."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        developer_emails: frozenset[str],
        test_plan: str | None = None,
        access_sync: PlanAccessSync | None = None,
    ) -> None:
        self._repository = repository
        self._developer_emails = developer_emails
        self._test_plan = test_plan
        # Tells the database rules on the app's direct writes the two facts
        # only the backend knows (scripts/setup/plan_access_rules.sql).
        self._access_sync = access_sync

    def execute(self, data: GetOrCreateSubscriptionInput) -> GetOrCreateSubscriptionOutput:
        subscription = self._repository.get(data.owner_id)
        if subscription is None:
            subscription = self._repository.save(Subscription(owner_id=data.owner_id))

        is_developer = data.email.strip().lower() in self._developer_emails
        if self._access_sync is not None:
            self._access_sync.sync(
                owner_id=data.owner_id, is_developer=is_developer, test_plan=self._test_plan
            )
        has_access = subscription.has_access(is_developer=is_developer)
        subscription = self._keep_retention_clock(
            subscription, without_access=not has_access and self._test_plan is None
        )

        if self._test_plan is not None:
            reported = subscription.model_copy(update={"plan": self._test_plan})
            return GetOrCreateSubscriptionOutput(
                subscription=reported,
                is_developer=is_developer,
                has_access=True,
                limits=effective_limits(reported, is_developer=is_developer),
                test_period=True,
            )

        return GetOrCreateSubscriptionOutput(
            subscription=subscription,
            is_developer=is_developer,
            has_access=has_access,
            limits=effective_limits(subscription, is_developer=is_developer),
            data_kept_until=(
                data_kept_until(subscription.access_lost_at)
                if not has_access and subscription.access_lost_at is not None
                else None
            ),
        )

    def _keep_retention_clock(
        self, subscription: Subscription, *, without_access: bool
    ) -> Subscription:
        """Stamps day D when the account is first seen without access and
        clears it when it has access again. Best effort: this bookkeeping
        never decides access, so a failure (the column may not exist yet) is
        logged and the account is treated exactly as before."""
        try:
            if without_access and subscription.access_lost_at is None:
                now = utc_now()
                self._repository.set_access_lost_at(subscription.owner_id, now)
                return subscription.model_copy(update={"access_lost_at": now})
            if not without_access and subscription.access_lost_at is not None:
                self._repository.set_access_lost_at(subscription.owner_id, None)
                return subscription.model_copy(update={"access_lost_at": None})
        except Exception:  # noqa: BLE001 - bookkeeping must not decide access
            logger.warning("could not update the retention clock of an account", exc_info=False)
        return subscription
