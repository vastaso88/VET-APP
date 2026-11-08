"""The age routes and the blocks that follow, through the real API, with two
different owners ("utente B")."""

from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"


def _years_ago(years: int) -> str:
    today = datetime.now(UTC).date()
    return today.replace(year=today.year - years).isoformat()


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[object]:
    """Switch who the fake sign-in says the caller is."""
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current = {"id": USER_A}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=current["id"], email="owner@example.com"),
    )

    def switch(user_id: str) -> None:
        current["id"] = user_id

    yield switch


def test_the_status_never_returns_the_date_and_starts_unknown(as_user: object) -> None:
    client = TestClient(app)
    body = client.get("/account/age").json()
    assert body["band"] == "unknown"
    assert "birth" not in str(body).lower()
    assert "support_contact_email" in body


def test_declaring_once_then_409_and_each_owner_has_their_own(as_user: object) -> None:
    client = TestClient(app)
    first = client.post("/account/age", json={"birth_date": _years_ago(30)})
    assert first.status_code == 200 and first.json()["band"] == "adult"

    again = client.post("/account/age", json={"birth_date": _years_ago(15)})
    assert again.status_code == 409 and again.json()["code"] == "age_already_declared"
    assert client.get("/account/age").json()["band"] == "adult"

    as_user(USER_B)  # type: ignore[operator]
    assert client.get("/account/age").json()["band"] == "unknown"


def test_the_mercatino_asks_for_the_date_then_refuses_a_minor(as_user: object) -> None:
    client = TestClient(app)
    assert client.get("/marketplace/restriction").json()["code"] == "age_required"

    client.post("/account/age", json={"birth_date": _years_ago(16)})
    refused = client.get("/marketplace/restriction")
    assert refused.status_code == 403 and refused.json()["code"] == "marketplace_adults_only"
    assert client.get("/marketplace/conversations").status_code == 403
    assert client.get("/marketplace/listings/any-id").status_code == 403

    as_user(USER_B)  # type: ignore[operator]
    client.post("/account/age", json={"birth_date": _years_ago(30)})
    assert client.get("/marketplace/restriction").status_code == 200


def test_a_parents_ok_is_recorded_for_the_caller_only(as_user: object) -> None:
    client = TestClient(app)
    client.post("/account/age", json={"birth_date": _years_ago(16)})

    confirmed = client.post("/account/guardian-authorization")
    assert confirmed.status_code == 200 and confirmed.json()["guardian_confirmed"] is True

    as_user(USER_B)  # type: ignore[operator]
    assert client.get("/account/age").json()["guardian_confirmed"] is False
    other = client.post("/account/guardian-authorization")
    assert other.status_code == 403 and other.json()["code"] == "age_required"


def test_a_closed_account_can_only_read_its_status_and_delete_itself(as_user: object) -> None:
    client = TestClient(app)
    client.post("/account/age", json={"birth_date": _years_ago(10)})

    assert client.get("/account/age").json()["band"] == "under_minimum"
    closed = client.get("/pets")
    assert closed.status_code == 403 and closed.json()["code"] == "under_minimum_age"
    assert client.get("/marketplace/restriction").json()["code"] == "under_minimum_age"
    assert client.post("/subscription/select-plan", json={"plan": "plus"}).status_code == 403

    # Erasure stays possible for the owner themselves.
    assert client.delete("/account").status_code == 200

    # Someone else is not affected.
    as_user(USER_B)  # type: ignore[operator]
    assert client.get("/pets").status_code == 200
