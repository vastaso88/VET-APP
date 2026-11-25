"""Rules that turn settings into container values: plan overrides, the test plan, the
memorial-pets cap and the answer models. Pure functions, no I/O. They log under the
container's own logger name, and `container.py` re-exports every name."""

import logging

from packages.core.domain.llm_usage.models import DEMO_MODEL
from packages.core.domain.subscription.limits import DEFAULT_MAX_MEMORIAL_PETS
from packages.core.domain.subscription.models import SubscriptionPlan
from packages.shared.config.settings import Settings

logger = logging.getLogger("packages.bootstrap.container")


def _parse_plan_overrides(raw: str) -> dict[str, str]:
    """ "email:plan,email:plan" -> {email: plan}; malformed or unknown plans
    are ignored (never a crash, never a plan that does not exist)."""
    result: dict[str, str] = {}
    for item in raw.split(","):
        email, _, plan = item.strip().rpartition(":")
        plan = plan.strip().lower()
        if email.strip() and plan in SubscriptionPlan.ALL:
            result[email.strip().lower()] = plan
    return result


def _resolve_subscription_test_plan(raw: str) -> str | None:
    """SUBSCRIPTION_TEST_PLAN as a plan key, or None for the normal behaviour.
    A value that is not a plan is ignored with a warning rather than refused:
    a typo must neither take the API down at start-up (a bad variable already
    did once, 2026-10-06) nor hand out a plan nobody asked for."""
    value = raw.strip().lower()
    if not value:
        return None
    if value not in SubscriptionPlan.ALL:
        logger.warning("SUBSCRIPTION_TEST_PLAN is not a plan: ignored (normal behaviour)")
        return None
    logger.warning(
        "SUBSCRIPTION_TEST_PLAN is set: every account is on the %s plan and nobody pays",
        value,
    )
    return value


def resolve_memorial_pets_max(raw: str) -> int:
    """MEMORIAL_PETS_MAX as a whole number above zero, or the default (30). A
    value that is not one is ignored with a warning rather than refused, for the
    same reason as SUBSCRIPTION_TEST_PLAN: a typo must not take the API down at
    start-up, and "no cap" by accident (0, a negative number) is the worse
    answer for a limit that bounds how much data an account can pile up."""
    value = raw.strip()
    if not value:
        return DEFAULT_MAX_MEMORIAL_PETS
    try:
        number = int(value)
    except ValueError:
        number = 0
    if number < 1:
        logger.warning("MEMORIAL_PETS_MAX is not a whole number above zero: default used")
        return DEFAULT_MAX_MEMORIAL_PETS
    return number


def answer_models(settings: Settings) -> list[str]:
    """The models an answer may come from, in order: what the budget
    checks before a turn is admitted."""
    return [settings.anthropic_model if settings.llm_provider == "anthropic" else DEMO_MODEL]
