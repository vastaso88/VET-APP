"""Collaudo K28: an id that belongs to someone else must answer EXACTLY like one that does not
exist (same status, same code, same text), so a stranger can never learn that a chat, an
attachment, a pet or a walk exists. «Utente B» tries every id of «utente A» and an invented one,
and the two answers must be identical.

Two chat routes said «… does not belong to …» for another owner's id and «… not found» for an
invented one; the same pattern was in the upload, and in three walk services."""

from __future__ import annotations

import io
from collections.abc import Callable, Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.services.end_walk import EndWalkInput, EndWalkService
from packages.core.application.services.record_route_point import (
    RecordRoutePointInput,
    RecordRoutePointService,
)
from packages.core.application.services.start_walk import StartWalkInput, StartWalkService
from packages.core.domain.dog_walk.models import WalkSession
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryDogWalkRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ValidationError

OWNER_A = "11111111-1111-4111-8111-111111111111"
OWNER_B = "22222222-2222-4222-8222-222222222222"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


# --- the walk services (no route reaches them today, but they must not be an oracle either) ---


def _refusal(action: Callable[[], object]) -> str:
    with pytest.raises(ValidationError) as caught:
        action()
    return str(caught.value)


def test_a_walk_of_another_owner_answers_like_a_missing_one() -> None:
    walks = InMemoryDogWalkRepository()
    walk = walks.save(WalkSession(owner_id=OWNER_A, pet_id="pet-a"))

    def end(owner: str, walk_id: str) -> Callable[[], object]:
        return lambda: EndWalkService(walks).execute(EndWalkInput(walk_id=walk_id, owner_id=owner))

    def point(owner: str, walk_id: str) -> Callable[[], object]:
        return lambda: RecordRoutePointService(walks).execute(
            RecordRoutePointInput(
                walk_id=walk_id,
                owner_id=owner,
                coordinates=Coordinates(latitude=45.0, longitude=9.0),
            )
        )

    for make in (end, point):
        stolen = _refusal(make(OWNER_B, walk.id))
        missing = _refusal(make(OWNER_B, "does-not-exist"))
        assert stolen == missing == "walk not found"
    # The owner still ends it, and nothing was changed by B's attempts.
    assert walks.get(walk.id) is not None and walks.get(walk.id).status == "in_progress"  # type: ignore[union-attr]
    assert EndWalkService(walks).execute(EndWalkInput(walk_id=walk.id, owner_id=OWNER_A))


def test_starting_a_walk_with_a_pet_of_another_owner_answers_like_a_missing_pet() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id=OWNER_A, name="Milo", species="Cane"))
    walks = InMemoryDogWalkRepository()
    service = StartWalkService(walks, pets)

    stolen = _refusal(lambda: service.execute(StartWalkInput(owner_id=OWNER_B, pet_id="pet-a")))
    missing = _refusal(lambda: service.execute(StartWalkInput(owner_id=OWNER_B, pet_id="nope")))

    assert stolen == missing == "pet_profile not found"
    assert walks.list_by_owner(OWNER_B) == []


# --- the chat routes ---------------------------------------------------------------------


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[Callable[[str], None]]:
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current = {"id": OWNER_A}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=current["id"], email="owner@example.com"),
    )

    def switch(owner_id: str) -> None:
        current["id"] = owner_id

    yield switch


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


def _same(stolen: Any, missing: Any) -> None:
    # 400 today, 404 once the K08 change lands: what matters is that both are the same.
    assert stolen.status_code == missing.status_code
    assert stolen.status_code in (400, 404)
    assert stolen.json() == missing.json()
    assert "not found" in stolen.json()["detail"]
    assert "belong" not in stolen.text


def test_reporting_a_reply_of_someone_elses_chat_answers_like_an_invented_chat(
    client: TestClient, as_user: Callable[[str], None]
) -> None:
    pet = client.post("/pets", json={"name": "Milo", "species": "Cane"}).json()["pet_profile"]
    chat = client.post("/chat", json={"pet_id": pet["id"], "user_message": "Mangia poco"}).json()
    conversation_id = chat["conversation"]["id"]
    message_id = chat["reply"]["id"]
    as_user(OWNER_B)

    def report(conversation: str) -> Any:
        return client.post(
            "/chat-response-reports",
            json={"conversation_id": conversation, "message_id": message_id, "reason": "other"},
        )

    _same(report(conversation_id), report("does-not-exist"))


def test_a_message_with_someone_elses_attachment_answers_like_an_invented_attachment(
    client: TestClient, as_user: Callable[[str], None]
) -> None:
    pet_a = client.post("/pets", json={"name": "Milo", "species": "Cane"}).json()["pet_profile"]
    uploaded = client.post(
        "/chat-attachments",
        data={"pet_id": pet_a["id"]},
        files={"file": ("zampa.png", io.BytesIO(PNG), "application/octet-stream")},
    )
    attachment_id = uploaded.json()["attachment"]["id"]
    as_user(OWNER_B)
    pet_b = client.post("/pets", json={"name": "Luna", "species": "Gatto"}).json()["pet_profile"]

    def send(attachment: str) -> Any:
        return client.post(
            "/chat",
            json={"pet_id": pet_b["id"], "user_message": "Guarda", "attachment_id": attachment},
        )

    # A's attachment on B's own pet, and an attachment that was never there.
    _same(send(attachment_id), send("does-not-exist"))
    # The same attachment on A's OTHER pet (right owner, wrong pet) is also just "not found".
    as_user(OWNER_A)
    other_pet = client.post("/pets", json={"name": "Rio", "species": "Cane"}).json()["pet_profile"]
    wrong_pet = client.post(
        "/chat",
        json={"pet_id": other_pet["id"], "user_message": "Guarda", "attachment_id": attachment_id},
    )
    invented = client.post(
        "/chat",
        json={
            "pet_id": other_pet["id"],
            "user_message": "Guarda",
            "attachment_id": "does-not-exist",
        },
    )
    _same(wrong_pet, invented)


def test_uploading_to_someone_elses_pet_answers_like_an_invented_pet(
    client: TestClient, as_user: Callable[[str], None]
) -> None:
    pet_a = client.post("/pets", json={"name": "Milo", "species": "Cane"}).json()["pet_profile"]
    as_user(OWNER_B)

    def upload(pet_id: str) -> Any:
        return client.post(
            "/chat-attachments",
            data={"pet_id": pet_id},
            files={"file": ("zampa.png", io.BytesIO(PNG), "application/octet-stream")},
        )

    _same(upload(pet_a["id"]), upload("does-not-exist"))


def test_the_owner_still_gets_a_real_answer_on_their_own_ids(
    client: TestClient, as_user: Callable[[str], None]
) -> None:
    pet = client.post("/pets", json={"name": "Milo", "species": "Cane"}).json()["pet_profile"]
    chat = client.post("/chat", json={"pet_id": pet["id"], "user_message": "Mangia poco"}).json()
    uploaded = client.post(
        "/chat-attachments",
        data={"pet_id": pet["id"]},
        files={"file": ("zampa.png", io.BytesIO(PNG), "application/octet-stream")},
    )

    reported = client.post(
        "/chat-response-reports",
        json={
            "conversation_id": chat["conversation"]["id"],
            "message_id": chat["reply"]["id"],
            "reason": "other",
        },
    )

    assert uploaded.status_code == 200
    assert reported.status_code == 200, reported.text
