"""Collaudo K08: the errors of a refused request.

- a body that does not fit its schema answered FastAPI's technical English and carried the owner's
  own text back (`input`): now a short sentence in the owner's language, and nothing typed returns;
- "<thing> not found" answered 400: now 404, with the same `detail` the apps map to a sentence.

What installed apps already read stays: 422 with a LIST in `detail` whose entries have `type` and
`loc` (the chat tells "message too long" by `string_too_long` + `user_message`), and the `detail`
texts "conversation not found" / "message not found"."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from apps.api.request_errors import request_error_body, request_error_message
from packages.core.domain.localization import SupportedLocale

LANGUAGES: tuple[SupportedLocale, ...] = ("it", "en", "es", "de", "fr")
TYPED = "NOME-DIGITATO-DALL-UTENTE-" * 4  # 100 characters, distinctive
SECRET = "segreto-dell-utente"


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


def _too_long(client: TestClient, language: str | None = None) -> dict[str, object]:
    headers = {"Accept-Language": language} if language else {}
    response = client.post("/pets", json={"name": TYPED, "species": "Cane"}, headers=headers)
    assert response.status_code == 422
    body: dict[str, object] = response.json()
    return body


# --- the 422 ----------------------------------------------------------------------------


def test_the_shape_the_installed_apps_read_is_kept(client: TestClient) -> None:
    body = _too_long(client)

    detail = body["detail"]
    assert isinstance(detail, list)  # the app's `_isMessageTooLong` reads a list
    assert detail[0]["type"] == "string_too_long"
    assert detail[0]["loc"] == ["body", "name"]
    assert body["code"] == "invalid_input"


def test_the_chat_message_too_long_is_still_recognised_by_type_and_field(
    client: TestClient,
) -> None:
    response = client.post("/chat", json={"pet_id": "p", "user_message": "x" * 8001})

    assert response.status_code == 422
    entries = response.json()["detail"]
    assert any(
        entry["type"] == "string_too_long" and "user_message" in entry["loc"] for entry in entries
    )


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_sentence_is_short_and_in_the_owners_language(
    client: TestClient, language: str
) -> None:
    body = _too_long(client, language)

    message = str(body["message"])
    assert "80" in message  # the real limit, not a number of ours
    assert message == body["detail"][0]["msg"]  # type: ignore[index]
    assert "String should" not in message and len(message) < 80
    expected = request_error_message(
        {"type": "string_too_long", "ctx": {"max_length": 80}}, language
    )
    assert message == expected


def test_the_five_languages_say_it_differently(client: TestClient) -> None:
    sentences = {str(_too_long(client, language)["message"]) for language in LANGUAGES}

    assert len(sentences) == 5


def test_the_language_follows_the_account_when_the_request_names_none(
    client: TestClient,
) -> None:
    assert "troppo lungo" in str(_too_long(client)["message"])  # Italian by default


def test_what_the_owner_typed_never_comes_back(client: TestClient) -> None:
    for language in LANGUAGES:
        response = client.post(
            "/pets",
            json={"name": TYPED, "species": "Cane", "notes": 5, "age_years": SECRET},
            headers={"Accept-Language": language},
        )

        assert response.status_code == 422
        assert "NOME-DIGITATO" not in response.text
        assert SECRET not in response.text
        assert '"input"' not in response.text and '"ctx"' not in response.text
        assert "pydantic" not in response.text and "https://errors" not in response.text


def test_a_key_typed_by_the_client_does_not_come_back_either() -> None:
    body = request_error_body(
        [{"type": "extra_forbidden", "loc": ("body", "k" * 500, 3), "msg": "Extra", "input": 1}],
        "it",
    )

    assert body["detail"][0]["loc"] == ["body", "k" * 64, 3]
    assert "input" not in body["detail"][0]


@pytest.mark.parametrize(
    ("error", "needle"),
    [
        ({"type": "missing"}, "obbligatorio"),
        ({"type": "int_parsing"}, "non è valido"),
        ({"type": "date_from_datetime_parsing"}, "data"),
        ({"type": "less_than_equal", "ctx": {"le": 100000}}, "100000"),
        ({"type": "less_than", "ctx": {"lt": 11}}, "10"),
        ({"type": "greater_than_equal", "ctx": {"ge": 1}}, "almeno 1"),
        ({"type": "too_long", "ctx": {"max_length": 6}}, "6"),
        ({"type": "string_too_short", "ctx": {"min_length": 3}}, "3"),
        ({"type": "something_new"}, "non è valido"),
    ],
)
def test_each_kind_of_refusal_has_its_own_short_sentence(
    error: dict[str, object], needle: str
) -> None:
    assert needle in request_error_message(error, "it")


def test_a_missing_field_and_a_bad_date_are_short_sentences_too(client: TestClient) -> None:
    missing = client.post("/pets", json={"species": "Cane"}, headers={"Accept-Language": "de"})
    bad_date = client.post("/account/age", json={"birth_date": "domani"})

    assert missing.status_code == 422 and "Pflichtangabe" in missing.json()["message"]
    assert bad_date.status_code == 422 and "data" in bad_date.json()["message"].lower()
    assert "domani" not in bad_date.text


# --- the 404 ----------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("method", "path", "body", "detail"),
    [
        ("GET", "/pets/inventato", None, "pet_profile not found"),
        ("PUT", "/pets/inventato", {"name": "Rex"}, "pet_profile not found"),
        (
            "POST",
            "/reminders",
            {"pet_id": "inventato", "title": "x", "due_date": "2030-01-01"},
            "pet_profile not found",
        ),
        (
            "POST",
            "/chat",
            {"pet_id": "inventato", "user_message": "ciao"},
            "pet_profile not found",
        ),
        ("DELETE", "/conversations/inventata", None, "conversation not found"),
    ],
)
def test_something_that_is_not_there_answers_404_with_the_same_detail(
    client: TestClient, method: str, path: str, body: dict[str, object] | None, detail: str
) -> None:
    response = client.request(method, path, json=body)

    assert response.status_code == 404
    assert response.json()["detail"] == detail  # the text the apps map is unchanged
    assert response.json()["code"] == "not_found"
    assert response.json()["message"] == "Non trovato."


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_not_found_sentence_is_in_the_owners_language(
    client: TestClient, language: str
) -> None:
    response = client.get("/pets/inventato", headers={"Accept-Language": language})

    assert response.status_code == 404
    assert response.json()["message"] != "" and len(response.json()["message"]) < 30


def test_a_pet_of_another_owner_answers_exactly_like_one_that_does_not_exist(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    pet_id = created["pet_profile"]["id"]
    from packages.bootstrap.container import get_container
    from packages.core.application.ports.auth_provider import AuthenticatedUser

    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner, "get_current_user", lambda: AuthenticatedUser(id="owner-b", email="b@example.com")
    )

    other = client.get(f"/pets/{pet_id}")
    missing = client.get("/pets/inventato")

    assert other.status_code == missing.status_code == 404
    assert other.json() == missing.json()


def test_other_refusals_stay_400(client: TestClient) -> None:
    response = client.post("/chat", json={"pet_id": "p", "user_message": "   "})

    assert response.status_code in (400, 404)
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    empty = client.post(
        "/chat", json={"pet_id": created["pet_profile"]["id"], "user_message": "   "}
    )
    assert empty.status_code == 400
    assert empty.json()["detail"] == "user_message must not be empty"
