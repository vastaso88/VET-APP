"""Ricordi (docs/product/17_ricordi_animali.md): a pet that passed away can be
read, exported and deleted, never added to or changed, also when a route is
called directly. Another owner still gets "not found", never a hint that the
pet is in Ricordi (utente B)."""

import asyncio
import json
from datetime import date

import pytest

from apps.api.main import handle_pet_in_memories
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_reminder import (
    CreateReminderInput,
    CreateReminderService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentInput,
    SetMedicalRecordConsentService,
)
from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.application.services.upload_chat_attachment import (
    UploadChatAttachmentInput,
    UploadChatAttachmentService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import PetInMemoriesError, ValidationError

OWNER = "owner-a"
STRANGER = "owner-b"
JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"fake-jpeg-body"


class _FakeLLM:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        return LLMResponse(content="Risposta.", provider="fake", model="fake", token_count=1)


class _FakeStorage:
    def __init__(self) -> None:
        self.saved: dict[str, bytes] = {}

    def save(self, key: str, content: bytes) -> None:
        self.saved[key] = content

    def read(self, key: str) -> bytes | None:
        return self.saved.get(key)

    def delete(self, key: str) -> None:
        self.saved.pop(key, None)


class _FakeAnalyzer:
    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        return "analisi"


def _pets() -> InMemoryPetProfileRepository:
    repository = InMemoryPetProfileRepository()
    repository.save(
        PetProfile(id="pet-a", owner_id=OWNER, name="Milo", species="Cane", is_memorial=True)
    )
    repository.save(PetProfile(id="pet-b", owner_id=OWNER, name="Luna", species="Gatto"))
    return repository


def _chat(
    pets: InMemoryPetProfileRepository,
) -> tuple[SendChatMessageService, InMemoryConversationRepository]:
    conversations = InMemoryConversationRepository()
    orchestrator = ChatOrchestrator(_FakeLLM(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    return SendChatMessageService(conversations, orchestrator, pets), conversations


def test_the_flag_is_read_from_the_row_and_never_written_back() -> None:
    pet = PetProfile.model_validate(
        {"id": "p", "owner_id": OWNER, "name": "Milo", "species": "Cane", "is_memorial": True}
    )
    assert pet.is_memorial is True
    # The backend's save upserts model_dump(): without the column it can
    # never move a pet out of (or into) Ricordi.
    assert "is_memorial" not in pet.model_dump()
    assert "is_memorial" not in pet.model_dump(mode="json")


def test_profile_of_a_memory_cannot_be_changed() -> None:
    pets = _pets()
    service = UpdatePetProfileService(pets)

    with pytest.raises(PetInMemoriesError):
        service.execute(
            UpdatePetProfileInput(pet_id="pet-a", owner_id=OWNER, name="Altro", species="Cane")
        )
    stored = pets.get("pet-a")
    assert stored is not None and stored.name == "Milo" and stored.is_memorial

    # An active pet is untouched by the rule.
    service.execute(
        UpdatePetProfileInput(pet_id="pet-b", owner_id=OWNER, name="Luna II", species="Gatto")
    )


def test_utente_b_still_gets_not_found_for_a_memory() -> None:
    pets = _pets()
    with pytest.raises(ValidationError, match="pet_profile not found"):
        UpdatePetProfileService(pets).execute(
            UpdatePetProfileInput(pet_id="pet-a", owner_id=STRANGER, name="X", species="Cane")
        )
    with pytest.raises(ValidationError, match="pet_profile not found"):
        CreateReminderService(InMemoryReminderRepository(), pets).execute(
            CreateReminderInput(
                owner_id=STRANGER, pet_id="pet-a", title="Vaccino", due_date=date(2026, 12, 1)
            )
        )
    with pytest.raises(ValidationError, match="pet_profile not found"):
        _chat(pets)[0].execute(
            SendChatMessageInput(owner_id=STRANGER, pet_id="pet-a", user_message="Ciao")
        )
    with pytest.raises(ValidationError, match="pet_profile not found"):
        SetMedicalRecordConsentService(pets).execute(
            SetMedicalRecordConsentInput(owner_id=STRANGER, pet_id="pet-a", granted=False)
        )


def test_records_consent_can_be_revoked_but_not_granted() -> None:
    pets = _pets()
    service = SetMedicalRecordConsentService(pets)

    with pytest.raises(PetInMemoriesError):
        service.execute(SetMedicalRecordConsentInput(owner_id=OWNER, pet_id="pet-a", granted=True))

    revoked = service.execute(
        SetMedicalRecordConsentInput(owner_id=OWNER, pet_id="pet-a", granted=False)
    )
    consent = revoked.pet_profile.medical_record_consent
    assert consent is not None and consent.granted is False
    stored = pets.get("pet-a")
    assert stored is not None and stored.is_memorial, "revoking keeps the pet in Ricordi"


def test_no_new_reminder_for_a_memory() -> None:
    reminders = InMemoryReminderRepository()
    service = CreateReminderService(reminders, _pets())

    with pytest.raises(PetInMemoriesError):
        service.execute(
            CreateReminderInput(
                owner_id=OWNER, pet_id="pet-a", title="Vaccino", due_date=date(2026, 12, 1)
            )
        )
    assert reminders.list_by_owner(OWNER) == []


def test_no_new_chat_message_about_a_memory() -> None:
    service, conversations = _chat(_pets())

    with pytest.raises(PetInMemoriesError):
        service.execute(SendChatMessageInput(owner_id=OWNER, pet_id="pet-a", user_message="Ciao"))
    assert conversations.list_by_owner(OWNER) == [], "no conversation is created"


def test_a_past_chat_of_a_memory_stays_as_it_was() -> None:
    pets = _pets()
    service, conversations = _chat(pets)
    past = Conversation(
        owner_id=OWNER,
        pet_id="pet-a",
        title="Visita",
        messages=[ChatMessage(role="user", content="Come sta?")],
    )
    conversations.save(past)

    # Continuing it, or editing a message (EditChatMessageService answers
    # again through respond_in), is refused.
    with pytest.raises(PetInMemoriesError):
        service.execute(
            SendChatMessageInput(
                owner_id=OWNER, pet_id="pet-a", conversation_id=past.id, user_message="E ora?"
            )
        )
    with pytest.raises(PetInMemoriesError):
        service.respond_in(
            past,
            SendChatMessageInput(owner_id=OWNER, pet_id="pet-a", user_message="Modificato"),
        )
    stored = conversations.get(past.id)
    assert stored is not None and len(stored.messages) == 1


def test_no_chat_attachment_for_a_memory() -> None:
    storage = _FakeStorage()
    service = UploadChatAttachmentService(
        _pets(), InMemoryChatAttachmentRepository(), storage, _FakeAnalyzer()
    )

    with pytest.raises(PetInMemoriesError):
        service.execute(
            UploadChatAttachmentInput(
                owner_id=OWNER,
                pet_id="pet-a",
                filename="zampa.jpg",
                content_type="image/jpeg",
                file_bytes=JPEG_BYTES,
            )
        )
    assert storage.saved == {}, "nothing is stored"


def test_the_api_answers_409_pet_in_memories() -> None:
    response = asyncio.run(handle_pet_in_memories(None, PetInMemoriesError()))  # type: ignore[arg-type]

    assert response.status_code == 409
    assert json.loads(bytes(response.body)) == {
        "detail": "pet_in_memories",
        "code": "pet_in_memories",
    }
