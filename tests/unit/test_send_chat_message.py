import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ValidationError


def test_send_chat_message_persists_conversation() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
    )

    result = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Il mio cane tossisce")
    )

    assert len(result.conversation.messages) == 2
    assert result.reply.content  # Echo's demo evidence synthesis, rendered to text
    assert result.mode == "evidence"
    assert result.ai_generated is True
    assert result.sources


def test_send_chat_message_asks_a_safety_clarification_for_red_flags() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
    )

    result = service.execute(
        SendChatMessageInput(
            owner_id="user-1", pet_id="pet-1", user_message="Il cane non respira bene"
        )
    )

    assert result.mode == "safety_clarification"
    assert result.provider == "rule-based"
    assert result.safety_flags
    assert result.awaiting_safety_clarification is True
    assert result.safety_clarification_category == "respiratory"
    assert result.conversation.awaiting_safety_clarification is True


def test_send_chat_message_resolves_safety_clarification_on_next_turn() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
    )

    first = service.execute(
        SendChatMessageInput(
            owner_id="user-1", pet_id="pet-1", user_message="Il cane non respira bene"
        )
    )

    second = service.execute(
        SendChatMessageInput(
            owner_id="user-1",
            pet_id="pet-1",
            conversation_id=first.conversation.id,
            user_message="Ha appena corso ed è un caldo torrido, ora si sta calmando",
        )
    )

    assert second.mode == "safety_clarification_resolved"
    assert second.awaiting_safety_clarification is False
    assert second.conversation.awaiting_safety_clarification is False


def test_send_chat_message_forwards_breed_and_age_to_the_orchestrator() -> None:
    # Real-world finding: PetProfile already carries breed/age_years/notes,
    # but SendChatMessageService never passed them into
    # ChatOrchestratorInput — EchoLLMClient's demo reply echoes the prompt
    # verbatim for the general-answer path, so it doubles as a cheap probe
    # for what actually reached the LLM.
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(
        PetProfile(
            id="pet-1",
            owner_id="user-1",
            name="Milo",
            species="dog",
            breed="Labrador",
            age_years=9,
        )
    )
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(InMemoryConversationRepository(), orchestrator, pet_repository)

    result = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="ciao")
    )

    assert "Breed: Labrador" in result.reply.content
    assert "Age: 9 years" in result.reply.content


def test_send_chat_message_rejects_empty_input() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
    )

    with pytest.raises(ValidationError):
        service.execute(SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="  "))


def test_send_chat_message_enforces_the_per_pet_conversation_limit() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
        max_active_conversations_per_pet=2,
    )

    service.execute(SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Ciao"))
    service.execute(SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Ciao"))

    with pytest.raises(ValidationError):
        service.execute(
            SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Ciao")
        )


def test_send_chat_message_persists_medical_record_consent_at_pet_level_and_reuses_it() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    clinical_events = InMemoryClinicalEventRepository(
        seed=[ClinicalEvent(pet_id="pet-1", title="Richiamo vaccinale", subtitle="al completo")]
    )
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        medical_record_context_retriever=MedicalRecordContextRetriever(clinical_events),
        enable_interview_loop=True,
    )
    service = SendChatMessageService(InMemoryConversationRepository(), orchestrator, pet_repository)

    first = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Il mio cane tossisce")
    )
    assert first.mode == "consent_request"

    granted = service.execute(
        SendChatMessageInput(
            owner_id="user-1",
            pet_id="pet-1",
            conversation_id=first.conversation.id,
            user_message="Sì, consultala pure",
        )
    )
    assert granted.medical_record_consent is True

    stored_pet = pet_repository.get("pet-1")
    assert stored_pet is not None
    assert stored_pet.medical_record_consent is not None
    assert stored_pet.medical_record_consent.granted is True

    # A brand new conversation for the same pet must not ask again.
    second_conversation = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="Ora ha anche vomito")
    )
    assert second_conversation.mode != "consent_request"
