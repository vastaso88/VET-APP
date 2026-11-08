"""The retention pieces reachable over HTTP: the status field and the dry-run
route. The route is for the scheduler only (shared secret, no user session)."""

from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription

OWNER = "demo-user"
SECRET = "test-scheduler-secret"
HEADER = "X-VetApp-Scheduler"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    monkeypatch.setenv("ADMIN_SCHEDULER_SECRET", SECRET)
    return TestClient(app)


def _expire_the_trial() -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=OWNER, trial_ends_at=utc_now() - timedelta(days=1))
    )


# --- the status field -------------------------------------------------------


def test_status_has_no_retention_date_while_the_account_has_access(client: TestClient) -> None:
    body = client.get("/subscription/status").json()

    assert body["has_access"] is True
    assert body["data_kept_until"] is None


def test_status_gives_the_date_the_data_is_kept_until_after_the_trial(
    client: TestClient,
) -> None:
    _expire_the_trial()

    body = client.get("/subscription/status").json()

    assert body["has_access"] is False
    assert body["data_kept_until"] is not None
    stored = get_container().subscription_repository.get(OWNER)
    assert stored is not None and stored.access_lost_at is not None
    # The status answers with the same instant it stored, plus four months.
    assert body["data_kept_until"].startswith(
        (stored.access_lost_at + timedelta(days=120)).strftime("%Y-%m-%dT%H:%M")
    )


def test_the_status_date_disappears_when_a_plan_is_chosen(client: TestClient) -> None:
    _expire_the_trial()
    client.get("/subscription/status")

    stored = get_container().subscription_repository.get(OWNER)
    assert stored is not None
    get_container().subscription_repository.save(stored.model_copy(update={"plan": "plus"}))
    body = client.get("/subscription/status").json()

    assert body["has_access"] is True
    assert body["data_kept_until"] is None


# --- the dry-run route ------------------------------------------------------


def test_the_dry_run_refuses_a_call_without_the_token(client: TestClient) -> None:
    assert client.post("/admin/lifecycle/dry-run").status_code == 403


def test_the_dry_run_refuses_a_wrong_token(client: TestClient) -> None:
    response = client.post("/admin/lifecycle/dry-run", headers={HEADER: "not-the-secret"})

    assert response.status_code == 403


def test_a_user_session_alone_is_not_enough(client: TestClient) -> None:
    """The ordinary user token (here the bootstrap user) opens nothing."""
    _expire_the_trial()

    response = client.post("/admin/lifecycle/dry-run", headers={"Authorization": "Bearer x"})

    assert response.status_code == 403


def test_the_dry_run_reports_counts_and_changes_nothing(client: TestClient) -> None:
    _expire_the_trial()
    client.get("/subscription/status")  # starts the clock
    repository = get_container().subscription_repository
    before = repository.get(OWNER)

    response = client.post("/admin/lifecycle/dry-run", headers={HEADER: SECRET})

    assert response.status_code == 200
    body = response.json()
    assert body["dry_run"] is True
    assert body["clock_running"] is True
    assert body["accounts_without_plan"] == 1
    assert body["erasable_now"] == 0
    # No registration records a date of birth yet: the safe, service notice.
    assert body["age_unknown"] == 1
    assert body["service_notices"] == 1
    assert body["commercial_notices"] == 0
    assert repository.get(OWNER) == before


def test_the_dry_run_response_holds_no_personal_data(client: TestClient) -> None:
    _expire_the_trial()
    client.get("/subscription/status")

    text = client.post("/admin/lifecycle/dry-run", headers={HEADER: SECRET}).text

    assert OWNER not in text
    assert "@" not in text
