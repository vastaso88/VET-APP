from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    PlanLimits,
    effective_limits,
)
from packages.core.domain.subscription.models import Subscription


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


class GetOrCreateSubscriptionService:
    """Starts the 14-day free trial (spec: no card required) on first
    lookup, and reports whether the owner currently has access — always
    true for the developer allowlist, otherwise trial-or-plan.

    [test_plan] is the deployment's public-test switch: when it names a
    plan, every owner is reported on that plan with access and its limits,
    whatever the stored row says. It is only reported, never saved, so
    switching the test off puts every account back exactly where it was."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        developer_emails: frozenset[str],
        test_plan: str | None = None,
    ) -> None:
        self._repository = repository
        self._developer_emails = developer_emails
        self._test_plan = test_plan

    def execute(self, data: GetOrCreateSubscriptionInput) -> GetOrCreateSubscriptionOutput:
        subscription = self._repository.get(data.owner_id)
        if subscription is None:
            subscription = self._repository.save(Subscription(owner_id=data.owner_id))

        is_developer = data.email.strip().lower() in self._developer_emails

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
            has_access=subscription.has_access(is_developer=is_developer),
            limits=effective_limits(subscription, is_developer=is_developer),
        )
