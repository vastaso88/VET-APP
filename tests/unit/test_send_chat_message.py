import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
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
    assert result.reply.content.startswith("Demo reply for:")
    assert result.mode == "evidence"
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
