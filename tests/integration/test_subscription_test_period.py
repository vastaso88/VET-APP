"""The public test (SUBSCRIPTION_TEST_PLAN): everyone on the test plan while the
variable is set, and exactly the normal behaviour without it. Nothing a request
carries can switch it on."""

from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.limits import LIMITS_BY_PLAN, NO_ACCESS_LIMITS
from packages.core.domain.subscription.models import Subscription
from packages.shared.config.settings import Settings

OWNER = "demo-user"


def _expire_the_trial() -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=OWNER, trial_ends_at=utc_now() - timedelta(days=1))
    )


@pytest.fixture
def normal(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    """The switch off. An empty value beats whatever a local .env says."""
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    return TestClient(app)


@pytest.fixture
def test_period(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "pro")
    return TestClient(app)


# --- without the switch nothing changes -------------------------------------


def test_without_the_switch_a_new_account_is_on_the_trial(normal: TestClient) -> None:
    body = normal.get("/subscription/status").json()

    assert body["test_period"] is False
    assert body["subscription"]["plan"] is None
    assert body["has_access"] is True


def test_without_the_switch_an_expired_account_has_no_access_and_no_plan(
    normal: TestClient,
) -> None:
    _expire_the_trial()

    body = normal.get("/subscription/status").json()

    assert body["test_period"] is False
    assert body["subscription"]["plan"] is None
    assert body["has_access"] is False
    assert body["limits"] == NO_ACCESS_LIMITS.model_dump()


def test_without_the_switch_the_functions_answer_402_after_the_trial(normal: TestClient) -> None:
    _expire_the_trial()

    response = normal.post("/pets", json={"name": "Milo", "species": "dog"})

    assert response.status_code == 402
    assert response.json()["code"] == "subscription_required"


def test_without_the_switch_choosing_a_plan_is_saved(normal: TestClient) -> None:
    _expire_the_trial()

    body = normal.post("/subscription/select-plan", json={"plan": "plus"}).json()

    assert body["changed"] is True
    assert body["test_period"] is False
    assert "message" not in body
    assert get_container().subscription_repository.get(OWNER).plan == "plus"  # type: ignore[union-attr]
    assert normal.get("/subscription/status").json()["has_access"] is True


def test_an_unset_variable_is_the_normal_behaviour(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SUBSCRIPTION_TEST_PLAN", raising=False)

    assert Settings(_env_file=None).subscription_test_plan == ""  # type: ignore[call-arg]


def test_a_value_that_is_not_a_plan_is_ignored(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "gold")
    client = TestClient(app)
    _expire_the_trial()

    body = client.get("/subscription/status").json()

    assert body["test_period"] is False
    assert body["has_access"] is False


# --- with the switch ---------------------------------------------------------


def test_with_the_switch_an_expired_account_is_on_the_test_plan(test_period: TestClient) -> None:
    _expire_the_trial()

    body = test_period.get("/subscription/status").json()

    assert body["test_period"] is True
    assert body["subscription"]["plan"] == "pro"
    assert body["has_access"] is True
    assert body["limits"] == LIMITS_BY_PLAN["pro"].model_dump()


def test_the_switch_is_read_without_caring_for_case_or_spaces(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "  Pro ")

    body = TestClient(app).get("/subscription/status").json()

    assert body["test_period"] is True
    assert body["subscription"]["plan"] == "pro"


def test_the_test_plan_is_reported_but_never_saved(test_period: TestClient) -> None:
    _expire_the_trial()

    test_period.get("/subscription/status")

    stored = get_container().subscription_repository.get(OWNER)
    assert stored is not None
    assert stored.plan is None, "ending the test must put every account back where it was"


def test_with_the_switch_the_functions_open_after_the_trial(test_period: TestClient) -> None:
    _expire_the_trial()

    response = test_period.post("/pets", json={"name": "Milo", "species": "dog"})

    assert response.status_code == 200


def test_with_the_switch_the_limits_are_those_of_the_test_plan(test_period: TestClient) -> None:
    _expire_the_trial()
    pro = LIMITS_BY_PLAN["pro"]

    for index in range(pro.max_pets):
        assert (
            test_period.post("/pets", json={"name": f"P{index}", "species": "dog"}).status_code
            == 200
        )

    refused = test_period.post("/pets", json={"name": "Un altro", "species": "dog"})
    assert refused.status_code == 403
    assert refused.json()["code"] == "plan_limit_reached"


def test_with_the_switch_choosing_a_plan_changes_nothing_and_says_so(
    test_period: TestClient,
) -> None:
    _expire_the_trial()

    response = test_period.post("/subscription/select-plan", json={"plan": "ultra"})

    body = response.json()
    assert response.status_code == 200
    assert body["changed"] is False
    assert body["test_period"] is True
    assert body["code"] == "subscription_test_period"
    assert "nessuno paga" in body["message"]
    assert body["subscription"]["plan"] == "pro"
    stored = get_container().subscription_repository.get(OWNER)
    assert stored is not None and stored.plan is None


def test_a_bad_plan_is_still_refused_during_the_test(test_period: TestClient) -> None:
    response = test_period.post("/subscription/select-plan", json={"plan": "gold"})

    assert response.status_code == 400


# --- nothing from the app can switch it on ---------------------------------


def test_no_request_can_turn_the_switch_on(normal: TestClient) -> None:
    _expire_the_trial()
    sneaky = {"X-Test-Plan": "pro", "X-Subscription-Test-Plan": "pro", "X-Debug": "1"}
    params = {"test_plan": "pro", "SUBSCRIPTION_TEST_PLAN": "pro", "test_period": "true"}

    status = normal.get("/subscription/status", params=params, headers=sneaky).json()
    pets = normal.post(
        "/pets",
        params=params,
        headers=sneaky,
        json={"name": "M", "species": "dog", "test_plan": "pro"},
    )

    assert status["test_period"] is False
    assert status["subscription"]["plan"] is None
    assert status["has_access"] is False
    assert pets.status_code == 402


def test_choosing_a_plan_with_extra_fields_saves_only_the_plan_asked_for(
    normal: TestClient,
) -> None:
    _expire_the_trial()

    body = normal.post(
        "/subscription/select-plan",
        params={"test_plan": "pro"},
        headers={"X-Test-Plan": "pro"},
        json={"plan": "plus", "test_plan": "pro", "test_period": True},
    ).json()

    assert body["test_period"] is False
    assert body["changed"] is True
    assert get_container().subscription_repository.get(OWNER).plan == "plus"  # type: ignore[union-attr]
