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


def test_unknown_languages_fall_back_to_italian() -> None:
    client = TestClient(app)
    baseline = client.get("/legal/consents").json()

    for lang in ("fr", "xx", "it"):
        response = client.get("/legal/consents", params={"lang": lang})
        assert response.status_code == 200
        body = response.json()
        assert body["language"] == "it", lang
        assert body["catalog"] == baseline["catalog"], lang


def test_english_and_spanish_catalogs_have_the_same_keys_and_versions() -> None:
    client = TestClient(app)
    baseline = client.get("/legal/consents").json()["catalog"]
    for lang in ("en", "es", "EN-gb"):
        body = client.get("/legal/consents", params={"lang": lang}).json()
        assert body["language"] == lang.lower().split("-")[0]
        assert set(body["catalog"]) == set(baseline)
        for key, entry in body["catalog"].items():
            assert entry["text"].strip()
            assert entry["version"] == baseline[key]["version"]
