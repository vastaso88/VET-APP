"""POST /chat and PUT …/messages/{id} refuse messages longer than the limit
(2026-10-14: 200 KB of text cost ~2 s of CPU in the safety gate), and the
app's composer uses the same limit."""

import re
from pathlib import Path

from fastapi.testclient import TestClient

from apps.api.main import app
from apps.api.schemas.chat import MAX_USER_MESSAGE_CHARS
from packages.bootstrap.container import get_container, reset_container
from packages.core.domain.pet_profile.models import PetProfile

_REMOTE = (
    Path(__file__).resolve().parents[2]
    / "apps/mobile_app/lib/features/chat/data/chat_remote_data_source.dart"
)


def _client_with_pet() -> TestClient:
    reset_container()
    client = TestClient(app)
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.pet_profile_repository.save(
        PetProfile(id="pet-len", owner_id=user.id, name="Birba", species="Cane")
    )
    return client


def test_a_message_over_the_limit_is_refused_before_anything_runs() -> None:
    client = _client_with_pet()
    try:
        response = client.post(
            "/chat",
            json={"pet_id": "pet-len", "user_message": "a" * (MAX_USER_MESSAGE_CHARS + 1)},
        )

        assert response.status_code == 422
        [error] = response.json()["detail"]
        # The shape the app recognises (chat_remote_data_source.dart).
        assert error["type"] == "string_too_long"
        assert "user_message" in error["loc"]
        assert get_container().conversation_repository.list_by_pet("pet-len") == []
    finally:
        reset_container()


def test_a_message_at_the_limit_is_accepted() -> None:
    client = _client_with_pet()
    try:
        response = client.post(
            "/chat",
            json={"pet_id": "pet-len", "user_message": "a" * MAX_USER_MESSAGE_CHARS},
        )

        assert response.status_code == 200
    finally:
        reset_container()


def test_an_edit_over_the_limit_is_refused_the_same_way() -> None:
    client = _client_with_pet()
    try:
        sent = client.post(
            "/chat",
            json={"pet_id": "pet-len", "user_message": "ciao", "client_message_id": "c1"},
        ).json()

        response = client.put(
            f"/conversations/{sent['conversation']['id']}/messages/c1",
            json={"user_message": "a" * (MAX_USER_MESSAGE_CHARS + 1)},
        )

        assert response.status_code == 422
        assert response.json()["detail"][0]["type"] == "string_too_long"
    finally:
        reset_container()


def test_the_app_uses_the_same_limit_as_the_backend() -> None:
    source = _REMOTE.read_text(encoding="utf-8")
    declaration = re.search(r"const chatMaxMessageLength = (\d+);", source)
    assert declaration is not None, "chat_remote_data_source.dart no longer declares the limit"

    assert int(declaration.group(1)) == MAX_USER_MESSAGE_CHARS
