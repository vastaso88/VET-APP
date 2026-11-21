"""Effective, server-authoritative feature quotas for subscribed accounts.

Admin toggles can disable a feature without losing its saved quota. Numeric
limits remain enforced by the existing service checks; the pet limit is also
enforced in Supabase SQL for direct Flutter writes.
"""

from __future__ import annotations

from packages.core.domain.subscription.limits import LIMITS_BY_PLAN, PlanLimits

FEATURE_KEYS = (
    "max_pets",
    "max_chats_per_pet",
    "daily_questions",
    "max_devices",
    "daily_sonnet_answers",
)


def configured_plan_limits(rows: list[dict[str, object]]) -> dict[str, PlanLimits]:
    """Strictly validate admin data. Missing rows use versioned defaults.

    Invalid complete rows are rejected rather than silently granting access.
    """
    values = {plan: limits.model_dump() for plan, limits in LIMITS_BY_PLAN.items()}
    seen: set[tuple[str, str]] = set()
    for row in rows:
        plan = row.get("plan")
        feature = row.get("feature")
        if not isinstance(plan, str) or not isinstance(feature, str):
            raise ValueError("Invalid pricing feature row")
        if plan not in values or feature not in FEATURE_KEYS or (plan, feature) in seen:
            raise ValueError("Invalid or duplicate pricing feature")
        seen.add((plan, feature))
        enabled, quota = row.get("enabled"), row.get("quota")
        if not isinstance(enabled, bool) or type(quota) is not int or not 0 <= quota <= 2000:
            raise ValueError("Invalid pricing feature quota")
        values[plan][feature] = quota if enabled else 0
    return {plan: PlanLimits.model_validate(value) for plan, value in values.items()}
