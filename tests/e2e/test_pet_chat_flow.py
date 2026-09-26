from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
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


def test_pet_creation_then_chat_flow() -> None:
    pet_repo = InMemoryPetProfileRepository()
    conversation_repo = InMemoryConversationRepository()

    pet = CreatePetProfileService(pet_repo).execute(
        CreatePetProfileInput(owner_id="user-1", name="Luna", species="cat")
    ).pet_profile

    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    chat = SendChatMessageService(conversation_repo, orchestrator, pet_repo).execute(
        SendChatMessageInput(owner_id="user-1", pet_id=pet.id, user_message="Mangia poco oggi")
    )

    assert chat.conversation.pet_id == pet.id
    assert chat.reply.role == "assistant"
    assert chat.mode == "natural"
