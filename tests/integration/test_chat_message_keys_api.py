"""QK-03b through the real API and the container: the reservation is wired into the chat, the
hourly prune route is protected like the other lifecycle routes and harmless while the table is
missing, and the account deletion and export know the table."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.message_key_repository import MessageKeysUnavailable
from packages.infrastructure.persistence.supabase.supabase_account_eraser import OWNER_TABLES
from packages.infrastructure.persistence.supabase.supabase_account_exporter import EXPORTED_TABLES

SECRET = "test-scheduler-secret"
HEADER = "X-VetApp-Scheduler"
ROUTE = "/admin/lifecycle/prune-chat-message-keys"


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setenv("ADMIN_SCHEDULER_SECRET", SECRET)
    return TestClient(app)


def _pet_id(client: TestClient) -> str:
    created = client.post("/pets", json={"name": "Nebbia", "species": "cat"}).json()
    pet_id: str = created["pet_profile"]["id"]
    return pet_id


def test_the_container_gives_the_chat_service_the_shared_reservation() -> None:
    container = get_container()

    service = container.send_chat_message_service()

    claims = service._message_claims  # noqa: SLF001
    assert claims is not None
    assert claims._keys is container.chat_message_key_repository  # noqa: SLF001
    # every request builds a new service but they all share the one repository
    again = container.send_chat_message_service()._message_claims  # noqa: SLF001
    assert again is not None
    assert again._keys is container.chat_message_key_repository  # noqa: SLF001


def test_a_message_through_the_api_leaves_an_answered_key_and_a_retry_is_replayed(
    client: TestClient,
) -> None:
    pet_id = _pet_id(client)
    body = {"pet_id": pet_id, "user_message": "Starnutisce", "client_message_id": "user-qk03b-1"}

    first = client.post("/chat", json=body)
    retry = client.post("/chat", json=body)

    assert first.status_code == 200 and retry.status_code == 200
    assert retry.json()["reply"]["id"] == first.json()["reply"]["id"]
    keys = get_container().chat_message_key_repository
    stored = [k for k in keys.keys_of("demo-user") if k.client_message_id == "user-qk03b-1"]  # type: ignore[attr-defined]
    assert len(stored) == 1
    assert stored[0].answered_reply_id == first.json()["reply"]["id"]
    assert stored[0].conversation_id == first.json()["conversation"]["id"]


def test_the_prune_route_needs_the_scheduler_token(client: TestClient) -> None:
    assert client.post(ROUTE).status_code in (401, 403)
    assert client.post(ROUTE, headers={HEADER: "wrong"}).status_code in (401, 403)


def test_the_prune_route_counts_what_it_removed(client: TestClient) -> None:
    body = client.post(ROUTE, headers={HEADER: SECRET})

    assert body.status_code == 200
    assert body.json()["table_available"] is True and isinstance(body.json()["deleted"], int)


def test_the_prune_route_is_green_while_the_table_does_not_exist_yet(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    keys = get_container().chat_message_key_repository

    def missing(cutoff: object) -> int:
        raise MessageKeysUnavailable("missing")

    monkeypatch.setattr(keys, "purge_before", missing)

    response = client.post(ROUTE, headers={HEADER: SECRET})

    assert response.status_code == 200  # the hourly job must not go red before the SQL is run
    assert response.json()["deleted"] == 0 and response.json()["table_available"] is False


def test_account_deletion_and_export_cover_the_table() -> None:
    assert ("chat_message_keys", "owner_id") in OWNER_TABLES
    assert "chat_message_keys" in EXPORTED_TABLES
