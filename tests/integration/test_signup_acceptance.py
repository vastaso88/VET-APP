"""Registration through the API records the acceptance of Terms and Privacy,
and the public consent catalogue follows the signed-in account's language."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
)

BODY = {"email": "new.owner@example.com", "password": "synthetic"}


@pytest.fixture
def consents(monkeypatch: pytest.MonkeyPatch) -> Iterator[InMemoryAccountConsentsRepository]:
    container = get_container()
    repository = InMemoryAccountConsentsRepository()
    monkeypatch.setattr(container, "account_consents_repository", repository)
    yield repository


def test_signup_without_the_acceptance_is_refused_and_creates_nothing(
    consents: InMemoryAccountConsentsRepository,
) -> None:
    response = TestClient(app).post("/auth/signup", json=BODY)

    assert response.status_code in (400, 422)
    assert "accept_terms_required" in response.text
    assert consents.get(get_container().settings.bootstrap_user_id) is None

    refused = TestClient(app).post("/auth/signup", json={**BODY, "accept_terms": False})
    assert refused.status_code in (400, 422)


def test_signup_with_the_acceptance_records_terms_and_privacy_with_version_and_date(
    consents: InMemoryAccountConsentsRepository,
) -> None:
    response = TestClient(app).post("/auth/signup", json={**BODY, "accept_terms": True})

    assert response.status_code == 200
    assert response.json()["consents_recorded"] is True
    owner_id = response.json()["user"]["id"]
    recorded = consents.get(owner_id)
    assert recorded is not None
    for key in (AccountConsentType.TERMS_OF_SERVICE, AccountConsentType.PRIVACY_POLICY):
        record = recorded.consents[key]
        assert record.granted is True
        assert record.version == CURRENT_VERSIONS[key]
        assert record.decided_at is not None
    # Nothing optional is switched on by registering.
    assert set(recorded.consents) == {
        AccountConsentType.TERMS_OF_SERVICE,
        AccountConsentType.PRIVACY_POLICY,
    }


def test_a_failure_to_record_does_not_lose_the_new_session(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    container = get_container()

    def boom() -> object:
        raise RuntimeError("storage down")

    monkeypatch.setattr(container, "set_account_consent_service", boom)

    response = TestClient(app).post("/auth/signup", json={**BODY, "accept_terms": True})

    assert response.status_code == 200
    assert response.json()["consents_recorded"] is False
    assert response.json()["access_token"]


@pytest.fixture
def signed_in_locale(monkeypatch: pytest.MonkeyPatch) -> Iterator[dict[str, str]]:
    container = get_container()
    state = {"locale": "de"}
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(
            id="11111111-1111-4111-8111-111111111111",
            email="owner@example.com",
            preferred_locale=state["locale"],  # type: ignore[arg-type]
        ),
    )
    yield state


def test_the_consent_catalogue_uses_the_signed_in_accounts_language(
    signed_in_locale: dict[str, str],
) -> None:
    client = TestClient(app)

    assert client.get("/legal/consents").json()["language"] == "de"
    signed_in_locale["locale"] = "en"
    assert client.get("/legal/consents").json()["language"] == "en"


def test_an_explicit_lang_still_wins_over_the_account(signed_in_locale: dict[str, str]) -> None:
    body = TestClient(app).get("/legal/consents", params={"lang": "fr"}).json()
    assert body["language"] == "fr"


def test_without_a_signed_in_account_the_header_decides_then_italian(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from packages.shared.errors.base import AuthenticationError

    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]

    def not_signed_in() -> AuthenticatedUser:
        raise AuthenticationError("no token")

    monkeypatch.setattr(inner, "get_current_user", not_signed_in)
    client = TestClient(app)

    assert (
        client.get("/legal/consents", headers={"Accept-Language": "es-ES"}).json()["language"]
        == "es"
    )
    assert client.get("/legal/consents").json()["language"] == "it"
