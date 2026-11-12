from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.shared.errors.base import ValidationError


class SelectPlanInput(BaseModel):
    owner_id: str
    plan: str


class SelectPlanOutput(BaseModel):
    subscription: Subscription
    # False during the public test: nothing was saved.
    changed: bool = True
    test_period: bool = False


class SelectPlanService:
    """Records the plan the owner picked. During the public test
    ([test_plan] set) it changes nothing and says so: everyone is on the
    test plan and nobody chooses or pays."""

    def __init__(self, repository: SubscriptionRepository, test_plan: str | None = None) -> None:
        self._repository = repository
        self._test_plan = test_plan

    def execute(self, data: SelectPlanInput) -> SelectPlanOutput:
        if data.plan not in SubscriptionPlan.ALL:
            raise ValidationError(f"Unknown plan: {data.plan}")

        subscription = self._repository.get(data.owner_id) or Subscription(owner_id=data.owner_id)
        if self._test_plan is not None:
            return SelectPlanOutput(
                subscription=subscription.model_copy(update={"plan": self._test_plan}),
                changed=False,
                test_period=True,
            )

        updated = subscription.model_copy(update={"plan": data.plan})
        return SelectPlanOutput(subscription=self._repository.save(updated))
