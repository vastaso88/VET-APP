"""QK-05b: the subscription is read ONCE per request, however many dependencies and services
ask for it, and the outcome never travels to another request or another owner.

Real app, real middleware, real SupabaseAuthProvider on a counting fake admin client (as in
test_identity_once_per_request.py); the subscription repository counts its reads. Local only,
example.com addresses."""

from __future__ import annotations

import threading
from collections import Counter
from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.age.models import AccountAge
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.infrastructure.auth import supabase_auth_provider as module

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
    def __init__(self) -> None:
        self.users = {
            TOKEN_A: SimpleNamespace(
                id=USER_A, email="a@example.com", user_metadata={}, email_confirmed_at="2026-01-01"
            ),
            TOKEN_B: SimpleNamespace(
                id=USER_B, email="b@example.com", user_metadata={}, email_confirmed_at="2026-01-01"
            ),
        }

    def get_user(self, token: str) -> SimpleNamespace:
        return SimpleNamespace(user=self.users[token])


@pytest.fixture(autouse=True)
def real_provider(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    container = get_container()
    client: Any = SimpleNamespace(auth=_FakeAuth())
    monkeypatch.setattr(module, "_SUPABASE_IMPORT_ERROR", None)
    monkeypatch.setattr(
        container.auth_provider, "_inner", module.SupabaseAuthProvider(client, client)
    )

    class _EveryoneIsAdult(type(container.account_age_repository)):  # type: ignore[misc]
        def get(self, owner_id: str) -> AccountAge | None:
            return super().get(owner_id) or AccountAge(
                owner_id=owner_id,
                birth_date=date(1980, 1, 1),
                declared_at=datetime(2026, 1, 1, tzinfo=UTC),
            )

    monkeypatch.setattr(container, "account_age_repository", _EveryoneIsAdult())
    yield


class _Reads:
    """Counts the subscription reads per owner, through the repository the services share."""

    def __init__(self, monkeypatch: pytest.MonkeyPatch) -> None:
        self.by_owner: Counter[str] = Counter()
        repository = get_container().subscription_repository
        original = repository.get
        lock = threading.Lock()

        def counting(owner_id: str) -> Subscription | None:
            with lock:
                self.by_owner[owner_id] += 1
            return original(owner_id)

        monkeypatch.setattr(repository, "get", counting)

    @property
    def total(self) -> int:
        return sum(self.by_owner.values())


@pytest.fixture
def reads(monkeypatch: pytest.MonkeyPatch) -> _Reads:
    return _Reads(monkeypatch)


@pytest.fixture
def memo_off(monkeypatch: pytest.MonkeyPatch) -> None:
    """The behaviour before QK-05b: the service never finds a memo."""
    monkeypatch.setattr(
        "packages.core.application.services.get_or_create_subscription.get_identity_memo",
        lambda: None,
    )


def _as(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _trial(owner_id: str, *, open_: bool) -> None:
    delta = timedelta(days=5) if open_ else timedelta(days=-1)
    get_container().subscription_repository.save(
        Subscription(owner_id=owner_id, trial_ends_at=utc_now() + delta)
    )


ROUTES = [
    ("POST", "/pets", {"name": "Milo", "species": "dog"}),
    ("POST", "/marketplace/listings", LISTING_BODY),
    ("GET", "/subscription/status", None),
]


@pytest.mark.parametrize(("method", "path", "body"), ROUTES)
def test_one_subscription_read_per_request(
    reads: _Reads, method: str, path: str, body: dict[str, Any] | None
) -> None:
    _trial(USER_A, open_=True)
    reads.by_owner.clear()

    response = TestClient(app).request(method, path, json=body, headers=_as(TOKEN_A))

    assert response.status_code == 200, response.text
    assert reads.by_owner == Counter({USER_A: 1})


def test_before_the_change_the_same_post_pets_read_it_twice(reads: _Reads, memo_off: None) -> None:
    """The measurement the esito quotes: with the memo off (the old behaviour) the access
    gate and the plan limits each read the subscription."""
    _trial(USER_A, open_=True)
    reads.by_owner.clear()

    response = TestClient(app).post(
        "/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A)
    )

    assert response.status_code == 200
    assert reads.by_owner[USER_A] == 2


def test_the_expired_trial_is_still_refused_with_the_same_402(reads: _Reads) -> None:
    _trial(USER_A, open_=False)
    reads.by_owner.clear()
    client = TestClient(app)

    refused = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))

    assert refused.status_code == 402
    assert refused.json()["code"] == "subscription_required"
    assert reads.by_owner[USER_A] == 1
    # What stays open to an owner without access is unchanged.
    assert client.get("/pets", headers=_as(TOKEN_A)).status_code == 200
    assert client.get("/subscription/status", headers=_as(TOKEN_A)).status_code == 200


def test_the_trial_ending_between_two_requests_changes_the_second_answer() -> None:
    client = TestClient(app)
    _trial(USER_A, open_=True)
    ok = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))
    assert ok.status_code == 200

    _trial(USER_A, open_=False)  # same token, same owner, a moment later
    refused = client.post("/pets", json={"name": "Luna", "species": "cat"}, headers=_as(TOKEN_A))

    assert refused.status_code == 402


def test_two_owners_at_the_same_time_each_get_their_own_subscription_answer() -> None:
    _trial(USER_A, open_=True)
    _trial(USER_B, open_=False)
    rounds = 8
    barrier = threading.Barrier(2)
    failures: list[str] = []

    def worker(token: str, expected: int, prefix: str) -> None:
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
            if response.status_code != expected:
                failures.append(f"{prefix}-{i}: {response.status_code}")

    threads = [
        threading.Thread(target=worker, args=(TOKEN_A, 200, "A")),
        threading.Thread(target=worker, args=(TOKEN_B, 402, "B")),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)

    assert failures == []
    repository = get_container().pet_profile_repository
    assert len(repository.list_by_owner(USER_A)) == rounds
    assert repository.list_by_owner(USER_B) == []


def test_a_plan_granted_to_one_owner_does_not_reach_another_owners_request(
    reads: _Reads,
) -> None:
    _trial(USER_A, open_=False)
    _trial(USER_B, open_=False)
    get_container().subscription_repository.save(
        Subscription(owner_id=USER_A, trial_ends_at=utc_now() - timedelta(days=1), plan="plus")
    )
    client = TestClient(app)

    assert (
        client.post(
            "/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A)
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/pets", json={"name": "Luna", "species": "cat"}, headers=_as(TOKEN_B)
        ).status_code
        == 402
    )


def _a_pet_of_owner_a(client: TestClient) -> str:
    created = client.post("/pets", json={"name": "Milo", "species": "dog"}, headers=_as(TOKEN_A))
    return str(created.json()["pet_profile"]["id"])


def test_a_chat_message_reads_the_subscription_once(reads: _Reads) -> None:
    _trial(USER_A, open_=True)
    client = TestClient(app)
    pet_id = _a_pet_of_owner_a(client)
    reads.by_owner.clear()

    response = client.post(
        "/chat", json={"pet_id": pet_id, "user_message": "Mangia poco"}, headers=_as(TOKEN_A)
    )

    assert response.status_code == 200, response.text
    assert reads.by_owner == Counter({USER_A: 1})


def test_before_the_change_a_chat_message_read_it_three_times(
    reads: _Reads, memo_off: None
) -> None:
    _trial(USER_A, open_=True)
    client = TestClient(app)
    pet_id = _a_pet_of_owner_a(client)
    reads.by_owner.clear()

    response = client.post(
        "/chat", json={"pet_id": pet_id, "user_message": "Mangia poco"}, headers=_as(TOKEN_A)
    )

    assert response.status_code == 200
    assert reads.by_owner[USER_A] == 3
