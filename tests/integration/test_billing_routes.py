"""Billing routes end to end with store doubles (no network, no purchase)."""

from __future__ import annotations

from collections.abc import Iterator
from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.store import Store, StoreState, VerifiedStorePurchase
from packages.infrastructure.billing.fake_store import FakeStore

USER_A = "user-a"
USER_B = "user-b"


@pytest.fixture
def billing(monkeypatch: pytest.MonkeyPatch, request: pytest.FixtureRequest) -> Iterator[object]:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    monkeypatch.setenv("BILLING_ENABLED", "true")
    monkeypatch.setenv("BILLING_ACCOUNT_TOKEN_SECRET", "test-secret-not-real")
    monkeypatch.setenv("BILLING_STORE_ENVIRONMENT", "sandbox")
    request.getfixturevalue("adult_everyone")
    container = get_container()
    service = container.store_billing_service()
    assert service is not None
    apple = FakeStore()
    service._verifiers = {Store.APPLE: apple, Store.GOOGLE: FakeStore()}  # type: ignore[assignment]
    current = {"id": USER_A}
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=current["id"], email="owner@example.com"),
    )
    for owner in (USER_A, USER_B):
        container.subscription_repository.save(
            Subscription(owner_id=owner, trial_ends_at=utc_now() - timedelta(days=1))
        )

    def switch(user_id: str) -> None:
        current["id"] = user_id

    yield {"apple": apple, "service": service, "as": switch}


def _answer(env: dict[str, object], owner: str, store_id: str = "1000") -> None:
    service = env["service"]
    env["apple"].answers[store_id] = VerifiedStorePurchase(  # type: ignore[attr-defined]
        store=Store.APPLE,
        store_subscription_id=store_id,
        product_id="net.quokkapp.pro.monthly",
        state=StoreState.ACTIVE,
        expires_at=utc_now() + timedelta(days=30),
        auto_renew=True,
        environment="sandbox",
        account_token=service.account_token(owner),  # type: ignore[attr-defined]
    )


def test_verified_purchase_unlocks_and_user_b_cannot_claim_it(billing: dict[str, object]) -> None:
    client = TestClient(app)
    assert client.post("/pets", json={"name": "Milo", "species": "dog"}).status_code == 402
    token = client.get("/billing/account-token").json()["account_token"]
    assert len(token) == 36
    _answer(billing, USER_A)

    body = client.post(
        "/billing/purchases/verify", json={"store": "apple", "store_subscription_id": "1000"}
    ).json()
    assert body["complete_transaction"] is True
    assert body["status"]["has_access"] is True
    assert body["status"]["store_subscription"]["plan"] == "pro"

    billing["as"](USER_B)  # type: ignore[operator]
    stolen = client.post(
        "/billing/purchases/verify", json={"store": "apple", "store_subscription_id": "1000"}
    )
    assert stolen.status_code == 409
    assert stolen.json()["code"] == "purchase_owned_by_another_account"
    assert client.get("/subscription/status").json()["has_access"] is False


def test_forged_id_and_select_plan_grant_nothing(billing: dict[str, object]) -> None:
    client = TestClient(app)
    forged = client.post(
        "/billing/purchases/verify", json={"store": "apple", "store_subscription_id": "fake"}
    )
    assert forged.status_code == 422
    assert client.post("/subscription/select-plan", json={"plan": "ultra"}).status_code == 409
    assert client.get("/subscription/status").json()["has_access"] is False


def test_store_outage_answers_503_and_grants_nothing(billing: dict[str, object]) -> None:
    client = TestClient(app)
    _answer(billing, USER_A)
    billing["apple"].down = True  # type: ignore[attr-defined]
    response = client.post(
        "/billing/purchases/verify", json={"store": "apple", "store_subscription_id": "1000"}
    )
    assert response.status_code == 503
    assert client.get("/subscription/status").json()["has_access"] is False


def test_restore_route(billing: dict[str, object]) -> None:
    client = TestClient(app)
    _answer(billing, USER_A)
    body = client.post(
        "/billing/purchases/restore",
        json={"store": "apple", "store_subscription_ids": ["1000"]},
    ).json()
    assert body["restored"] == 1 and body["status"]["has_access"] is True


def test_unsigned_notifications_are_rejected(
    billing: dict[str, object], monkeypatch: pytest.MonkeyPatch
) -> None:
    client = TestClient(app)
    # Without Apple roots configured the route refuses everything.
    assert (
        client.post("/billing/apple/notifications", json={"signedPayload": "a.b.c"}).status_code
        == 503
    )
    monkeypatch.setenv("GOOGLE_PUBSUB_AUDIENCE", "aud")
    monkeypatch.setenv("GOOGLE_PUBSUB_SERVICE_ACCOUNT", "push@example.com")
    from packages.shared.config.settings import reset_settings

    reset_settings()
    get_container().settings = __import__(
        "packages.shared.config.settings", fromlist=["get_settings"]
    ).get_settings()
    assert client.post("/billing/google/notifications", json={"message": {}}).status_code == 403


def test_reconcile_requires_the_scheduler_secret(billing: dict[str, object]) -> None:
    client = TestClient(app)
    assert client.post("/billing/reconcile").status_code in (403, 503)


def test_admin_test_grant_is_refused_by_default(billing: dict[str, object]) -> None:
    client = TestClient(app)
    response = client.post("/admin/billing/test-grant", json={"owner_id": USER_A, "plan": "pro"})
    assert response.status_code in (403, 503)
    assert client.get("/subscription/status").json()["has_access"] is False


def test_billing_disabled_routes_answer_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("BILLING_ENABLED", "false")
    client = TestClient(app)
    assert client.get("/billing/account-token").status_code == 503
    assert client.get("/billing/catalog").json()["enabled"] is False
