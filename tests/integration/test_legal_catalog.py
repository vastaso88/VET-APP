from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.domain.consent.account_consent_text import (
    CONSENT_TEXT_IT,
    build_consent_catalog,
)
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


def test_catalog_is_unchanged_without_lang() -> None:
    client = TestClient(app)

    body = client.get("/legal/consents").json()

    assert body["language"] == "it"
    assert {key: entry["text"] for key, entry in body["catalog"].items()} == dict(CONSENT_TEXT_IT)
    assert body["catalog"] == {k: v.model_dump() for k, v in build_consent_catalog().items()}


def test_other_languages_are_served_the_italian_catalog_for_now() -> None:
    client = TestClient(app)
    baseline = client.get("/legal/consents").json()

    for lang in ("en", "fr", "xx", "it", "EN-gb"):
        response = client.get("/legal/consents", params={"lang": lang})
        assert response.status_code == 200
        body = response.json()
        assert body["language"] == "it", lang
        assert body["catalog"] == baseline["catalog"], lang
