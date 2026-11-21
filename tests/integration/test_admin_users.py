"""Synthetic local accounts only: permission boundaries and truthful plan reporting."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.shared.errors.base import AuthenticationError

PATH = "/admin/users"


@pytest.fixture
def portal(monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, Mock]:
    monkeypatch.setattr(
        "apps.api.routes.admin._configured_admin_emails",
        lambda: frozenset({"admin@example.com"}),
    )
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(id="admin", email="admin@example.com", email_verified=True),
    )
    client = Mock()
    client.auth.admin.list_users.return_value = []
    monkeypatch.setattr("apps.api.routes.admin_users._admin_client", lambda: client)
    return TestClient(app), client


def account(user_id: str, **kwargs: Any) -> SimpleNamespace:
    return SimpleNamespace(
        id=user_id,
        email=f"{user_id}@example.com",
        created_at=datetime(2026, 1, 1, tzinfo=UTC),
        **kwargs,
    )


@pytest.mark.parametrize("verified", [True, False])
def test_non_admin_cannot_list_other_accounts(
    portal: tuple[TestClient, Mock],
    monkeypatch: pytest.MonkeyPatch,
    verified: bool,
) -> None:
    browser, client = portal
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(id="b", email="b@example.com", email_verified=verified),
    )
    assert browser.get(PATH).status_code == 403
    client.auth.admin.list_users.assert_not_called()


def test_unverified_admin_is_denied(
    portal: tuple[TestClient, Mock],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(id="admin", email="admin@example.com", email_verified=False),
    )
    assert portal[0].get(PATH).status_code == 403


def test_unauthenticated_is_denied(
    portal: tuple[TestClient, Mock],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def unauthenticated() -> None:
        raise AuthenticationError("Authentication required")

    monkeypatch.setattr(get_container().auth_provider, "get_current_user", unauthenticated)
    assert portal[0].get(PATH).status_code == 401


def test_search_pagination_and_accounts_without_subscriptions(
    portal: tuple[TestClient, Mock],
) -> None:
    browser, client = portal
    client.auth.admin.list_users.return_value = [account("a"), account("b"), account("c")]
    query = client.table.return_value.select.return_value.in_.return_value
    query.execute.return_value = SimpleNamespace(data=[])
    body = browser.get(PATH, params={"page": 2, "page_size": 1}).json()
    assert body["total"] == 3
    assert [user["id"] for user in body["users"]] == ["b"]
    client.table.return_value.select.return_value.in_.assert_called_with("owner_id", ["b"])
    user = body["users"][0]
    assert user["access"] == "not_started"
    assert user["trial_ends_at"] is None
    assert user["total_paid_minor"] is None
    assert not body["payments_available"]
    body = browser.get(PATH, params={"q": "A@EXAMPLE", "page": 99}).json()
    assert body["total"] == 1 and body["page"] == 1
    assert body["users"][0]["id"] == "a"
    assert browser.get(PATH, params={"q": "not-found"}).json()["users"] == []
    client.table.return_value.insert.assert_not_called()
    client.table.return_value.upsert.assert_not_called()


@pytest.mark.parametrize(
    ("plan", "days", "test_plan", "developer", "expected"),
    [
        (None, 3, None, False, "trial"),
        (None, -3, None, False, "expired"),
        ("plus", -3, None, False, "plan"),
        ("legacy", -3, None, False, "expired"),
        ("plus", -3, "pro", False, "test"),
        (None, -3, None, True, "developer"),
    ],
)
def test_access_matches_subscription_rules_and_never_implies_payment(
    portal: tuple[TestClient, Mock],
    plan: str | None,
    days: int,
    test_plan: str | None,
    developer: bool,
    expected: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    browser, client = portal
    now = datetime.now(UTC)
    client.auth.admin.list_users.return_value = [
        account(
            "a",
            email_confirmed_at=now,
            last_sign_in_at=now,
            banned_until=now + timedelta(days=1),
            user_metadata={"role": "admin", "private": "DO NOT RETURN"},
        )
    ]
    client.table.return_value.select.return_value.in_.return_value.execute.return_value = (
        SimpleNamespace(
            data=[
                {
                    "owner_id": "a",
                    "plan": plan,
                    "trial_ends_at": (now + timedelta(days=days)).isoformat(),
                    "created_at": now.isoformat(),
                }
            ]
        )
    )
    monkeypatch.setattr(get_container(), "subscription_test_plan", test_plan)
    monkeypatch.setattr(
        get_container(),
        "developer_emails",
        frozenset({"a@example.com"}) if developer else frozenset(),
    )
    response = browser.get(PATH)
    assert response.status_code == 200
    user = response.json()["users"][0]
    assert user["access"] == expected
    assert user["email_verified"] and user["banned_until"]
    assert user["total_paid_minor"] is None and user["last_payment_at"] is None
    assert user["effective_plan"] == (test_plan or (plan if plan != "legacy" else None))
    assert "DO NOT RETURN" not in response.text


def test_provider_failure_is_not_an_empty_list_or_leaked_error(
    portal: tuple[TestClient, Mock],
) -> None:
    browser, client = portal
    client.auth.admin.list_users.side_effect = RuntimeError("password=secret person@example.com")
    response = browser.get(PATH)
    assert response.status_code == 503
    assert "secret" not in response.text and "person@example.com" not in response.text


@pytest.mark.parametrize("params", [{"page": 0}, {"page_size": 101}, {"q": "a" * 201}])
def test_bounded_inputs(portal: tuple[TestClient, Mock], params: dict[str, Any]) -> None:
    assert portal[0].get(PATH, params=params).status_code == 422
