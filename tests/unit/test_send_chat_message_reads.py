"""QK-03: one read of the pet's conversations per new message, and one answer per message.

SendChatMessageService used to read the conversations twice per new message: once to look
for a retry of the same client_message_id (already_answered) and once to load or create the
conversation. They are now read once and shared. A retry of an answer already stored gives
the same reply id with zero model calls; a duplicate that arrives while the first copy is
still being answered waits for it and then gets that stored answer (before: two model calls,
and for a new chat two conversations). Fake provider only, no network.
"""

import threading
from collections.abc import Callable

import pytest

from packages.core.application.services import send_chat_message
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
from packages.shared.errors.base import ValidationError

BLOCK = "BLOCCA"  # a message containing this stays in the (fake) model until released


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
    """A fake provider: counts the calls, never talks to any model. A message with BLOCK in
    it waits for `release` so a test can hold one request in flight."""

    def __init__(self) -> None:
        self.calls = 0
        self.fail_first = False
        self.entered = threading.Event()
        self.release = threading.Event()
        self._lock = threading.Lock()

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        with self._lock:
            self.calls += 1
            number = self.calls
        if BLOCK in data.user_message:
            self.entered.set()
            assert self.release.wait(timeout=10), "the test forgot to release the model"
        if self.fail_first and number == 1:
            raise RuntimeError("the model is down")
        return ChatOrchestratorResult(
            answer=f"Risposta numero {number}",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
        )


def _service() -> tuple[SendChatMessageService, _CountingOrchestrator, _CountingConversations]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Birba", species="Cane"))
    pets.save(PetProfile(id="pet-2", owner_id="owner-2", name="Luna", species="Gatto"))
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


# --- one read ------------------------------------------------------------------------------


def test_a_new_chat_with_a_client_id_reads_the_pets_conversations_once() -> None:
    service, _, conversations = _service()

    _send(service)

    assert conversations.list_by_pet_calls == 1


def test_a_new_message_in_an_existing_chat_reads_the_conversation_once() -> None:
    service, _, conversations = _service()
    first = _send(service, client_message_id="user-1")
    conversations.reset_counts()

    _send(service, conversation_id=first.conversation.id, client_message_id="user-2")

    assert conversations.gets == 1


def test_without_a_client_id_there_is_still_one_read() -> None:
    service, _, conversations = _service()

    _send(service, client_message_id=None)

    assert conversations.list_by_pet_calls == 1


# --- a retry of a stored answer ------------------------------------------------------------


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


def test_user_b_cannot_replay_or_open_user_as_chat_by_its_ids() -> None:
    service, orchestrator, _ = _service()
    first = _send(service)

    with pytest.raises(ValidationError, match="conversation not found"):
        _send(
            service,
            owner_id="owner-2",
            pet_id="pet-2",
            conversation_id=first.conversation.id,
            client_message_id="user-abc",
        )

    assert orchestrator.calls == 1  # nothing reached the model, nothing was replayed


# --- the same message twice at once --------------------------------------------------------


def _in_thread(fn: Callable[[], SendChatMessageOutput]) -> tuple[threading.Thread, list[object]]:
    box: list[object] = []

    def run() -> None:
        try:
            box.append(fn())
        except Exception as exc:  # noqa: BLE001 - the test inspects it
            box.append(exc)

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    return thread, box


def test_a_duplicate_of_a_new_chat_in_flight_waits_and_gets_the_stored_answer() -> None:
    """Before QK-03 this made two model calls and two conversations."""
    service, orchestrator, conversations = _service()
    first_thread, first = _in_thread(lambda: _send(service, user_message=f"{BLOCK} scarpe"))
    assert orchestrator.entered.wait(timeout=5)  # the first copy is inside the model

    second_thread, second = _in_thread(lambda: _send(service, user_message=f"{BLOCK} scarpe"))
    second_thread.join(timeout=0.3)
    assert second_thread.is_alive()  # it waits, it does not call the model
    assert orchestrator.calls == 1

    orchestrator.release.set()
    first_thread.join(timeout=5)
    second_thread.join(timeout=5)

    a, b = first[0], second[0]
    assert isinstance(a, SendChatMessageOutput) and isinstance(b, SendChatMessageOutput)
    assert orchestrator.calls == 1
    assert b.mode == "replayed"
    assert b.reply.id == a.reply.id
    assert b.conversation.id == a.conversation.id
    assert len(conversations.list_by_pet("pet-1")) == 1


def test_a_duplicate_in_an_existing_chat_in_flight_gets_the_same_answer() -> None:
    service, orchestrator, conversations = _service()
    chat = _send(service, client_message_id="user-0").conversation
    orchestrator.entered.clear()
    first_thread, first = _in_thread(
        lambda: _send(
            service,
            conversation_id=chat.id,
            client_message_id="user-1",
            user_message=f"{BLOCK} ancora",
        )
    )
    assert orchestrator.entered.wait(timeout=5)
    second_thread, second = _in_thread(
        lambda: _send(
            service,
            conversation_id=chat.id,
            client_message_id="user-1",
            user_message=f"{BLOCK} ancora",
        )
    )
    second_thread.join(timeout=0.3)
    assert second_thread.is_alive()

    orchestrator.release.set()
    first_thread.join(timeout=5)
    second_thread.join(timeout=5)

    a, b = first[0], second[0]
    assert isinstance(a, SendChatMessageOutput) and isinstance(b, SendChatMessageOutput)
    assert orchestrator.calls == 2  # the first message of the chat plus this one, once
    assert b.reply.id == a.reply.id
    stored = conversations.get(chat.id)
    assert stored is not None and [m.role for m in stored.messages] == [
        "user",
        "assistant",
        "user",
        "assistant",
    ]


def test_if_the_first_copy_fails_the_duplicate_answers_itself_and_nothing_stays_locked() -> None:
    service, orchestrator, conversations = _service()
    orchestrator.fail_first = True
    first_thread, first = _in_thread(lambda: _send(service, user_message=f"{BLOCK} scarpe"))
    assert orchestrator.entered.wait(timeout=5)
    second_thread, second = _in_thread(lambda: _send(service, user_message="scarpe"))
    second_thread.join(timeout=0.3)
    assert second_thread.is_alive()

    orchestrator.release.set()
    first_thread.join(timeout=5)
    second_thread.join(timeout=5)

    assert isinstance(first[0], Exception)  # the first one failed, nothing was stored
    assert isinstance(second[0], SendChatMessageOutput)
    assert second[0].mode != "replayed"  # a real answer, not a replay of nothing
    assert orchestrator.calls == 2
    assert len(conversations.list_by_pet("pet-1")) == 1
    assert send_chat_message._IN_FLIGHT._entries == {}


def test_different_messages_and_different_owners_never_wait_for_each_other() -> None:
    service, orchestrator, _ = _service()
    held_thread, _ = _in_thread(lambda: _send(service, user_message=f"{BLOCK} scarpe"))
    assert orchestrator.entered.wait(timeout=5)

    other_message = _send(service, client_message_id="user-other", user_message="altro")
    other_owner = _send(
        service, owner_id="owner-2", pet_id="pet-2", user_message="ciao"
    )  # the same client id, another owner

    assert other_message.mode != "replayed" and other_owner.mode != "replayed"
    orchestrator.release.set()
    held_thread.join(timeout=5)
    assert send_chat_message._IN_FLIGHT._entries == {}


def test_a_duplicate_that_waits_too_long_goes_on_and_answers_as_before(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The documented fallback: never hang the app on a first copy that is too slow."""
    monkeypatch.setattr(send_chat_message, "DUPLICATE_WAIT_SECONDS", 0.2)
    service, orchestrator, _ = _service()
    first_thread, _ = _in_thread(lambda: _send(service, user_message=f"{BLOCK} scarpe"))
    assert orchestrator.entered.wait(timeout=5)

    late = _send(service, user_message="scarpe")  # waits 0.2 s, then answers by itself

    assert late.mode != "replayed"
    assert orchestrator.calls == 2
    orchestrator.release.set()
    first_thread.join(timeout=5)
