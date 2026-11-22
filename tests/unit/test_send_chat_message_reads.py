"""QK-03 (proposed tests, ready for the day send_chat_message.py may change).

SendChatMessageService used to read the pet's conversations twice per new message:
once to look for a retry of the same client_message_id (already_answered) and once
to load or create the conversation. The two tests marked xfail(strict) describe the
wanted count (1 read) and will flip to "unexpected pass" - i.e. fail loudly - as soon as
the change lands, which is the signal to drop the marker. The others pin behaviour
that must NOT change: a stored retry gives the same id with zero model calls, and
concurrent duplicates keep the documented behaviour.
"""

import pytest

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)


class _CountingConversations(InMemoryConversationRepository):
    def __init__(self) -> None:
        super().__init__()
        self.gets = 0
        self.list_by_pet_calls = 0

    def get(self, conversation_id: str) -> Conversation | None:
        self.gets += 1
        return super().get(conversation_id)

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        self.list_by_pet_calls += 1
        return super().list_by_pet(pet_id)

    def reset_counts(self) -> None:
        self.gets = 0
        self.list_by_pet_calls = 0


class _CountingOrchestrator:
    """A fake provider: counts the calls, never talks to any model."""

    def __init__(self) -> None:
        self.calls = 0
        self.on_first_call: object = None

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        self.calls += 1
        hook = self.on_first_call
        if self.calls == 1 and callable(hook):
            hook()
        return ChatOrchestratorResult(
            answer=f"Risposta numero {self.calls}",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
        )


def _service() -> tuple[SendChatMessageService, _CountingOrchestrator, _CountingConversations]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Birba", species="Cane"))
    conversations = _CountingConversations()
    orchestrator = _CountingOrchestrator()
    service = SendChatMessageService(conversations, orchestrator, pets)  # type: ignore[arg-type]
    return service, orchestrator, conversations


def _input(**overrides: str | None) -> SendChatMessageInput:
    values: dict[str, str | None] = {
        "owner_id": "owner-1",
        "pet_id": "pet-1",
        "user_message": "perché mastica le scarpe?",
        "client_message_id": "user-abc",
    }
    values.update(overrides)
    return SendChatMessageInput.model_validate(values)


def _send(service: SendChatMessageService, **overrides: str | None) -> SendChatMessageOutput:
    return service.execute(_input(**overrides))


@pytest.mark.xfail(strict=True, reason="QK-03 not applied yet: 2 list_by_pet today")
def test_a_new_chat_with_a_client_id_reads_the_pets_conversations_once() -> None:
    service, _, conversations = _service()

    _send(service)

    assert conversations.list_by_pet_calls == 1


@pytest.mark.xfail(strict=True, reason="QK-03 not applied yet: 2 get today")
def test_a_new_message_in_an_existing_chat_reads_the_conversation_once() -> None:
    service, _, conversations = _service()
    first = _send(service, client_message_id="user-1")
    conversations.reset_counts()

    _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert conversations.gets == 1


def test_a_stored_retry_costs_one_read_zero_model_calls_and_keeps_the_ids() -> None:
    service, orchestrator, conversations = _service()
    first = _send(service)
    assert orchestrator.calls == 1
    conversations.reset_counts()

    retry = _send(service)  # new chat: the app never saw the first response

    assert orchestrator.calls == 1  # no regeneration, whatever the read strategy
    assert conversations.list_by_pet_calls == 1
    assert retry.mode == "replayed"
    assert retry.reply.id == first.reply.id
    assert retry.conversation.id == first.conversation.id
    assert len(conversations.list_by_pet("pet-1")) == 1


def test_a_stored_retry_in_an_existing_chat_costs_one_read_and_zero_model_calls() -> None:
    service, orchestrator, conversations = _service()
    first = _send(service, client_message_id="user-1")
    second = _send(service, conversation_id=first.conversation.id, client_message_id="user-2")
    conversations.reset_counts()

    retry = _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert orchestrator.calls == 2
    assert conversations.gets == 1
    assert retry.reply.id == second.reply.id


def test_a_retry_never_regenerates_even_when_it_arrives_in_a_chat_that_has_moved_on() -> None:
    service, orchestrator, _ = _service()
    first = _send(service, client_message_id="user-1")
    _send(service, conversation_id=first.conversation.id, client_message_id="user-2")
    _send(service, conversation_id=first.conversation.id, client_message_id="user-3")

    retry = _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert orchestrator.calls == 3
    assert retry.mode == "replayed"


def test_another_owners_chat_is_never_replayed_nor_loaded() -> None:
    service, orchestrator, conversations = _service()
    first = _send(service)
    stolen = conversations.get(first.conversation.id)
    assert stolen is not None
    stolen.owner_id = "owner-b"
    conversations.save(stolen)

    fresh = _send(service)  # same client id from owner-1: owner-b's chat does not count

    assert orchestrator.calls == 2
    assert fresh.mode != "replayed"
    assert fresh.conversation.id != first.conversation.id


def test_concurrent_duplicates_of_a_new_chat_are_not_deduplicated_documented() -> None:
    """Documented, not wished for: the answer is saved only when generated, so a duplicate
    that arrives while the first is still being answered finds nothing stored and is
    answered too (two chats). Only an answer already saved is replayed. A real guard would
    need a durable unique key; one process-local lock would not hold on several instances.
    QK-03 must leave this exactly as it is."""
    service, orchestrator, conversations = _service()
    inner: list[SendChatMessageOutput] = []
    orchestrator.on_first_call = lambda: inner.append(_send(service))

    _send(service)

    assert orchestrator.calls == 2
    assert inner[0].mode != "replayed"
    assert len(conversations.list_by_pet("pet-1")) == 2
