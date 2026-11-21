"""Admin-configured plan features: disabled means zero entitlement."""
from __future__ import annotations

import pytest

from packages.core.domain.subscription.limits import LIMITS_BY_PLAN
from packages.core.domain.subscription.pricing import configured_plan_limits


def test_disabling_a_feature_only_affects_its_plan() -> None:
    result = configured_plan_limits([
        {"plan": "plus", "feature": "daily_questions", "enabled": False, "quota": 9},
        {"plan": "pro", "feature": "max_pets", "enabled": True, "quota": 10},
    ])
    assert result["plus"].daily_questions == 0
    assert result["plus"].max_pets == 4
    assert result["pro"].max_pets == 10
    assert result["ultra"] == LIMITS_BY_PLAN["ultra"]


def test_a_disabled_feature_keeps_its_saved_quota_for_reactivation() -> None:
    result = configured_plan_limits([
        {"plan": "ultra", "feature": "daily_sonnet_answers", "enabled": False, "quota": 3},
    ])
    assert result["ultra"].daily_sonnet_answers == 0


@pytest.mark.parametrize("row", [
    {"plan": "plus", "feature": "daily_questions", "enabled": "true", "quota": 9},
    {"plan": "plus", "feature": "daily_questions", "enabled": True, "quota": True},
    {"plan": "plus", "feature": "daily_questions", "enabled": True, "quota": -1},
    {"plan": "plus", "feature": "daily_questions", "enabled": True, "quota": 2001},
    {"plan": "plus", "feature": "unsupported", "enabled": True, "quota": 5},
    {"plan": "enterprise", "feature": "max_pets", "enabled": True, "quota": 3},
])
def test_invalid_rows_never_create_entitlements(row: dict[str, object]) -> None:
    with pytest.raises(ValueError):
        configured_plan_limits([row])


def test_duplicate_feature_rows_rejected() -> None:
    row = {"plan": "pro", "feature": "max_pets", "enabled": True, "quota": 8}
    with pytest.raises(ValueError):
        configured_plan_limits([row, row])


def test_plan_specific_trial_limits_use_configured_pro_values() -> None:
    from packages.core.domain.subscription.limits import effective_limits
    from packages.core.domain.subscription.models import Subscription

    quotas = configured_plan_limits([
        {"plan": "pro", "feature": "daily_questions", "enabled": False, "quota": 16}
    ])
    trial = effective_limits(Subscription(owner_id="test"), is_developer=False, plan_limits=quotas)
    assert trial is not None
    assert trial.source == "trial"
    assert trial.daily_questions == 0
