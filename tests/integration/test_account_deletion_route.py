from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app


def test_delete_account_acts_on_the_signed_in_owner_only() -> None:
    client = TestClient(app)
    response = client.delete("/account")
    assert response.status_code == 200
    body = response.json()
    assert body["deleted"] is True
    assert "rows_deleted" in body["report"]


def test_the_route_takes_no_owner_id_from_the_caller() -> None:
    client = TestClient(app)
    # There is no path or query parameter that could name another account.
    assert client.delete("/account/someone-else").status_code in (404, 405)


def test_a_sign_in_older_than_a_few_minutes_gets_401_and_deletes_nothing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # The app reads 401 as "ask for the password again" (reauth_required).
    client = TestClient(app)
    container = get_container()
    stale = datetime.now(UTC) - timedelta(hours=1)
    monkeypatch.setattr(container.auth_provider, "last_sign_in_at", lambda: stale)
    pet_id = client.post("/pets", json={"name": "Brina", "species": "dog"}).json()["pet_profile"][
        "id"
    ]

    response = client.delete("/account")

    assert response.status_code == 401
    assert client.get(f"/pets/{pet_id}").status_code == 200
