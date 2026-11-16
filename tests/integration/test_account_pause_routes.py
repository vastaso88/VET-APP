"""The pause over HTTP: it blocks the session that asked, ends at the next real
sign-in, is told to the app once, and never reaches another owner."""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.infrastructure.persistence.in_memory_account_pause_repository import (
    InMemoryAccountPauseRepository,
)

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"


class _World:
    """Who is calling, and when that caller last signed in."""

    def __init__(self) -> None:
        self.user = USER_A
        self.signed_in_at: datetime | None = datetime.now(UTC) - timedelta(hours=1)


@pytest.fixture
def world(monkeypatch: pytest.MonkeyPatch) -> Iterator[_World]:
    container = get_container()
    state = _World()
    monkeypatch.setattr(container, "account_pause_repository", InMemoryAccountPauseRepository())
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=state.user, email="owner@example.com"),
    )
    monkeypatch.setattr(inner, "last_sign_in_at", lambda: state.signed_in_at)
    container.auth_provider._blocked.clear()  # type: ignore[attr-defined]
    yield state
    container.auth_provider._blocked.clear()  # type: ignore[attr-defined]


def test_pausing_blocks_the_session_that_asked_and_hides_nothing_else(world: _World) -> None:
    client = TestClient(app)
    assert client.get("/pets").status_code == 200

    response = client.post("/account/pause")

    body = response.json()
    assert response.status_code == 200 and body["paused"] is True
    assert datetime.fromisoformat(body["delete_after"]) > datetime.fromisoformat(body["paused_at"])
    assert body["max_months"] == 24
    for path in ("/pets", "/account/session"):
        blocked = client.get(path)
        assert blocked.status_code == 403 and blocked.json()["code"] == "account_paused"


def test_a_new_sign_in_ends_the_pause_and_the_app_is_told_once(world: _World) -> None:
    client = TestClient(app)
    client.post("/account/pause")

    world.signed_in_at = datetime.now(UTC) + timedelta(minutes=5)  # a real sign-in, later
    assert client.get("/account/session").status_code == 200
    assert client.get("/pets").status_code == 200

    notice = client.get("/account/pause/notice").json()
    assert notice["resumed"] is True
    assert "has_access" in notice and "data_kept_until" in notice
    # Still told until the app says it has shown it.
    assert client.get("/account/pause/notice").json()["resumed"] is True

    assert client.post("/account/pause/notice/ack").json() == {"acknowledged": True}
    assert client.get("/account/pause/notice").json() == {"resumed": False}
    assert client.post("/account/pause/notice/ack").json() == {"acknowledged": False}


def test_an_unreadable_sign_in_time_does_not_end_the_pause(world: _World) -> None:
    client = TestClient(app)
    client.post("/account/pause")
    world.signed_in_at = None
    assert client.get("/account/session").status_code == 403


def test_pausing_again_after_returning_starts_a_new_pause(world: _World) -> None:
    client = TestClient(app)
    client.post("/account/pause")
    world.signed_in_at = datetime.now(UTC) + timedelta(minutes=5)
    client.get("/pets")  # resumed, not yet acknowledged
    assert client.get("/account/pause/notice").json()["resumed"] is True

    again = client.post("/account/pause")
    assert again.status_code == 200
    # The caller signed in before pressing the button, as in real life.
    world.signed_in_at = datetime.now(UTC) - timedelta(hours=1)

    # The ended row is replaced: nothing left to announce, and the account is paused.
    assert client.get("/account/session").status_code == 403
    world.signed_in_at = datetime.now(UTC) + timedelta(minutes=5)
    assert client.get("/account/session").status_code == 200  # the next sign-in resumes


def test_user_b_never_sees_or_clears_user_a_pause(world: _World) -> None:
    client = TestClient(app)
    client.post("/account/pause")  # user A paused
    world.signed_in_at = datetime.now(UTC) + timedelta(minutes=5)
    client.get("/pets")  # A is back, notice pending

    world.user = USER_B
    # B is untouched by A's pause and has nothing to be told.
    assert client.get("/pets").status_code == 200
    assert client.get("/account/pause/notice").json() == {"resumed": False}
    assert client.post("/account/pause/notice/ack").json() == {"acknowledged": False}

    world.user = USER_A
    assert client.get("/account/pause/notice").json()["resumed"] is True  # A's is still there


def test_user_b_pausing_does_not_block_user_a(world: _World) -> None:
    client = TestClient(app)
    world.user = USER_B
    client.post("/account/pause")
    assert client.get("/account/session").status_code == 403

    world.user = USER_A
    assert client.get("/account/session").status_code == 200


def test_the_routes_take_no_owner_id_from_the_caller(world: _World) -> None:
    client = TestClient(app)
    assert client.post(f"/account/pause/{USER_B}").status_code in (404, 405)
    assert client.get(f"/account/pause/notice/{USER_B}").status_code in (404, 405)
