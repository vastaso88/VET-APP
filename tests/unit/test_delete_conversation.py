import pytest

from packages.core.application.services.delete_conversation import (
    DeleteConversationInput,
    DeleteConversationService,
)
from packages.core.domain.conversation.models import Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
)
from packages.shared.errors.base import ValidationError


def test_deletes_a_conversation_owned_by_the_requester() -> None:
    repository = InMemoryConversationRepository()
    conversation = repository.save(
        Conversation(id="conv-1", owner_id="user-1", pet_id="pet-1", title="Chat")
    )
    service = DeleteConversationService(repository)

    service.execute(DeleteConversationInput(owner_id="user-1", conversation_id=conversation.id))

    assert repository.get(conversation.id) is None


def test_rejects_deleting_a_conversation_owned_by_someone_else() -> None:
    repository = InMemoryConversationRepository()
    conversation = repository.save(
        Conversation(id="conv-1", owner_id="user-1", pet_id="pet-1", title="Chat")
    )
    service = DeleteConversationService(repository)

    with pytest.raises(ValidationError):
        service.execute(
            DeleteConversationInput(owner_id="user-2", conversation_id=conversation.id)
        )
    assert repository.get(conversation.id) is not None


def test_rejects_deleting_an_unknown_conversation() -> None:
    service = DeleteConversationService(InMemoryConversationRepository())

    with pytest.raises(ValidationError):
        service.execute(DeleteConversationInput(owner_id="user-1", conversation_id="missing"))
