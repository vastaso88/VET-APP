"""The scheduler route of the exit e-mails (QK-18): for the scheduler only, counts only, and
off by default: with sending off it touches nothing."""

from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.account_deletion.models import AccountDeletionRequest
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.store import (
    BillingPeriod,
    Store,
    StoreEntitlement,
    StoreState,
)

SECRET = "test-scheduler-secret"
HEADER = "X-VetApp-Scheduler"
ROUTE = "/admin/lifecycle/send-exit-notices"
OWNER = "11111111-1111-4111-8111-111111111111"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("ADMIN_SCHEDULER_SECRET", SECRET)
    return TestClient(app)


def _waiting_request() -> None:
    get_container().account_deletion_repository.create(
        AccountDeletionRequest(
            owner_id=OWNER,
            requested_at=utc_now() - timedelta(hours=1),
            purge_after=utc_now() + timedelta(days=30),
        )
    )


def test_only_the_scheduler_may_call_it(client: TestClient) -> None:
    assert client.post(ROUTE).status_code == 403
    assert client.post(ROUTE, headers={HEADER: "wrong"}).status_code == 403
    # A signed-in user's token is not the scheduler's.
    assert client.post(ROUTE, headers={"Authorization": "Bearer user-token"}).status_code == 403
    assert client.post(ROUTE, headers={"Authorization": "Bearer " + SECRET}).status_code == 403


def test_it_answers_with_numbers_only_and_sending_is_off_by_default(client: TestClient) -> None:
    _waiting_request()

    response = client.post(ROUTE, headers={HEADER: SECRET})

    assert response.status_code == 200
    body = response.json()
    assert body["sending_enabled"] is False and body["ready"] is False
    assert body["deletion"]["due"] == 1 and body["deletion"]["sent"] == 0
    assert body["deletion"]["blocked"] == "sending_off"
    text = str(body)
    for secret in ("@", OWNER, "Quokka", "account"):
        assert secret not in text
    # Nothing was written: the notice is still due for when sending is switched on.
    stored = get_container().account_deletion_repository.get(OWNER)
    assert stored is not None and stored.last_notice is None
    get_container().account_deletion_repository.delete(OWNER)


def _yearly_plan_that_renews_in_seven_days() -> None:
    get_container().store_entitlement_repository.save(
        StoreEntitlement(
            owner_id=OWNER,
            store=Store.GOOGLE,
            store_subscription_id="a-purchase-token",
            product_id="quokka_pro",
            plan="pro",
            period=BillingPeriod.YEARLY,
            state=StoreState.ACTIVE,
            expires_at=utc_now() + timedelta(days=7),
            auto_renew=True,
        )
    )


def test_the_reminder_of_the_yearly_renewals_is_in_the_same_run_and_off_by_default(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("BILLING_ENABLED", "true")
    monkeypatch.setenv("BILLING_ACCOUNT_TOKEN_SECRET", "test-secret-not-real")
    _yearly_plan_that_renews_in_seven_days()

    response = client.post(ROUTE, headers={HEADER: SECRET})

    body = response.json()
    assert response.status_code == 200
    assert (body["renewal"]["due"], body["renewal"]["sent"]) == (1, 0)
    assert body["renewal"]["blocked"] == "sending_off" and body["alarm"] == 0
    for secret in ("@", OWNER, "Quokka", "a-purchase-token"):
        assert secret not in str(body)


def test_with_store_billing_off_there_is_no_renewal_to_tell(client: TestClient) -> None:
    _yearly_plan_that_renews_in_seven_days()

    body = client.post(ROUTE, headers={HEADER: SECRET}).json()

    assert body["renewal"]["due"] == 0 and body["renewal"]["blocked"] is None


def test_the_restore_route_still_answers_when_the_security_message_cannot_go(
    client: TestClient,
) -> None:
    """R1 runs after the answer and never breaks it: with sending off it is simply skipped."""
    _waiting_request()
    response = client.post("/account/deletion/cancel")
    assert response.status_code == 200
    assert response.json()["pending"] is False
