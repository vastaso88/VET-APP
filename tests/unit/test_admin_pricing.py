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


def test_feature_update_requires_six_digit_totp() -> None:
    from pydantic import ValidationError
    from apps.api.routes.admin_pricing import FeatureUpdate

    with pytest.raises(ValidationError):
        FeatureUpdate(
            plan="plus", feature="max_pets", enabled=False, quota=4, totp_code="123"
        )


def test_price_update_rejects_negative_or_unbounded_amount() -> None:
    from pydantic import ValidationError
    from apps.api.routes.admin_pricing import PriceUpdate

    for value in (-1, 100_000_001):
        with pytest.raises(ValidationError):
            PriceUpdate(
                country_code="IT", store="apple", plan="plus",
                period="monthly", currency="EUR", amount_minor=value,
                totp_code="123456",
            )


def test_pricing_feature_save_sends_digest_not_totp_to_database(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from types import SimpleNamespace

    from apps.api.routes import admin_pricing

    calls: list[tuple[str, dict[str, object]]] = []

    class Client:
        def rpc(self, name: str, data: dict[str, object]) -> "Client":
            calls.append((name, data))
            return self

        def execute(self) -> object:
            return SimpleNamespace(data=True)

    monkeypatch.setattr(
        admin_pricing, "_require_admin",
        lambda: SimpleNamespace(id="00000000-0000-4000-8000-000000000001"),
    )
    monkeypatch.setattr(admin_pricing, "_admin_client", Client)
    monkeypatch.setattr(admin_pricing, "_verify_plan_totp", lambda _admin, _code: "a" * 64)

    request = admin_pricing.FeatureUpdate(
        plan="plus", feature="max_pets", enabled=False, quota=4, totp_code="123456",
    )
    assert admin_pricing.save_feature(request) == {"saved": True}
    assert [name for name, _ in calls] == [
        "admin_plan_totp_register_attempt", "admin_pricing_save_feature",
    ]
    assert calls[-1][1]["p_code_digest"] == "a" * 64
    assert "123456" not in repr(calls[-1])


def test_pricing_save_stops_after_invalid_totp(monkeypatch: pytest.MonkeyPatch) -> None:
    from types import SimpleNamespace

    from fastapi import HTTPException
    from apps.api.routes import admin_pricing

    calls: list[str] = []

    class Client:
        def rpc(self, name: str, data: dict[str, object]) -> "Client":
            calls.append(name)
            return self

        def execute(self) -> object:
            return SimpleNamespace(data=True)

    def invalid_code(_admin: str, _code: str) -> str:
        raise HTTPException(status_code=400, detail="Invalid TOTP code")

    monkeypatch.setattr(
        admin_pricing, "_require_admin",
        lambda: SimpleNamespace(id="00000000-0000-4000-8000-000000000001"),
    )
    monkeypatch.setattr(admin_pricing, "_admin_client", Client)
    monkeypatch.setattr(admin_pricing, "_verify_plan_totp", invalid_code)
    with pytest.raises(HTTPException) as exc:
        admin_pricing.save_feature(admin_pricing.FeatureUpdate(
            plan="plus", feature="daily_questions", enabled=True,
            quota=9, totp_code="123456",
        ))
    assert exc.value.status_code == 400
    assert calls == ["admin_plan_totp_register_attempt"]
