"""A retried message is answered once (2026-10-07: the app gave up after
25 s, the server stored the answer anyway, and "Riprova" sent the message
again — a second model call, a duplicate turn, and for a new chat a second
conversation counting against the per-pet limit)."""

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)


class CountingOrchestrator:
    def __init__(self) -> None:
        self.calls = 0

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        self.calls += 1
        return ChatOrchestratorResult(
            answer=f"Risposta numero {self.calls}",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
        )


def _service() -> tuple[
    SendChatMessageService, CountingOrchestrator, InMemoryConversationRepository
]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Birba", species="Cane"))
    conversations = InMemoryConversationRepository()
    orchestrator = CountingOrchestrator()
    service = SendChatMessageService(conversations, orchestrator, pets)  # type: ignore[arg-type]
    return service, orchestrator, conversations


def _send(service: SendChatMessageService, **overrides: str | None):  # type: ignore[no-untyped-def]
    values: dict[str, str | None] = {
        "owner_id": "owner-1",
        "pet_id": "pet-1",
        "user_message": "perché mastica le scarpe?",
        "client_message_id": "user-abc",
    }
    values.update(overrides)
    return service.execute(SendChatMessageInput.model_validate(values))


def test_a_retry_of_a_new_chat_gets_the_stored_answer_and_no_second_conversation() -> None:
    service, orchestrator, conversations = _service()

    first = _send(service)
    retry = _send(service)  # no conversation_id: the app never got the first response

    assert orchestrator.calls == 1
    assert retry.reply.content == "Risposta numero 1"
    assert retry.reply.id == first.reply.id
    assert retry.conversation.id == first.conversation.id
    assert retry.ai_generated is True
    assert retry.mode == "replayed"
    assert len(conversations.list_by_pet("pet-1")) == 1
    assert [m.role for m in conversations.get(first.conversation.id).messages] == [  # type: ignore[union-attr]
        "user",
        "assistant",
    ]


def test_a_retry_inside_an_existing_chat_does_not_add_a_duplicate_turn() -> None:
    service, orchestrator, conversations = _service()
    first = _send(service, client_message_id="user-1")
    second = _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    retry = _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert orchestrator.calls == 2
    assert retry.reply.content == second.reply.content
    assert len(conversations.get(first.conversation.id).messages) == 4  # type: ignore[union-attr]


def test_a_new_message_with_a_new_id_is_answered_normally() -> None:
    service, orchestrator, _ = _service()
    first = _send(service, client_message_id="user-1")

    _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert orchestrator.calls == 2


def test_without_a_client_id_every_send_is_answered_as_before() -> None:
    service, orchestrator, conversations = _service()

    _send(service, client_message_id=None)
    _send(service, client_message_id=None)

    assert orchestrator.calls == 2
    assert len(conversations.list_by_pet("pet-1")) == 2


def test_another_owners_message_id_is_never_replayed() -> None:
    service, orchestrator, conversations = _service()
    first = _send(service)
    stolen = conversations.get(first.conversation.id)
    assert stolen is not None
    stolen.owner_id = "someone-else"
    conversations.save(stolen)

    _send(service)

    assert orchestrator.calls == 2


def test_the_stored_reply_remembers_it_was_written_by_the_model() -> None:
    service, _, conversations = _service()

    first = _send(service)

    stored = conversations.get(first.conversation.id)
    assert stored is not None
    assert stored.messages[0].client_message_id == "user-abc"
    assert stored.messages[1].ai_generated is True
