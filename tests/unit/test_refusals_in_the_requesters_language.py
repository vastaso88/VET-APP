"""Collaudo F24: what the form of "Segnala un evento" and the Mercatino refuse was written in
Italian only. It is now written in the language of whoever asked (Accept-Language), while `detail`
stays what installed apps already read (the Italian sentence, or the code)."""

from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.core.application.services.marketplace_messaging import MarketplaceMessagingService
from packages.core.domain.events.submission import build_submission
from packages.core.domain.localization import _MESSAGES
from packages.core.domain.localized_errors import LocalizedValidationError
from packages.shared.errors.base import ValidationError

LANGUAGES = ("it", "en", "es", "de", "fr")


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


def _event(**values: object) -> dict[str, object]:
    soon = date.today() + timedelta(days=10)
    return {
        "title": "Giornata del cane",
        "event_type": "other",
        "starts_on": soon.isoformat(),
        "ends_on": soon.isoformat(),
        "city": "Modena",
        "source_url": "https://example.com/evento",
        **values,
    }


def test_every_new_text_exists_in_the_five_languages() -> None:
    keys = [
        k for k in _MESSAGES if k.startswith(("event_", "listing_not_found", "marketplace_message"))
    ]

    assert len(keys) >= 19
    for key in keys:
        assert set(_MESSAGES[key]) == set(LANGUAGES), key


@pytest.mark.parametrize(
    ("language", "expected"),
    [
        ("it", "Titolo: troppo corto"),
        ("en", "Title: too short"),
        ("es", "Título: demasiado corto"),
        ("de", "Titel: zu kurz"),
        ("fr", "Titre : trop court"),
    ],
)
def test_the_event_form_refuses_in_the_language_of_the_request(
    client: TestClient, language: str, expected: str
) -> None:
    response = client.post(
        "/events/submissions", json=_event(title="abc"), headers={"Accept-Language": language}
    )

    assert response.status_code == 400
    body = response.json()
    assert body["message"] == expected
    assert body["detail"] == "Titolo: troppo corto"  # what installed apps read, always Italian
    assert body["code"] == "event_title_short"


def test_the_field_name_inside_a_sentence_is_translated_too(client: TestClient) -> None:
    response = client.post(
        "/events/submissions",
        json=_event(city="  "),
        headers={"Accept-Language": "de"},
    )

    assert response.json()["message"] == "Ort: Pflichtfeld"
    assert response.json()["detail"] == "Città: campo obbligatorio"


def test_without_a_language_the_event_form_answers_in_italian_as_before(
    client: TestClient,
) -> None:
    response = client.post("/events/submissions", json=_event(event_type="nope"))

    assert response.json()["detail"] == "Tipo di evento non valido"
    assert response.json()["message"] == "Tipo di evento non valido"


def test_the_daily_limit_of_suggestions_is_in_the_language_of_the_request(
    client: TestClient,
) -> None:
    headers = {"Accept-Language": "en"}
    for _ in range(3):
        assert client.post("/events/submissions", json=_event(), headers=headers).status_code == 201

    refused = client.post("/events/submissions", json=_event(), headers=headers)

    assert refused.status_code == 429
    body = refused.json()
    assert body["code"] == "submission_limit_reached"
    assert body["message"] == "You have already sent 3 suggestions today: try again tomorrow."
    assert body["detail"] == "Hai già inviato 3 segnalazioni oggi: riprova domani."


def test_the_domain_refusal_keeps_its_italian_sentence_as_str() -> None:
    with pytest.raises(ValidationError, match="Titolo: troppo corto"):
        build_submission(
            owner_id="o",
            title="abc",
            event_type="other",
            starts_on=date.today(),
            ends_on=date.today(),
            city="Modena",
            source_url="https://example.com/x",
        )


@pytest.mark.parametrize(
    ("language", "expected"),
    [
        ("it", "Annuncio non trovato."),
        ("en", "Listing not found."),
        ("es", "Anuncio no encontrado."),
        ("de", "Anzeige nicht gefunden."),
        ("fr", "Annonce introuvable."),
    ],
)
@pytest.mark.usefixtures("adult_everyone")
def test_a_missing_ad_says_so_in_the_language_of_the_request(
    client: TestClient, language: str, expected: str
) -> None:
    response = client.get(
        "/marketplace/listings/does-not-exist", headers={"Accept-Language": language}
    )

    assert response.status_code == 404
    assert response.json()["detail"] == expected


def test_the_refusals_of_a_mercatino_message_keep_their_codes_and_speak_the_language() -> None:
    for text, code, message_en in (
        ("   ", "message is empty", "Write a message."),
        ("x" * 5000, "message is too long", "The message is too long."),
    ):
        with pytest.raises(LocalizedValidationError) as caught:
            MarketplaceMessagingService._clean(text)
        assert str(caught.value) == code  # what installed apps read
        assert caught.value.message("en") == message_en
