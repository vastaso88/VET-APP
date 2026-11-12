"""POST /devices/register through the route: the owner comes from the token
only, so a second account ("user B") can never take a place of user A's."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app, rate_limiter
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser

SwitchUser = Callable[[str], None]


@pytest.fixture(autouse=True)
def _normal_behaviour(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")
    rate_limiter._hits.clear()
    yield
    rate_limiter._hits.clear()


@pytest.fixture
def act_as(monkeypatch: pytest.MonkeyPatch) -> SwitchUser:
    provider = get_container().auth_provider

    def switch(user_id: str) -> None:
        monkeypatch.setattr(
            provider,
            "get_current_user",
            lambda: AuthenticatedUser(id=user_id, email=f"{user_id}@example.com"),
        )

    return switch


def _register(client: TestClient, device_id: str, *, claim: bool) -> dict[str, object]:
    response = client.post("/devices/register", json={"device_id": device_id, "claim": claim})
    assert response.status_code == 200, response.text
    body: dict[str, object] = response.json()
    return body


def test_user_b_filling_their_places_never_revokes_a_device_of_user_a(
    act_as: SwitchUser,
) -> None:
    client = TestClient(app)
    tag = uuid4().hex[:8]
    act_as(f"owner-a-{tag}")
    assert _register(client, f"phone-a-{tag}", claim=True)["active"] is True

    act_as(f"owner-b-{tag}")
    for index in range(6):
        _register(client, f"phone-b{index}-{tag}", claim=True)

    act_as(f"owner-a-{tag}")
    assert _register(client, f"phone-a-{tag}", claim=False)["active"] is True


def test_the_same_install_id_under_two_accounts_is_two_separate_devices(
    act_as: SwitchUser,
) -> None:
    client = TestClient(app)
    tag = uuid4().hex[:8]
    shared = f"family-tablet-{tag}"
    act_as(f"owner-a-{tag}")
    _register(client, shared, claim=True)
    act_as(f"owner-b-{tag}")
    _register(client, shared, claim=True)

    act_as(f"owner-a-{tag}")
    assert _register(client, shared, claim=False)["active"] is True


@pytest.mark.parametrize("device_id", ["short", "has spaces in it", "x" * 65, "../../etc"])
def test_a_malformed_device_id_is_refused(act_as: SwitchUser, device_id: str) -> None:
    act_as(f"owner-{uuid4().hex[:8]}")
    response = TestClient(app).post("/devices/register", json={"device_id": device_id})
    assert response.status_code in (400, 422)
