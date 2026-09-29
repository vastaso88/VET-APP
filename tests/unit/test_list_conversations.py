from packages.core.application.services.list_conversations import (
    ListConversationsInput,
    ListConversationsService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
)


def test_lists_only_the_owners_conversations_with_their_messages() -> None:
    repository = InMemoryConversationRepository()
    repository.save(
        Conversation(
            id="conv-1",
            owner_id="user-1",
            pet_id="pet-1",
            title="Chat",
            messages=[
                ChatMessage(role="user", content="Ciao"),
                ChatMessage(role="assistant", content="Come posso aiutarti?"),
            ],
        )
    )
    repository.save(Conversation(id="conv-2", owner_id="user-2", pet_id="pet-2", title="Altro"))
    service = ListConversationsService(repository)

    result = service.execute(ListConversationsInput(owner_id="user-1"))

    assert [c.id for c in result.conversations] == ["conv-1"]
    assert [m.content for m in result.conversations[0].messages] == [
        "Ciao",
        "Come posso aiutarti?",
    ]
    assert [m.role for m in result.conversations[0].messages] == ["user", "assistant"]


def test_lists_nothing_for_an_owner_without_conversations() -> None:
    service = ListConversationsService(InMemoryConversationRepository())

    assert service.execute(ListConversationsInput(owner_id="user-1")).conversations == []
