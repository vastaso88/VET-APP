"""Security regression tests (audit 2026-10-26): the backend talks to
Supabase with the service role, so row-level security never applies to
its queries and every service must reject ids that belong to someone
else, answering exactly as it would for a missing id."""

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_reminder import (
    CreateReminderInput,
    CreateReminderService,
)
from packages.core.application.services.get_pet_profile import (
    GetPetProfileInput,
    GetPetProfileService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ValidationError

OWNER = "owner-a"
STRANGER = "owner-b"


class _FakeLLM:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        return LLMResponse(content="Risposta.", provider="fake", model="fake", token_count=1)


def _pets() -> InMemoryPetProfileRepository:
    repository = InMemoryPetProfileRepository()
    repository.save(PetProfile(id="pet-a", owner_id=OWNER, name="Milo", species="Cane"))
    return repository


def test_get_pet_profile_rejects_another_owner_like_a_missing_pet() -> None:
    service = GetPetProfileService(_pets())

    assert service.execute(GetPetProfileInput(pet_id="pet-a", owner_id=OWNER)).pet_profile.name

    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(GetPetProfileInput(pet_id="pet-a", owner_id=STRANGER))
    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(GetPetProfileInput(pet_id="missing", owner_id=STRANGER))


def test_update_pet_profile_rejects_another_owner() -> None:
    pets = _pets()
    service = UpdatePetProfileService(pets)

    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(
            UpdatePetProfileInput(pet_id="pet-a", owner_id=STRANGER, name="Hacked", species="Cane")
        )
    assert pets.get("pet-a") is not None
    assert pets.get("pet-a").name == "Milo"  # type: ignore[union-attr]

    updated = service.execute(
        UpdatePetProfileInput(pet_id="pet-a", owner_id=OWNER, name="Milo II", species="Cane")
    )
    assert updated.pet_profile.name == "Milo II"
    assert updated.pet_profile.owner_id == OWNER


def test_create_reminder_rejects_another_owners_pet() -> None:
    service = CreateReminderService(InMemoryReminderRepository(), _pets())
    from datetime import date

    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(
            CreateReminderInput(
                owner_id=STRANGER, pet_id="pet-a", title="Vaccino", due_date=date(2026, 11, 1)
            )
        )


def _chat_service(conversations: InMemoryConversationRepository) -> SendChatMessageService:
    orchestrator = ChatOrchestrator(_FakeLLM(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    return SendChatMessageService(conversations, orchestrator, _pets())


def test_chat_rejects_another_owners_pet() -> None:
    service = _chat_service(InMemoryConversationRepository())

    with pytest.raises(ValidationError, match="pet_profile not found"):
        service.execute(
            SendChatMessageInput(owner_id=STRANGER, pet_id="pet-a", user_message="Come sta?")
        )


def test_chat_rejects_another_owners_conversation_without_revealing_it() -> None:
    conversations = InMemoryConversationRepository()
    secret = Conversation(
        owner_id=OWNER,
        pet_id="pet-a",
        title="Visita",
        messages=[ChatMessage(role="user", content="Milo ha una ferita alla zampa")],
    )
    conversations.save(secret)
    # The stranger also owns a pet with the same id? No: ids are global, so
    # the stranger needs their own pet to even reach the conversation check.
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id=OWNER, name="Milo", species="Cane"))
    pets.save(PetProfile(id="pet-b", owner_id=STRANGER, name="Rex", species="Cane"))
    orchestrator = ChatOrchestrator(_FakeLLM(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    service = SendChatMessageService(conversations, orchestrator, pets)

    with pytest.raises(ValidationError, match="conversation not found"):
        service.execute(
            SendChatMessageInput(
                owner_id=STRANGER,
                pet_id="pet-b",
                conversation_id=secret.id,
                user_message="Dimmi tutto",
            )
        )
    stored = conversations.get(secret.id)
    assert stored is not None
    assert len(stored.messages) == 1, "a stranger's message must never land in the conversation"


def test_chat_conversation_must_belong_to_the_same_pet() -> None:
    conversations = InMemoryConversationRepository()
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id=OWNER, name="Milo", species="Cane"))
    pets.save(PetProfile(id="pet-c", owner_id=OWNER, name="Luna", species="Gatto"))
    conversation = Conversation(owner_id=OWNER, pet_id="pet-a", title="Milo")
    conversations.save(conversation)
    orchestrator = ChatOrchestrator(_FakeLLM(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    service = SendChatMessageService(conversations, orchestrator, pets)

    with pytest.raises(ValidationError, match="conversation not found"):
        service.execute(
            SendChatMessageInput(
                owner_id=OWNER, pet_id="pet-c", conversation_id=conversation.id, user_message="?"
            )
        )
