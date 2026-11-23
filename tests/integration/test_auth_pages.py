"""The page a sign-up confirmation link lands on: five languages, neutral, nothing active,
nothing echoed, never cached."""

from html import escape

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from apps.api.routes.auth_pages import APP_LINK, pick_language

client = TestClient(app)


@pytest.mark.parametrize(
    ("header", "language", "title", "button"),
    [
        (None, "it", "Torna all'app Quokka", "Apri Quokka"),
        ("it-IT,it;q=0.9", "it", "Torna all'app Quokka", "Apri Quokka"),
        ("en-GB,en;q=0.8", "en", "Back to the Quokka app", "Open Quokka"),
        ("es-ES", "es", "Vuelve a la app de Quokka", "Abrir Quokka"),
        ("fr-CH, fr;q=0.9", "fr", "Retour à l'application Quokka", "Ouvrir Quokka"),
        ("de-DE,de;q=0.9,en;q=0.5", "de", "Zurück zur Quokka-App", "Quokka öffnen"),
        ("ja-JP,ja;q=0.9", "it", "Torna all'app Quokka", "Apri Quokka"),
        ("ja-JP,fr;q=0.5", "fr", "Retour à l'application Quokka", "Ouvrir Quokka"),
    ],
)
def test_the_page_follows_the_browser_language(
    header: str | None, language: str, title: str, button: str
) -> None:
    headers = {"Accept-Language": header} if header else {}
    response = client.get("/auth/confirmed", headers=headers)

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert f'lang="{language}"' in response.text
    assert escape(title) in response.text
    assert escape(button) in response.text
    assert pick_language(header) == language


def test_the_page_does_not_claim_the_address_was_confirmed() -> None:
    text = client.get("/auth/confirmed").text
    assert "Indirizzo confermato" not in text
    assert "Se hai appena confermato" in text and "scaduto o già usato" in text


def test_with_an_error_in_the_address_only_the_invalid_link_part_is_shown() -> None:
    for query in ("?error=access_denied", "?error_code=otp_expired&error_description=x"):
        text = client.get("/auth/confirmed" + query).text
        assert "non è valido" in text
        assert "Se hai appena confermato" not in text


def test_the_button_opens_the_app_without_any_code() -> None:
    text = client.get("/auth/confirmed?code=SECRET123").text
    assert f'href="{APP_LINK}"' in text
    assert APP_LINK == "vetapp://auth-callback"


def test_the_page_runs_nothing_loads_nothing_and_echoes_nothing() -> None:
    response = client.get(
        "/auth/confirmed?code=SECRET123&error=<script>alert(1)</script>&error_description=BOOM"
    )
    text = response.text.lower()

    assert "<script" not in text and "<img" not in text and "<form" not in text
    assert "http://" not in text and "https://" not in text and "src=" not in text
    assert "secret123" not in text and "alert(1)" not in text and "boom" not in text
    policy = response.headers["content-security-policy"]
    assert "default-src 'none'" in policy and "script-src" not in policy
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"


def test_the_page_is_never_cached() -> None:
    assert client.get("/auth/confirmed?code=abc").headers["cache-control"] == "no-store"
