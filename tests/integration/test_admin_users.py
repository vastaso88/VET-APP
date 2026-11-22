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
    reply(client, [])
    monkeypatch.setattr("apps.api.routes.admin_users._admin_client", lambda: client)
    return TestClient(app), client


def account(user_id: str, **kwargs: Any) -> dict[str, Any]:
    """A row of the admin_users_directory function (QK-07), not an Auth user."""
    return {
        "id": user_id,
        "email": f"{user_id}@example.com",
        "created_at": datetime(2026, 1, 1, tzinfo=UTC).isoformat(),
        **kwargs,
    }


def reply(client: Mock, rows: list[dict[str, Any]], **page: Any) -> None:
    """What the database function answers: one page plus total and country counts."""
    client.rpc.return_value.execute.return_value = SimpleNamespace(
        data={
            "total": page.get("total", len(rows)),
            "page": page.get("page", 1),
            "page_size": 50,
            "countries": page.get("countries", {}),
            "rows": rows,
        }
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
    client.rpc.assert_not_called()
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


def test_the_page_comes_from_the_database_and_accounts_without_subscriptions_are_listed(
    portal: tuple[TestClient, Mock],
) -> None:
    browser, client = portal
    # The database answers page 2 of 3 (one account per page): the API sends the filters
    # and the page to it and never lists Auth users itself.
    reply(client, [account("b")], total=3, page=2, countries={"IT": 2, "unknown": 1})
    query = client.table.return_value.select.return_value.in_.return_value
    query.execute.return_value = SimpleNamespace(data=[])
    body = browser.get(
        PATH, params={"page": 2, "page_size": 1, "q": " A@Example ", "country": "IT"}
    )
    body = body.json()
    client.rpc.assert_called_once_with(
        "admin_users_directory",
        {"p_q": "A@Example", "p_country": "IT", "p_page": 2, "p_page_size": 1},
    )
    client.auth.admin.list_users.assert_not_called()
    assert body["total"] == 3 and body["page"] == 2
    assert [user["id"] for user in body["users"]] == ["b"]
    assert body["countries"] == {"IT": 2, "unknown": 1}
    client.table.return_value.select.return_value.in_.assert_called_with("owner_id", ["b"])
    user = body["users"][0]
    assert user["access"] == "not_started"
    assert user["trial_ends_at"] is None
    assert user["total_paid_minor"] is None
    assert user["location"] is None
    assert not body["payments_available"]
    # An empty page makes no subscription lookup at all.
    reply(client, [], total=0)
    client.table.reset_mock()
    assert browser.get(PATH, params={"q": "not-found"}).json()["users"] == []
    client.table.assert_not_called()
    client.table.return_value.insert.assert_not_called()
    client.table.return_value.upsert.assert_not_called()


def test_the_residence_comes_with_the_row(portal: tuple[TestClient, Mock]) -> None:
    browser, client = portal
    reply(
        client,
        [
            account("a", home_country_code="IT", home_city="Example city", home_saved_at="x"),
            account("b", home_country_code=None, home_city="Elsewhere"),
        ],
    )
    client.table.return_value.select.return_value.in_.return_value.execute.return_value = (
        SimpleNamespace(data=[])
    )
    first, second = browser.get(PATH).json()["users"]
    assert first["location"] == {
        "country_code": "IT",
        "city": "Example city",
        "source": "residence",
        "updated_at": "x",
    }
    assert second["location"]["country_code"] is None and second["location"]["source"] is None


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
    reply(
        client,
        [
            account(
                "a",
                email_confirmed_at=now.isoformat(),
                last_sign_in_at=now.isoformat(),
                banned_until=(now + timedelta(days=1)).isoformat(),
                user_metadata={"role": "admin", "private": "DO NOT RETURN"},
            )
        ],
    )
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
    client.rpc.side_effect = RuntimeError("password=secret person@example.com")
    response = browser.get(PATH)
    assert response.status_code == 503
    assert "secret" not in response.text and "person@example.com" not in response.text


@pytest.mark.parametrize("params", [{"page": 0}, {"page_size": 101}, {"q": "a" * 201}])
def test_bounded_inputs(portal: tuple[TestClient, Mock], params: dict[str, Any]) -> None:
    assert portal[0].get(PATH, params=params).status_code == 422
