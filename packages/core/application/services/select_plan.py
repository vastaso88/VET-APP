from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.shared.errors.base import ValidationError


class SelectPlanInput(BaseModel):
    owner_id: str
    plan: str


class SelectPlanOutput(BaseModel):
    subscription: Subscription


class SelectPlanService:
    def __init__(self, repository: SubscriptionRepository) -> None:
        self._repository = repository

    def execute(self, data: SelectPlanInput) -> SelectPlanOutput:
        if data.plan not in SubscriptionPlan.ALL:
            raise ValidationError(f"Unknown plan: {data.plan}")

        subscription = self._repository.get(data.owner_id) or Subscription(owner_id=data.owner_id)
        updated = subscription.model_copy(update={"plan": data.plan})
        return SelectPlanOutput(subscription=self._repository.save(updated))
