import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError


class FailingLLMClient:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        raise ProviderError("llm unavailable")


def test_send_chat_message_raises_provider_error() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet = CreatePetProfileService(pet_repository).execute(
        CreatePetProfileInput(owner_id="user-1", name="Milo", species="dog")
    ).pet_profile

    orchestrator = ChatOrchestrator(
        FailingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(InMemoryConversationRepository(), orchestrator, pet_repository)

    with pytest.raises(ProviderError):
        service.execute(
            SendChatMessageInput(owner_id="user-1", pet_id=pet.id, user_message="Serve aiuto")
        )
