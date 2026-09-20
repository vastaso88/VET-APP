import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
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


def test_send_chat_message_forwards_habitat_and_aquarium_stock_to_the_orchestrator() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(
        PetProfile(
            id="pet-1",
            owner_id="user-1",
            name="Acquario del salotto",
            species="Pesce",
            habitat=HabitatDetails(dimensions="60x30x36 cm", volume_liters=54),
            aquarium_stock=[FishStock(species="Guppy", male_count=2, female_count=4)],
        )
    )
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(InMemoryConversationRepository(), orchestrator, pet_repository)

    result = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id="pet-1", user_message="ciao")
    )

    assert "54 liters" in result.reply.content
    assert "Guppy (2M/4F)" in result.reply.content


def test_send_chat_message_folds_the_attachments_analysis_into_the_prompt() -> None:
    # The photo's visual analysis is a genuine red flag (emorragia) that
    # the owner's own typed words don't mention at all — reaching
    # safety_clarification here is only possible if send_chat_message
    # actually resolved the attachment and forwarded its analysis into
    # the orchestrator (chat_orchestrator's own tests cover exactly how
    # that text is used once it arrives; this test is about the wiring
    # up to that point).
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    attachment_repository = InMemoryChatAttachmentRepository()
    attachment_repository.save(
        ChatAttachment(
            id="att-1",
            owner_id="user-1",
            pet_id="pet-1",
            storage_key="att-1",
            content_type="image/jpeg",
            original_filename="zampa.jpg",
            analysis="Si osserva una vistosa emorragia sulla zampa anteriore.",
        )
    )
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
        attachment_repository=attachment_repository,
    )

    result = service.execute(
        SendChatMessageInput(
            owner_id="user-1", pet_id="pet-1", user_message="ciao", attachment_id="att-1"
        )
    )

    assert result.mode in ("safety_clarification", "triage")
    assert result.safety_flags
    # The owner's own message stays clean in the stored transcript — the
    # photo analysis is folded in for the LLM only, not persisted as if
    # the owner had typed it.
    assert result.conversation.messages[0].content == "ciao"
    assert result.conversation.messages[0].attachment_id == "att-1"

    linked = attachment_repository.get("att-1")
    assert linked is not None
    assert linked.conversation_id == result.conversation.id


def test_send_chat_message_rejects_an_attachment_belonging_to_a_different_pet() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    attachment_repository = InMemoryChatAttachmentRepository()
    attachment_repository.save(
        ChatAttachment(
            id="att-1",
            owner_id="user-1",
            pet_id="a-different-pet",
            storage_key="att-1",
            content_type="image/jpeg",
            original_filename="zampa.jpg",
        )
    )
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        orchestrator,
        pet_repository,
        attachment_repository=attachment_repository,
    )

    with pytest.raises(ValidationError):
        service.execute(
            SendChatMessageInput(
                owner_id="user-1", pet_id="pet-1", user_message="ciao", attachment_id="att-1"
            )
        )


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
