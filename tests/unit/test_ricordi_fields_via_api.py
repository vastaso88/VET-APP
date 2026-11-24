"""Collaudo F41: a body that tries to move a pet to Ricordi through POST/PUT /pets used to
answer 200 and change nothing (the app writes Ricordi straight to the database). It is now a
422 with its own type, so a save that did not happen never looks like one."""

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


@pytest.mark.parametrize(
    "extra",
    [
        {"is_memorial": True},
        {"is_memorial": False},
        {"memorial_date_label": "15 mar 2031"},
        {"memorial_birthday_reminder": True},
    ],
)
@pytest.mark.parametrize(("method", "path"), [("post", "/pets"), ("put", "/pets/any-pet")])
def test_ricordi_fields_are_refused_not_ignored(
    client: TestClient, method: str, path: str, extra: dict[str, object]
) -> None:
    body = {"name": "Nocciola", "species": "Gatto", **extra}

    response = getattr(client, method)(path, json=body)

    assert response.status_code == 422
    payload = response.json()
    assert payload["code"] == "invalid_input"
    assert payload["detail"][0]["type"] == "memorial_not_via_api"
    # What was typed never travels back.
    assert "2031" not in response.text


def test_an_ordinary_pet_body_is_not_affected(client: TestClient) -> None:
    response = client.post("/pets", json={"name": "N" * 81, "species": "Gatto"})

    assert response.status_code == 422
    assert response.json()["detail"][0]["type"] == "string_too_long"
