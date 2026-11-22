"""QK-05: a request asks the identity provider who the caller is ONCE, however many
dependencies and the handler need it, and the answer never travels to another request.

The real app, the real middleware and the real SupabaseAuthProvider run here; only the
Supabase admin client is replaced by a fake that counts `auth.get_user` calls per token
and knows which tokens are revoked. Everything is local: no network, example.com only."""

from __future__ import annotations

import threading
import time
from collections import Counter
from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.age.models import AccountAge
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.auth import supabase_auth_provider as module
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
)
from packages.shared.auth_context import access_token_context

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
TOKEN_A = "token-of-owner-a"
TOKEN_B = "token-of-owner-b"

LISTING_BODY = {
    "private_seller_declared": True,
    "title": "Trasportino",
    "category": "kennels_carriers",
    "condition": "good",
    "latitude": 45.46,
    "longitude": 9.19,
}


class _FakeAuth:
    """`auth.get_user(token)` as Supabase answers it, with a counter."""

    def __init__(self) -> None:
        self.calls: Counter[str] = Counter()
        self.revoked: set[str] = set()
        self.delay = 0.0
        self.users = {
            TOKEN_A: SimpleNamespace(
                id=USER_A,
                email="a@example.com",
                user_metadata={},
                email_confirmed_at="2026-01-01",
            ),
            TOKEN_B: SimpleNamespace(
                id=USER_B,
                email="b@example.com",
                user_metadata={},
                email_confirmed_at="2026-01-01",
            ),
        }
        self._lock = threading.Lock()

    def get_user(self, token: str) -> SimpleNamespace:
        with self._lock:
            self.calls[token] += 1
        if self.delay:
            time.sleep(self.delay)
        if token in self.revoked or token not in self.users:
            raise module.AuthApiError("session revoked", 401, "session_not_found")
        return SimpleNamespace(user=self.users[token])


@pytest.fixture
def fake_auth(monkeypatch: pytest.MonkeyPatch) -> Iterator[_FakeAuth]:
    """The container's auth guard keeps its own rules (age, deletion, consent); only the
    inner provider becomes the real Supabase one on top of the counting fake."""
    container = get_container()
    fake = _FakeAuth()
    client: Any = SimpleNamespace(auth=fake)
    monkeypatch.setattr(module, "_SUPABASE_IMPORT_ERROR", None)
    monkeypatch.setattr(
        container.auth_provider, "_inner", module.SupabaseAuthProvider(client, client)
    )
    container.auth_provider._blocked.clear()  # type: ignore[attr-defined]
    container.auth_provider._consent_missing.clear()  # type: ignore[attr-defined]
    yield fake


def _as(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _adults(monkeypatch: pytest.MonkeyPatch) -> None:
    class _EveryoneIsAdult(type(get_container().account_age_repository)):  # type: ignore[misc]
        def get(self, owner_id: str) -> AccountAge | None:
            return super().get(owner_id) or AccountAge(
                owner_id=owner_id,
                birth_date=date(1980, 1, 1),
                declared_at=datetime(2026, 1, 1, tzinfo=UTC),
            )

    monkeypatch.setattr(get_container(), "account_age_repository", _EveryoneIsAdult())


@pytest.fixture
def adults(monkeypatch: pytest.MonkeyPatch) -> None:
    _adults(monkeypatch)


def _pet_names_of(owner_id: str) -> set[str]:
    repository = get_container().pet_profile_repository
    return {pet.name for pet in repository.list_by_owner(owner_id)}


# --- the headline criterion -------------------------------------------------------


@pytest.mark.usefixtures("adults")
def test_a_successful_post_pets_validates_the_token_once(fake_auth: _FakeAuth) -> None:
    response = TestClient(app).post(
        "/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A)
    )

    assert response.status_code == 200
    assert response.json()["pet_profile"]["owner_id"] == USER_A
    assert fake_auth.calls[TOKEN_A] == 1  # was 2: the dependency and the handler


@pytest.mark.usefixtures("adults")
@pytest.mark.parametrize(
    ("method", "path", "body"),
    [
        ("GET", "/pets", None),
        ("GET", "/marketplace/restriction", None),
        ("POST", "/marketplace/listings", LISTING_BODY),
        ("GET", "/subscription/status", None),
    ],
)
def test_other_routes_with_several_dependencies_validate_once(
    fake_auth: _FakeAuth, method: str, path: str, body: dict[str, Any] | None
) -> None:
    response = TestClient(app).request(method, path, json=body, headers=_as(TOKEN_A))

    assert response.status_code == 200, response.text
    assert fake_auth.calls[TOKEN_A] == 1


@pytest.mark.usefixtures("adults")
def test_the_same_token_on_the_next_request_is_validated_again(fake_auth: _FakeAuth) -> None:
    client = TestClient(app)
    client.get("/pets", headers=_as(TOKEN_A))
    client.get("/pets", headers=_as(TOKEN_A))

    assert fake_auth.calls[TOKEN_A] == 2  # one per request, never carried over


# --- two owners at the same time --------------------------------------------------


@pytest.mark.usefixtures("adults")
def test_two_owners_in_overlapping_requests_never_swap_identity(fake_auth: _FakeAuth) -> None:
    fake_auth.delay = 0.02  # keeps the two requests inside each other
    rounds = 6
    barrier = threading.Barrier(2)
    failures: list[str] = []

    def worker(token: str, owner_id: str, prefix: str) -> None:
        client = TestClient(app)
        for i in range(rounds):
            try:
                barrier.wait(timeout=10)
            except threading.BrokenBarrierError:  # pragma: no cover
                failures.append("barrier")
                return
            response = client.post(
                "/pets", json={"name": f"{prefix}-{i}", "species": "dog"}, headers=_as(token)
            )
            if (
                response.status_code != 200
                or response.json()["pet_profile"]["owner_id"] != owner_id
            ):
                failures.append(f"{prefix}-{i}: {response.status_code} {response.text[:120]}")

    threads = [
        threading.Thread(target=worker, args=(TOKEN_A, USER_A, "A")),
        threading.Thread(target=worker, args=(TOKEN_B, USER_B, "B")),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)

    assert failures == []
    assert _pet_names_of(USER_A) == {f"A-{i}" for i in range(rounds)}
    assert _pet_names_of(USER_B) == {f"B-{i}" for i in range(rounds)}
    assert fake_auth.calls[TOKEN_A] == rounds and fake_auth.calls[TOKEN_B] == rounds


@pytest.mark.usefixtures("adults")
def test_user_b_cannot_read_or_change_a_pet_of_user_a(fake_auth: _FakeAuth) -> None:
    client = TestClient(app)
    created = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))
    pet_id = created.json()["pet_profile"]["id"]

    read = client.get(f"/pets/{pet_id}", headers=_as(TOKEN_B))
    change = client.put(
        f"/pets/{pet_id}", json={"name": "Hacked", "species": "dog"}, headers=_as(TOKEN_B)
    )
    consent = client.put(
        f"/pets/{pet_id}/medical-record-consent", json={"granted": True}, headers=_as(TOKEN_B)
    )

    for refused in (read, change, consent):
        assert refused.status_code >= 400
    assert "pet_profile not found" in read.text
    assert client.get("/pets", headers=_as(TOKEN_B)).json()["pet_profiles"] == []
    assert _pet_names_of(USER_A) == {"Milo"}


# --- revoked session --------------------------------------------------------------


@pytest.mark.usefixtures("adults")
def test_a_revoked_session_is_refused_and_never_served_from_an_earlier_request(
    fake_auth: _FakeAuth,
) -> None:
    client = TestClient(app)
    assert client.get("/pets", headers=_as(TOKEN_A)).status_code == 200

    fake_auth.revoked.add(TOKEN_A)

    refused = client.post("/pets", json={"name": "Late", "species": "dog"}, headers=_as(TOKEN_A))
    assert refused.status_code == 401
    assert "Late" not in _pet_names_of(USER_A)
    # Failures are not remembered either: still checked, still refused.
    assert client.get("/pets", headers=_as(TOKEN_A)).status_code == 401
    assert client.get("/pets", headers=_as(TOKEN_B)).status_code == 200


def test_no_token_is_refused_without_asking_supabase(fake_auth: _FakeAuth) -> None:
    assert TestClient(app).get("/pets").status_code == 401
    assert sum(fake_auth.calls.values()) == 0


# --- the gates still run on every call (age, consent, plan, recovery routes) ------


def test_a_declared_under_age_account_is_still_refused(fake_auth: _FakeAuth) -> None:
    today = utc_now().date()
    get_container().account_age_repository.create(
        AccountAge(
            owner_id=USER_A,
            birth_date=today.replace(year=today.year - 12),
            declared_at=utc_now(),
        )
    )
    client = TestClient(app)

    refused = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))
    assert refused.status_code == 403
    assert refused.json()["code"] == "under_minimum_age"
    assert fake_auth.calls[TOKEN_A] == 1
    # The recovery route a closed account may use still answers, on one validation.
    fake_auth.calls.clear()
    assert client.get("/account/age", headers=_as(TOKEN_A)).status_code == 200
    assert fake_auth.calls[TOKEN_A] == 1
    # Another owner is not affected by A's block.
    assert client.get("/pets", headers=_as(TOKEN_B)).status_code == 200


@pytest.mark.usefixtures("adults")
def test_missing_consent_blocks_but_the_consent_routes_stay_open(
    fake_auth: _FakeAuth, monkeypatch: pytest.MonkeyPatch
) -> None:
    container = get_container()
    monkeypatch.setattr(
        container, "account_consents_repository", InMemoryAccountConsentsRepository()
    )
    monkeypatch.setattr(
        container,
        "settings",
        container.settings.model_copy(update={"consent_enforcement_enabled": True}),
    )
    client = TestClient(app)

    refused = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))
    assert refused.status_code == 403 and refused.json()["code"] == "consent_required"
    assert fake_auth.calls[TOKEN_A] == 1

    fake_auth.calls.clear()
    assert client.get("/account/consents", headers=_as(TOKEN_A)).status_code == 200
    assert fake_auth.calls[TOKEN_A] == 1


@pytest.mark.usefixtures("adults")
def test_an_expired_trial_is_refused_on_one_validation(fake_auth: _FakeAuth) -> None:
    get_container().subscription_repository.save(
        Subscription(owner_id=USER_A, trial_ends_at=utc_now() - timedelta(days=1))
    )

    refused = TestClient(app).post(
        "/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A)
    )

    assert refused.status_code == 402
    assert fake_auth.calls[TOKEN_A] == 1


# --- the memo itself --------------------------------------------------------------


def test_the_memo_is_bound_to_its_token_and_is_empty_outside_a_request(
    fake_auth: _FakeAuth, monkeypatch: pytest.MonkeyPatch
) -> None:
    provider = get_container().auth_provider._inner  # type: ignore[attr-defined]

    # Outside a request (a script, a job: no memo was opened) nothing is remembered.
    monkeypatch.setattr(module, "get_access_token", lambda: TOKEN_A)
    provider.get_current_user()
    provider.get_current_user()
    assert fake_auth.calls[TOKEN_A] == 2
    monkeypatch.undo()

    # Inside one, a call made with a different token is not served from what was
    # remembered for the first.
    monkeypatch.setattr(module, "_SUPABASE_IMPORT_ERROR", None)
    fake_auth.calls.clear()
    with access_token_context(TOKEN_A):
        first = provider.get_current_user()
        provider.get_current_user()
        with access_token_context(TOKEN_B):  # a new context opens its own, empty memo
            second = provider.get_current_user()
    assert (first.id, second.id) == (USER_A, USER_B)
    assert fake_auth.calls == Counter({TOKEN_A: 1, TOKEN_B: 1})


def test_a_stale_memo_is_never_used_for_another_token(fake_auth: _FakeAuth) -> None:
    from packages.shared import auth_context

    provider = get_container().auth_provider._inner  # type: ignore[attr-defined]
    with access_token_context(TOKEN_A):
        assert provider.get_current_user().id == USER_A
        # The token changes while the memo is the same one (it must not happen, but if it
        # did, A's identity must not be handed to B).
        token_state = auth_context._access_token.set(TOKEN_B)
        try:
            assert provider.get_current_user().id == USER_B
        finally:
            auth_context._access_token.reset(token_state)


def test_a_caller_editing_its_user_does_not_change_the_next_answer(fake_auth: _FakeAuth) -> None:
    provider = get_container().auth_provider._inner  # type: ignore[attr-defined]
    with access_token_context(TOKEN_A):
        first: AuthenticatedUser = provider.get_current_user()
        first.email = "changed@example.com"
        assert provider.get_current_user().email == "a@example.com"
