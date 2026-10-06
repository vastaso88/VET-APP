from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.domain.consent.models import AccountConsentType


def test_consent_texts_are_public_without_any_token() -> None:
    client = TestClient(app)

    response = client.get("/legal/consents")

    assert response.status_code == 200
    catalog = response.json()["catalog"]
    assert set(catalog) == set(AccountConsentType.ALL)
    for entry in catalog.values():
        assert entry["version"]
        assert entry["text"].strip()
