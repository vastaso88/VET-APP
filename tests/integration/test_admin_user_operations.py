"""No live service calls: a query double with independent synthetic accounts."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.marketplace.messaging import MarketplaceRestriction
from packages.infrastructure.admin.user_reports import moderation


def account(user_id: str) -> SimpleNamespace:
    return SimpleNamespace(
        id=user_id, email=f"{user_id}@example.com", created_at=datetime(2026, 1, 1, tzinfo=UTC)
    )


class Query:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows.copy()
        self.start, self.end = 0, len(rows)
        self.columns = "*"

    def select(self, columns: str) -> "Query":
        self.columns = columns
        return self

    def eq(self, key: str, value: Any) -> "Query":
        self.rows = [row for row in self.rows if row.get(key) == value]
        return self

    def in_(self, key: str, values: list[str]) -> "Query":
        self.rows = [row for row in self.rows if row.get(key) in values]
        return self

    def gte(self, key: str, value: Any) -> "Query":
        self.rows = [row for row in self.rows if str(row.get(key, "")) >= str(value)]
        return self

    def order(self, key: str, desc: bool = False) -> "Query":
        self.rows.sort(key=lambda row: str(row.get(key) or ""), reverse=desc)
        return self

    def range(self, start: int, end: int) -> "Query":
        self.start, self.end = start, end + 1
        return self

    def limit(self, count: int) -> "Query":
        self.end = count
        return self

    def execute(self) -> SimpleNamespace:
        rows = self.rows[self.start : self.end]
        if self.columns != "*":
            rows = [
                {key: row[key] for key in self.columns.split(",") if key in row} for row in rows
            ]
        return SimpleNamespace(data=rows)


class Database:
    def __init__(self) -> None:
        self.users = [account("a"), account("b"), account("c")]
        self.auth = SimpleNamespace(
            admin=SimpleNamespace(
                list_users=lambda **_: self.users,
                get_user_by_id=lambda owner: SimpleNamespace(
                    user=next((u for u in self.users if u.id == owner), None)
                ),
            )
        )
        self.data: dict[str, list[dict[str, Any]]] = {
            "user_locations": [
                {"owner_id": "a", "home_country_code": "IT", "home_city": "Example city"},
                {"owner_id": "b", "home_country_code": "FR"},
            ],
        }
        self.rpc = Mock(
            side_effect=lambda *_: SimpleNamespace(
                execute=lambda: SimpleNamespace(data={"status": "applied", "changed": True})
            )
        )

    def table(self, table: str) -> Query:
        return Query(self.data.get(table, []))


@pytest.fixture
def portal(monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, Database]:
    monkeypatch.setattr(
        "apps.api.routes.admin_user_actions._configured_admin_emails",
        lambda: frozenset({"admin@example.com"}),
    )
    monkeypatch.setattr(
        "apps.api.routes.admin._configured_admin_emails", lambda: frozenset({"admin@example.com"})
    )
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(
            id="admin",
            email="admin@example.com",
            email_verified=True,
        ),
    )
    database = Database()
    monkeypatch.setattr("apps.api.routes.admin_users._admin_client", lambda: database)
    monkeypatch.setattr("apps.api.routes.admin_user_actions._admin_client", lambda: database)
    return TestClient(app), database


def body(**kwargs: Any) -> dict[str, Any]:
    return {
        "action": "restrict_marketplace",
        "reason": "spam",
        "note": "Verified repeated spam",
        "owner_ids": ["a"],
        **kwargs,
    }


def test_country_filter_is_global_not_page_local(portal: tuple[TestClient, Database]) -> None:
    browser, _ = portal
    result = browser.get("/admin/users", params={"country": "FR", "page_size": 1}).json()
    assert result["total"] == 1 and result["users"][0]["id"] == "b"
    assert result["countries"] == {"FR": 1, "IT": 1, "unknown": 1}
    result = browser.get("/admin/users", params={"country": "unknown"}).json()
    assert [row["id"] for row in result["users"]] == ["c"]
    assert browser.get("/admin/users", params={"q": "a@example"}).json()["countries"] == {"IT": 1}


@pytest.mark.parametrize(
    "path", ["/admin/users/a", "/admin/user-actions/preview", "/admin/user-actions/execute"]
)
def test_normal_user_cannot_read_or_mutate_other_accounts(
    portal: tuple[TestClient, Database],
    monkeypatch: pytest.MonkeyPatch,
    path: str,
) -> None:
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(
            id="b",
            email="b@example.com",
            email_verified=True,
        ),
    )
    browser, database = portal
    response = (
        browser.get(path)
        if path.endswith("/a")
        else browser.post(
            path,
            json=body()
            if path.endswith("preview")
            else {"token": "invalid-token", "confirmed": True},
        )
    )
    assert response.status_code == 403
    database.rpc.assert_not_called()


def test_detail_is_scoped_and_failure_is_visible(portal: tuple[TestClient, Database]) -> None:
    browser, database = portal
    database.data["user_devices"] = [
        {"owner_id": "a", "device_id": "a-device"},
        {"owner_id": "b", "device_id": "b-device"},
    ]
    database.rpc.side_effect = RuntimeError("secret person@example.com")
    response = browser.get("/admin/users/a")
    assert response.status_code == 200
    data = response.json()
    assert data["usage"] is None and "usage" in data["unavailable"]
    assert "b-device" not in response.text and "secret" not in response.text
    assert browser.get("/admin/users/missing").status_code == 404


def test_preview_is_read_only_and_deduplicates_accounts(
    portal: tuple[TestClient, Database],
) -> None:
    browser, database = portal
    response = browser.post("/admin/user-actions/preview", json=body(owner_ids=["a", "a", "b"]))
    assert response.status_code == 200
    assert len(response.json()["users"]) == 2
    database.rpc.assert_not_called()


def test_all_results_is_frozen_to_filters_and_signed(portal: tuple[TestClient, Database]) -> None:
    browser, database = portal
    prepared = browser.post(
        "/admin/user-actions/preview", json=body(owner_ids=[], all_results=True, country="FR")
    ).json()
    assert [user["id"] for user in prepared["users"]] == ["b"]
    database.data["user_locations"].append({"owner_id": "c", "home_country_code": "FR"})
    result = browser.post(
        "/admin/user-actions/execute", json={"token": prepared["token"], "confirmed": True}
    )
    assert result.status_code == 200
    assert [row["id"] for row in result.json()["results"]] == ["b"]
    assert database.rpc.call_args.args[1]["p_owner_id"] == "b"
    database.rpc.reset_mock()
    assert (
        browser.post(
            "/admin/user-actions/execute",
            json={"token": prepared["token"] + "tampered", "confirmed": True},
        ).status_code
        == 409
    )
    database.rpc.assert_not_called()


def test_expired_preview_or_different_admin_is_rejected(
    portal: tuple[TestClient, Database],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    browser, _ = portal
    token = browser.post("/admin/user-actions/preview", json=body()).json()["token"]
    monkeypatch.setattr("apps.api.routes.admin_user_actions.time.time", lambda: 9_999_999_999)
    assert (
        browser.post(
            "/admin/user-actions/execute", json={"token": token, "confirmed": True}
        ).status_code
        == 409
    )


def test_bulk_returns_each_failure_without_leaking_provider_details(
    portal: tuple[TestClient, Database],
) -> None:
    browser, database = portal
    token = browser.post("/admin/user-actions/preview", json=body(owner_ids=["a", "b"])).json()[
        "token"
    ]
    database.rpc.side_effect = [
        RuntimeError("private token"),
        SimpleNamespace(
            execute=lambda: SimpleNamespace(data={"status": "applied", "changed": True})
        ),
    ]
    response = browser.post("/admin/user-actions/execute", json={"token": token, "confirmed": True})
    assert [result["status"] for result in response.json()["results"]] == ["failed", "applied"]
    assert "private token" not in response.text


def test_protected_accounts_rechecked_after_preview(portal: tuple[TestClient, Database]) -> None:
    browser, database = portal
    database.users.append(account("admin"))
    assert (
        browser.post("/admin/user-actions/preview", json=body(owner_ids=["admin"])).status_code
        == 422
    )
    token = browser.post("/admin/user-actions/preview", json=body()).json()["token"]
    database.users[0].email = "admin@example.com"
    result = browser.post(
        "/admin/user-actions/execute", json={"token": token, "confirmed": True}
    ).json()
    assert result["results"][0]["status"] == "protected"
    database.rpc.assert_not_called()


def test_case_link_must_concern_target_and_not_reporter(
    portal: tuple[TestClient, Database],
) -> None:
    browser, database = portal
    database.data["marketplace_conversations"] = [
        {"id": "thread", "buyer_id": "a", "seller_id": "b"}
    ]
    database.data["marketplace_conversation_reports"] = [
        {"id": "report", "conversation_id": "thread", "reporter_id": "a"}
    ]
    assert (
        browser.post(
            "/admin/user-actions/preview",
            json=body(
                owner_ids=[],
                cases=[{"owner_id": "a", "queue": "marketplace_messages", "id": "report"}],
            ),
        ).status_code
        == 422
    )
    prepared = browser.post(
        "/admin/user-actions/preview",
        json=body(
            owner_ids=[], cases=[{"owner_id": "b", "queue": "marketplace_messages", "id": "report"}]
        ),
    )
    assert prepared.status_code == 200
    browser.post(
        "/admin/user-actions/execute", json={"token": prepared.json()["token"], "confirmed": True}
    )
    assert database.rpc.call_args.args[1]["p_case_id"] == "report"


def test_moderation_separates_received_filed_and_excludes_other_users(
    portal: tuple[TestClient, Database],
) -> None:
    _, database = portal
    database.data["marketplace_listings"] = [
        {"id": "ad-a", "owner_id": "a"},
        {"id": "ad-b", "owner_id": "b"},
    ]
    database.data["marketplace_listing_reports"] = [
        {"id": "received", "listing_id": "ad-a", "reporter_owner_id": "b"},
        {"id": "filed", "listing_id": "ad-b", "reporter_owner_id": "a"},
        {"id": "unrelated", "listing_id": "ad-b", "reporter_owner_id": "c"},
    ]
    result = moderation(database, "a")
    assert result["received"] == result["filed"] == 1
    assert "unrelated" not in str(result)
    # Real PostgREST applies the explicit SELECT list; check the route's projection too.
    assert {event["direction"] for event in result["events"]} == {"filed", "received"}
    assert "reporter_owner_id" not in str(result)


@pytest.mark.parametrize(
    "changes", [{"note": "  "}, {"duration_days": 91}, {"all_results": True}, {"owner_ids": []}]
)
def test_invalid_actions_rejected(
    portal: tuple[TestClient, Database], changes: dict[str, Any]
) -> None:
    browser, database = portal
    assert browser.post("/admin/user-actions/preview", json=body(**changes)).status_code == 422
    database.rpc.assert_not_called()


def test_expired_restriction_does_not_block_marketplace() -> None:
    restriction = MarketplaceRestriction(
        owner_id="a", reason="spam", expires_at=datetime.now(UTC) - timedelta(seconds=1)
    )
    assert not restriction.active
