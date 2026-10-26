import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser


def test_old_account_defaults_to_italian() -> None:
    assert AuthenticatedUser(id="old", email="old@example.test").preferred_locale == "it"
    assert TestClient(app).get("/account/preferences").json() == {"preferred_locale": "it"}


@pytest.mark.parametrize("locale", ["it", "en", "es"])
def test_account_preference_round_trip(locale: str) -> None:
    client = TestClient(app)
    result = client.put("/account/preferences", json={"preferred_locale": locale})
    assert result.status_code == 200
    assert client.get("/account/preferences").json() == {"preferred_locale": locale}


def test_invalid_preference_does_not_change_account() -> None:
    client = TestClient(app)
    assert client.put("/account/preferences", json={"preferred_locale": "ja"}).status_code == 422
    assert client.get("/account/preferences").json() == {"preferred_locale": "it"}
