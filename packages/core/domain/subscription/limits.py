from datetime import datetime

from pydantic import BaseModel, ConfigDict

from packages.core.domain.subscription.models import Subscription, SubscriptionPlan


class PlanLimits(BaseModel):
    """What one plan allows. The single source of the numbers: the app reads
    them from `/subscription/status`, it never keeps its own copy."""

    model_config = ConfigDict(frozen=True)

    max_pets: int
    max_chats_per_pet: int
    daily_questions: int
    max_devices: int


LIMITS_BY_PLAN: dict[str, PlanLimits] = {
    SubscriptionPlan.PLUS: PlanLimits(
        max_pets=3, max_chats_per_pet=2, daily_questions=8, max_devices=2
    ),
    SubscriptionPlan.PRO: PlanLimits(
        max_pets=6, max_chats_per_pet=4, daily_questions=15, max_devices=3
    ),
    SubscriptionPlan.ULTRA: PlanLimits(
        max_pets=15, max_chats_per_pet=6, daily_questions=30, max_devices=3
    ),
}

# The trial shows the product at its best: same allowances as Pro.
TRIAL_LIMITS = LIMITS_BY_PLAN[SubscriptionPlan.PRO]

# Trial over and no plan: nothing can be created or asked, even by a route
# that forgot the access check.
NO_ACCESS_LIMITS = PlanLimits(max_pets=0, max_chats_per_pet=0, daily_questions=0, max_devices=1)


def effective_limits(
    subscription: Subscription, *, is_developer: bool, now: datetime | None = None
) -> PlanLimits | None:
    """The limits that apply to [subscription] right now; `None` means no
    limits (developer allowlist)."""
    if is_developer:
        return None
    if subscription.plan is not None:
        return LIMITS_BY_PLAN[subscription.plan]
    if subscription.is_trial_active(now=now):
        return TRIAL_LIMITS
    return NO_ACCESS_LIMITS
