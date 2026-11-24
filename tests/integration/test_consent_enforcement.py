"""While the Terms and the Privacy notice are not accepted at the current version
the protected routes answer `consent_required`; the routes needed to accept, leave
or look at one's data stay open. Off unless CONSENT_ENFORCEMENT_ENABLED."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import (
    AccountConsents,
    AccountConsentType,
    ConsentRecord,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
)

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
MANDATORY = tuple(sorted(AccountConsentType.MANDATORY))


class _World:
    def __init__(self) -> None:
        self.user = USER_A


def _clear_guard_caches() -> None:
    provider = get_container().auth_provider
    provider._blocked.clear()  # type: ignore[attr-defined]
    provider._consent_missing.clear()  # type: ignore[attr-defined]


@pytest.fixture
def world(monkeypatch: pytest.MonkeyPatch) -> Iterator[_World]:
    container = get_container()
    state = _World()
    monkeypatch.setattr(
        container, "account_consents_repository", InMemoryAccountConsentsRepository()
    )
    monkeypatch.setattr(
        container,
        "settings",
        container.settings.model_copy(update={"consent_enforcement_enabled": True}),
    )
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=state.user, email="owner@example.com"),
    )
    _clear_guard_caches()
    yield state
    _clear_guard_caches()


def _accept(
    owner_id: str,
    *,
    version_of: dict[str, str] | None = None,
    without: tuple[str, ...] = (),
) -> None:
    repository = get_container().account_consents_repository
    versions = {key: CURRENT_VERSIONS[key] for key in MANDATORY if key not in without}
    versions |= version_of or {}
    repository.save(  # type: ignore[attr-defined]
        AccountConsents(
            owner_id=owner_id,
            consents={key: ConsentRecord(granted=True, version=v) for key, v in versions.items()},
        )
    )


def _consent(client: TestClient, key: str, granted: bool = True) -> None:
    response = client.post("/account/consents", json={"consent_key": key, "granted": granted})
    assert response.status_code == 200


def test_protected_routes_refuse_until_the_terms_are_accepted(world: _World) -> None:
    refused = TestClient(app).get("/pets")

    assert refused.status_code == 403
    assert refused.json() == {"detail": "consent_required", "code": "consent_required"}


def test_the_routes_to_accept_leave_or_look_stay_open(world: _World) -> None:
    client = TestClient(app)

    assert client.get("/account/consents").status_code == 200
    assert client.get("/legal/consents").status_code == 200
    assert client.get("/account/session").status_code == 200
    assert client.get("/account/export").status_code != 403
    assert client.get("/account/deletion").status_code == 200
    assert client.get("/account/age").status_code == 200


def test_whoever_declines_a_new_version_can_still_pause_or_cancel_a_deletion(
    world: _World,
) -> None:
    client = TestClient(app)

    assert client.get("/pets").status_code == 403
    paused = client.post("/account/pause")
    assert paused.status_code == 200 and paused.json()["paused"] is True
    # The cancellation of a deletion was already open (the closed-account door).
    assert client.post("/account/deletion/cancel").status_code != 403


def test_a_text_shown_at_another_version_is_refused_on_the_route_with_a_400(
    world: _World,
) -> None:
    """The real HTTP answer (docs/compliance/04): `ValidationError` is a 400 whose `detail` is
    the code the app reads; nothing is recorded. An app that sends no version is still served."""
    client = TestClient(app)

    refused = client.post(
        "/account/consents",
        json={"consent_key": "terms_of_service", "granted": True, "shown_version": "v0"},
    )
    assert refused.status_code == 400
    assert refused.json() == {"detail": "consent_version_mismatch"}
    assert client.get("/pets").status_code == 403  # still not accepted

    undeclared = client.post(
        "/account/consents", json={"consent_key": "terms_of_service", "granted": True}
    )
    assert undeclared.status_code == 200


def test_accepting_through_the_consent_route_opens_everything_at_once(world: _World) -> None:
    client = TestClient(app)
    assert client.get("/pets").status_code == 403

    for key in MANDATORY:
        _consent(client, key)

    # The very next request: the cached "missing" was dropped.
    assert client.get("/pets").status_code == 200


def test_only_some_of_the_mandatory_consents_is_not_enough(world: _World) -> None:
    client = TestClient(app)
    _consent(client, AccountConsentType.TERMS_OF_SERVICE)
    assert client.get("/pets").status_code == 403  # the Privacy notice is still missing
    _consent(client, AccountConsentType.PRIVACY_POLICY)
    assert client.get("/pets").status_code == 200


def test_the_emergency_notice_closes_the_chat_and_nothing_else(world: _World) -> None:
    """Owner, 24/11/2026: the clause is a condition of the chat, never of the app."""
    _accept(USER_A, without=(AccountConsentType.EMERGENCY_NOTICE,))
    client = TestClient(app)
    message = {"pet_id": "nobody", "user_message": "ciao"}

    for path in ("/pets", "/conversations", "/reminders", "/account/session"):
        assert client.get(path).status_code != 403, path
    refused = client.post("/chat", json=message)
    assert refused.status_code == 403 and refused.json()["code"] == "consent_required"
    edited = client.put("/conversations/x/messages/y", json={"user_message": "ciao"})
    assert edited.status_code == 403
    assert client.get("/conversations/x/summary").status_code == 403
    upload = client.post(
        "/chat-attachments", data={"pet_id": "x"}, files={"file": ("a.jpg", b"x", "image/jpeg")}
    )
    assert upload.status_code == 403

    _consent(client, AccountConsentType.EMERGENCY_NOTICE)
    # Whatever it answers now (there is no such pet), it is not the gate any more.
    assert client.post("/chat", json=message).status_code != 403


def test_an_account_that_accepted_terms_v1_before_the_clause_is_asked_again(
    world: _World,
) -> None:
    """Existing accounts: Terms at the old version and no emergency notice. Everyone
    must accept the new Terms before going on (the dedicated box comes with the chat)."""
    _accept(
        USER_A,
        version_of={AccountConsentType.TERMS_OF_SERVICE: "v1"},
        without=(AccountConsentType.EMERGENCY_NOTICE,),
    )
    client = TestClient(app)
    assert client.get("/pets").status_code == 403

    _consent(client, AccountConsentType.TERMS_OF_SERVICE)
    assert client.get("/pets").status_code == 200


def test_an_older_version_of_the_emergency_notice_asks_again_before_the_chat(
    world: _World,
) -> None:
    _accept(USER_A, version_of={AccountConsentType.EMERGENCY_NOTICE: "an-older-version"})
    client = TestClient(app)
    assert client.get("/pets").status_code == 200
    refused = client.post("/chat", json={"pet_id": "nobody", "user_message": "ciao"})
    assert refused.status_code == 403


def test_the_emergency_notice_cannot_be_declined_or_revoked(world: _World) -> None:
    client = TestClient(app)
    response = client.post(
        "/account/consents",
        json={"consent_key": AccountConsentType.EMERGENCY_NOTICE, "granted": False},
    )
    assert response.status_code in (400, 422)


def test_an_acceptance_of_an_older_version_asks_again(world: _World) -> None:
    _accept(USER_A, version_of={AccountConsentType.PRIVACY_POLICY: "an-older-version"})
    assert TestClient(app).get("/pets").status_code == 403


def test_a_declined_optional_consent_never_blocks(world: _World) -> None:
    _accept(USER_A)
    client = TestClient(app)
    _consent(client, AccountConsentType.MARKETING_EMAIL, granted=False)
    assert client.get("/pets").status_code == 200


def test_user_b_is_judged_on_his_own_consents_only(world: _World) -> None:
    _accept(USER_A)
    client = TestClient(app)
    assert client.get("/pets").status_code == 200  # A accepted

    world.user = USER_B
    assert client.get("/pets").status_code == 403  # B did not: A's acceptance does not count

    for key in MANDATORY:
        _consent(client, key)
    assert client.get("/pets").status_code == 200

    world.user = USER_A
    assert client.get("/pets").status_code == 200


def test_it_is_off_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    container = get_container()
    monkeypatch.setattr(
        container, "account_consents_repository", InMemoryAccountConsentsRepository()
    )
    inner = container.auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner, "get_current_user", lambda: AuthenticatedUser(id=USER_B, email="owner@example.com")
    )
    _clear_guard_caches()

    assert container.settings.consent_enforcement_enabled is False
    assert TestClient(app).get("/pets").status_code == 200


def test_a_failed_lookup_lets_the_caller_through(
    world: _World, monkeypatch: pytest.MonkeyPatch
) -> None:
    class Broken:
        def get(self, owner_id: str) -> None:
            raise RuntimeError("table missing")

    monkeypatch.setattr(get_container(), "account_consents_repository", Broken())
    assert TestClient(app).get("/pets").status_code == 200


def test_legal_texts_accept_language_as_a_parameter_too(world: _World) -> None:
    client = TestClient(app)
    assert client.get("/legal/consents", params={"language": "fr"}).json()["language"] == "fr"
    both = client.get("/legal/consents", params={"lang": "es", "language": "fr"})
    assert both.json()["language"] == "es"
