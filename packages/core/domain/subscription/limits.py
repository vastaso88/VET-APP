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
    # Answers per day written by Claude Sonnet, the "older brother" that takes
    # over from Haiku when the owner is not satisfied with its answer (owner
    # decision 2026-11-10, plan "fratello maggiore"). Beyond it Haiku answers.
    # 0 = none. Counted on the owner's own day, like the questions.
    daily_sonnet_answers: int = 0
    # Where these limits come from: "plus", "pro", "ultra", "trial" (the free
    # trial, with Pro's allowances) or "none" (no access). Lets the chat tell
    # an owner at the limit which plan goes beyond it.
    source: str = "none"

    @property
    def upgrade_to(self) -> str | None:
        """The plan one step above, for an owner who has reached a limit; None
        for Ultra, and for the trial, which is not a plan to move up from."""
        return UPGRADE_PATH.get(self.source)


# The plan an owner at the limit is pointed to. The trial and Ultra have none.
UPGRADE_PATH: dict[str, str] = {
    SubscriptionPlan.PLUS: SubscriptionPlan.PRO,
    SubscriptionPlan.PRO: SubscriptionPlan.ULTRA,
}

LIMITS_BY_PLAN: dict[str, PlanLimits] = {
    SubscriptionPlan.PLUS: PlanLimits(
        max_pets=4,
        max_chats_per_pet=2,
        daily_questions=9,
        max_devices=2,
        daily_sonnet_answers=1,
        source=SubscriptionPlan.PLUS,
    ),
    SubscriptionPlan.PRO: PlanLimits(
        max_pets=8,
        max_chats_per_pet=4,
        daily_questions=16,
        max_devices=3,
        daily_sonnet_answers=2,
        source=SubscriptionPlan.PRO,
    ),
    SubscriptionPlan.ULTRA: PlanLimits(
        max_pets=15,
        max_chats_per_pet=6,
        daily_questions=30,
        max_devices=3,
        daily_sonnet_answers=3,
        source=SubscriptionPlan.ULTRA,
    ),
}

# The trial shows the product at its best: same allowances as Pro (and so is
# the public test, which reports everyone on Pro).
TRIAL_LIMITS = LIMITS_BY_PLAN[SubscriptionPlan.PRO].model_copy(update={"source": "trial"})

# Trial over and no plan: nothing can be created or asked, even by a route
# that forgot the access check.
NO_ACCESS_LIMITS = PlanLimits(
    max_pets=0, max_chats_per_pet=0, daily_questions=0, max_devices=1, source="none"
)

# Anti-spam on the Mercatino, the same for every plan (so not in PlanLimits): the
# conversations one buyer may open in 24 hours. Replies never count.
MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY = 10


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
