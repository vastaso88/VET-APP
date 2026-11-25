from datetime import datetime

from pydantic import BaseModel, ConfigDict

from packages.core.domain.subscription.models import Subscription, SubscriptionPlan


class PlanLimits(BaseModel):
    """What one plan allows. The single source of the numbers: the app reads
    them from `/subscription/status`, it never keeps its own copy."""

    model_config = ConfigDict(frozen=True)

    max_pets: int
    max_chats_per_pet: int
    # Questions per day for the whole account (the owner's day).
    daily_questions: int
    # Questions per day inside ONE chat (conversation); None = no cap per chat, only the
    # account's. Pro 15, Ultra 20 (owner decision 2026-11-25); Plus has none. The
    # count is made by the server from the conversation it stores, never from what the app sends.
    daily_questions_per_chat: int | None = None
    # Messages per day that continue a topic already open (replies to the chat's own questions,
    # "this did not help me"). Kept as they were when the questions grew on 2026-11-25 (48 for Pro,
    # 90 for Ultra): three times the questions would have tripled what an account can cost.
    daily_follow_ups: int | None = None
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
        # 15 per chat, 40 for the account (owner decision 2026-11-25; it was 16 for the account).
        daily_questions=40,
        daily_questions_per_chat=15,
        daily_follow_ups=48,
        max_devices=3,
        daily_sonnet_answers=2,
        source=SubscriptionPlan.PRO,
    ),
    SubscriptionPlan.ULTRA: PlanLimits(
        max_pets=15,
        max_chats_per_pet=6,
        # 20 per chat, 80 for the account, 5 devices (owner decisions 2026-11-25; it was 30 and 3).
        daily_questions=80,
        daily_questions_per_chat=20,
        daily_follow_ups=90,
        max_devices=5,
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

# How many pets one owner may keep in Ricordi (owner decision 2026-11-16: pets in
# Ricordi do not count towards the plan's pets, so this is what bounds what an
# account can pile up there). The same for every plan, so not in PlanLimits. This
# is only the DEFAULT: the deployment sets the real number with MEMORIAL_PETS_MAX
# (packages/shared/config/settings.py); the backend writes it into the database
# for the rule on the app's direct writes (plan_access_config.max_memorial_pets)
# and reports it on /subscription/status, so the app keeps no copy of its own.
DEFAULT_MAX_MEMORIAL_PETS = 30

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
