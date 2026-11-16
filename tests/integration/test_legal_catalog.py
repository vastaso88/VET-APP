import re

from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.domain.consent.account_consent_text import (
    CONSENT_TEXT_IT,
    CONSENT_TEXTS_BY_LANGUAGE,
    build_consent_catalog,
    served_consent_language,
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


def test_a_language_without_a_text_falls_back_to_english_never_to_italian() -> None:
    # Only languages that will never get a catalog here: German and French are
    # being translated, and the test must not break when they arrive.
    client = TestClient(app)
    english = client.get("/legal/consents", params={"lang": "en"}).json()

    for lang in ("xx", "pt-BR", "zh_CN"):
        response = client.get("/legal/consents", params={"lang": lang})
        assert response.status_code == 200
        body = response.json()
        assert body["language"] == "en", lang
        assert body["catalog"] == english["catalog"], lang


def test_no_language_or_italian_means_the_italian_catalog() -> None:
    client = TestClient(app)
    baseline = client.get("/legal/consents").json()

    for params in ({"lang": "it"}, {"lang": ""}, {"lang": "IT_it"}):
        body = client.get("/legal/consents", params=params).json()
        assert body["language"] == "it", params
        assert body["catalog"] == baseline["catalog"], params


def test_served_consent_language_rules() -> None:
    assert served_consent_language(None) == "it"
    assert served_consent_language("") == "it"
    assert served_consent_language("   ") == "it"
    assert served_consent_language("it") == "it"
    assert served_consent_language("EN-gb") == "en"
    assert served_consent_language("es_ES") == "es"
    assert served_consent_language("xx") == "en"
    assert served_consent_language("pt-BR") == "en"


def test_translated_catalogs_have_the_same_keys_and_versions() -> None:
    client = TestClient(app)
    baseline = client.get("/legal/consents").json()["catalog"]
    rules_lines = baseline["contribution_rules"]["text"].count("\n")
    for lang in ("en", "es", "de", "fr", "EN-gb", "de-AT", "de_CH", "fr-BE", "fr-CH"):
        body = client.get("/legal/consents", params={"lang": lang}).json()
        assert body["language"] == lang.lower().replace("_", "-").split("-")[0]
        assert set(body["catalog"]) == set(baseline)
        for key, entry in body["catalog"].items():
            assert entry["text"].strip()
            assert entry["version"] == baseline[key]["version"]
        # the title and the eight rules of the radar, one per line, in every language
        assert body["catalog"]["contribution_rules"]["text"].count("\n") == rules_lines


def test_german_and_french_consent_texts_use_the_formal_register_and_the_glossary() -> None:
    german = " ".join(CONSENT_TEXTS_BY_LANGUAGE["de"].values())
    french = " ".join(CONSENT_TEXTS_BY_LANGUAGE["fr"].values())

    # "Sie" and "vous", never "du" and "tu" (docs/i18n/GLOSSARIO_E_STILE.md)
    assert re.search(r"\bSie\b", german)
    assert not re.search(r"\b(du|dir|dich|dein\w*)\b", german, flags=re.IGNORECASE)
    assert re.search(r"\bvous\b", french)
    assert not re.search(r"\b(tu|toi|ton|ta|tes)\b", french, flags=re.IGNORECASE)
    # the same term as the app and as the medical record consent
    privacy = AccountConsentType.PRIVACY_POLICY
    assert "Krankenakte" in CONSENT_TEXTS_BY_LANGUAGE["de"][privacy]
    assert "dossier médical" in CONSENT_TEXTS_BY_LANGUAGE["fr"][privacy]
    # French typography: a no-break space before : ; ? !, never an ordinary one
    assert not re.search(r" [:;?!]", french)
