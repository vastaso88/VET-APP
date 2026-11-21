import logging

from pydantic import BaseModel

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.subscription.limits import LIMITS_BY_PLAN
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.shared.errors.base import ValidationError

logger = logging.getLogger(__name__)


class PlanRequiresStorePurchaseError(Exception):
    """A paid plan comes only from a verified App Store / Google Play
    subscription (StoreBillingService), never from a plain request."""


class SelectPlanInput(BaseModel):
    owner_id: str
    plan: str


class PetsOverLimit(BaseModel):
    """The owner has more pets than the plan they chose has places for."""

    count: int
    limit: int
    plan: str


class SelectPlanOutput(BaseModel):
    subscription: Subscription
    # False during the public test: nothing was saved.
    changed: bool = True
    test_period: bool = False
    # Set when the new plan has fewer places than the owner has pets. The change goes
    # through all the same (nothing is deleted or moved, Terms it/03 §4): new pets are
    # held back until the owner has fewer than the limit. The app asks before choosing;
    # a client that does not ask learns it here.
    pets_over_limit: PetsOverLimit | None = None


class SelectPlanService:
    """Public `/subscription/select-plan`. It never grants a plan:

    - during the public test ([test_plan] set) it changes nothing and says so;
    - otherwise it refuses: the owner buys through the store and the backend
      grants the plan only after verifying the purchase.

    Team test grants live in StoreBillingService.grant_admin_test behind the
    admin route, completely separate from this flow."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        test_plan: str | None = None,
        pets: PetProfileRepository | None = None,
    ) -> None:
        self._repository = repository
        self._test_plan = test_plan
        self._pets = pets

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
        raise PlanRequiresStorePurchaseError(data.plan)

    def pets_over_limit(self, owner_id: str, plan: str) -> PetsOverLimit | None:
        """Whether [plan] has fewer places than the owner has pets. Asked after a
        verified store purchase (/billing/purchases/verify). Best effort: the plan
        is already granted, a failed count must not undo it."""
        if self._pets is None:
            return None
        try:
            # Pets kept in Ricordi take no place of the plan (owner decision 2026-11-16)
            # once the profile carries the flag; until then every pet counts.
            count = sum(
                1
                for pet in self._pets.list_by_owner(owner_id)
                if not getattr(pet, "is_memorial", False)
            )
        except Exception:  # noqa: BLE001 - the plan change must not fail on a count
            logger.warning("could not count the pets for a plan change", exc_info=False)
            return None
        limit = LIMITS_BY_PLAN[plan].max_pets
        return PetsOverLimit(count=count, limit=limit, plan=plan) if count > limit else None
