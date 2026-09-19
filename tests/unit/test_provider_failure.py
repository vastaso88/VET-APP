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
from packages.core.domain.conversation.states import ConversationState
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


def test_send_chat_message_degrades_gracefully_on_provider_failure() -> None:
    # Real-world finding (live testing against Groq, which rate-limits):
    # a raised ProviderError used to crash the whole turn uncaught. Every
    # LLM call site in ChatOrchestrator now catches it and degrades to a
    # friendly retry message instead — a provider outage should never
    # surface as a 500 to the owner, same fail-safe posture the retrieval
    # adapters already have for network failures.
    pet_repository = InMemoryPetProfileRepository()
    pet = CreatePetProfileService(pet_repository).execute(
        CreatePetProfileInput(owner_id="user-1", name="Milo", species="dog")
    ).pet_profile

    orchestrator = ChatOrchestrator(
        FailingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    service = SendChatMessageService(InMemoryConversationRepository(), orchestrator, pet_repository)

    result = service.execute(
        SendChatMessageInput(owner_id="user-1", pet_id=pet.id, user_message="Serve aiuto")
    )

    assert result.state == ConversationState.RETRIEVAL_FAILURE
    assert result.reply.content
