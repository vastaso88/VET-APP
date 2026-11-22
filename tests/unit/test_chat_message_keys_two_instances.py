"""QK-03b: the same chat message received by two serverless instances answers once.

Each "instance" is its own SendChatMessageService with its OWN in-process lock (the lock that
used to be the only protection) and its own MessageClaims; the two share only what two real
instances share: the database (the conversations and the message keys). The interleaving is
driven by events and an injected sleep hook, never by real waiting. Fake provider only.
"""

from __future__ import annotations

import logging
import threading
from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.ports.message_key_repository import (
    MessageKey,
    MessageKeysUnavailable,
)
from packages.core.application.services import send_chat_message
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.message_claims import MessageClaims
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
    _InFlightMessages,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryMessageKeyRepository,
    InMemoryPetProfileRepository,
)

T0 = datetime(2026, 11, 22, 10, 0, tzinfo=UTC)
OWNER = "owner-aaaa-1111"
CLIENT_ID = "user-5f3a9c0d1e2b"
SECRET_TEXT = "SEGRETO il mio gatto Birba ha mangiato qualcosa"


class _Clock:
    """A clock the sleep hook moves forward, so a wait takes no time."""

    def __init__(self) -> None:
        self.now = T0

    def __call__(self) -> datetime:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += timedelta(seconds=seconds)


class _Model:
    """Counts the calls; a message with BLOCK waits for `release`; `fail` makes it raise."""

    def __init__(self) -> None:
        self.calls = 0
        self.fail = False
        self.entered = threading.Event()
        self.release = threading.Event()
        self._lock = threading.Lock()

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        with self._lock:
            self.calls += 1
            number = self.calls
        if "BLOCCA" in data.user_message:
            self.entered.set()
            assert self.release.wait(timeout=10)
        if self.fail:
            raise RuntimeError("the model is down")
        return ChatOrchestratorResult(
            answer=f"Risposta numero {number}",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
        )


class _Instance:
    def __init__(
        self,
        conversations: InMemoryConversationRepository,
        pets: InMemoryPetProfileRepository,
        keys: object,
        model: _Model,
        clock: _Clock,
        sleep: object,
    ) -> None:
        self.sleeps = 0
        self.model = model
        user_sleep = sleep

        def counted_sleep(seconds: float) -> None:
            self.sleeps += 1
            clock.advance(seconds)
            if callable(user_sleep):
                user_sleep(seconds)

        self.service = SendChatMessageService(
            conversations,
            model,  # type: ignore[arg-type]
            pets,
            message_claims=MessageClaims(keys, clock=clock, sleep=counted_sleep),  # type: ignore[arg-type]
            in_flight=_InFlightMessages(),  # its own: two processes never share this
        )

    def send(self, **overrides: str | None) -> SendChatMessageOutput:
        values: dict[str, str | None] = {
            "owner_id": OWNER,
            "pet_id": "pet-1",
            "user_message": "perché mastica le scarpe?",
            "client_message_id": CLIENT_ID,
        }
        values.update(overrides)
        return self.service.execute(SendChatMessageInput.model_validate(values))


def _world(
    sleep: object = None,
) -> tuple[_Instance, _Instance, InMemoryMessageKeyRepository, _Clock]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id=OWNER, name="Birba", species="Cane"))
    pets.save(PetProfile(id="pet-2", owner_id="owner-bbbb-2222", name="Luna", species="Gatto"))
    conversations = InMemoryConversationRepository()
    keys = InMemoryMessageKeyRepository()
    clock = _Clock()
    model = _Model()
    first = _Instance(conversations, pets, keys, model, clock, None)
    second = _Instance(conversations, pets, keys, model, clock, sleep)
    return first, second, keys, clock


# --- two instances at the same moment ------------------------------------------------------


def test_two_instances_with_the_same_message_call_the_model_once() -> None:
    """The first instance is inside the model; the second receives the same message, finds the
    reservation, waits (its sleep hook lets the first finish) and gets the stored answer."""
    first_done: list[SendChatMessageOutput] = []
    holder: dict[str, threading.Thread] = {}

    def let_the_first_finish(_: float) -> None:
        a.model.release.set()
        holder["first"].join(timeout=5)

    a, b, keys, _ = _world(sleep=let_the_first_finish)
    holder["first"] = threading.Thread(
        target=lambda: first_done.append(a.send(user_message="BLOCCA scarpe"))
    )
    holder["first"].start()
    assert a.model.entered.wait(timeout=5)  # the first copy is inside the model

    second = b.send(user_message="BLOCCA scarpe")  # same client id, another instance

    assert a.model.calls == 1
    assert second.mode == "replayed"
    assert second.reply.id == first_done[0].reply.id
    assert second.conversation.id == first_done[0].conversation.id
    assert b.sleeps >= 1  # it really waited for the reservation
    [key] = keys.keys_of(OWNER)
    assert key.answered_reply_id == first_done[0].reply.id


def test_without_the_reservation_the_same_race_answers_twice() -> None:
    """The control: the in-process lock alone (the situation before QK-03b) does not stop two
    instances, so the test above proves the reservation and not the lock."""
    holder: dict[str, threading.Thread] = {}
    outputs: list[SendChatMessageOutput] = []
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id=OWNER, name="Birba", species="Cane"))
    conversations = InMemoryConversationRepository()
    model = _Model()

    def instance() -> SendChatMessageService:
        return SendChatMessageService(
            conversations,
            model,  # type: ignore[arg-type]
            pets,
            in_flight=_InFlightMessages(),
        )

    first, second = instance(), instance()
    values = {
        "owner_id": OWNER,
        "pet_id": "pet-1",
        "user_message": "BLOCCA scarpe",
        "client_message_id": CLIENT_ID,
    }
    holder["t"] = threading.Thread(
        target=lambda: outputs.append(first.execute(SendChatMessageInput.model_validate(values)))
    )
    holder["t"].start()
    assert model.entered.wait(timeout=5)
    model.release.set()
    second.execute(SendChatMessageInput.model_validate(values))
    holder["t"].join(timeout=5)

    assert model.calls == 2


def test_a_retry_after_the_answer_is_stored_costs_no_model_call_and_no_wait() -> None:
    a, b, keys, _ = _world()
    first = a.send()

    retry = b.send()

    assert a.model.calls == 1
    assert retry.mode == "replayed" and retry.reply.id == first.reply.id
    assert b.sleeps == 0


# --- reservations that cannot be trusted ---------------------------------------------------


def test_an_orphan_reservation_is_taken_over_and_the_message_is_answered() -> None:
    """The instance that reserved it died: more than 60 s old, no answer, nothing stored."""
    a, b, keys, clock = _world()
    keys.claim(OWNER, CLIENT_ID, "conversation-of-the-dead", clock.now - timedelta(seconds=90))

    out = b.send()

    assert b.model.calls == 1 and out.mode != "replayed"
    assert b.sleeps == 0  # an orphan is not waited on
    [key] = keys.keys_of(OWNER)
    assert key.answered_reply_id == out.reply.id
    assert key.conversation_id == out.conversation.id and key.claimed_at == clock.now


def test_of_several_instances_only_one_takes_over_an_orphan() -> None:
    a, b, keys, clock = _world()
    old = clock.now - timedelta(seconds=120)
    keys.claim(OWNER, CLIENT_ID, "dead", old)
    seen = keys.claim(OWNER, CLIENT_ID, "x", clock.now)
    assert seen is not None

    assert keys.retake(seen, "mine", clock.now, require_unanswered=True) is True
    # the second taker holds the key as it was before the first took it
    assert keys.retake(seen, "other", clock.now, require_unanswered=True) is False
    assert keys.keys_of(OWNER)[0].conversation_id == "mine"


def test_a_key_that_says_answered_with_nothing_stored_is_taken_over_without_waiting() -> None:
    """The reply was cut by an edit or the chat was deleted: the table never decides a replay."""
    a, b, keys, clock = _world()
    keys.claim(OWNER, CLIENT_ID, "gone", clock.now - timedelta(seconds=5))
    keys.mark_answered(
        OWNER, CLIENT_ID, "reply-that-no-longer-exists", clock.now - timedelta(seconds=5)
    )

    out = b.send()

    assert b.model.calls == 1 and out.mode != "replayed"
    assert b.sleeps == 0


def test_a_failed_request_drops_its_reservation_so_the_retry_does_not_wait() -> None:
    a, b, keys, _ = _world()
    a.model.fail = True
    with pytest.raises(RuntimeError):
        a.send()
    assert keys.keys_of(OWNER) == []  # released

    a.model.fail = False
    retry = b.send()

    assert retry.mode != "replayed" and b.sleeps == 0
    assert a.model.calls == 2


def test_a_first_copy_that_never_finishes_is_not_waited_on_for_ever() -> None:
    """A recent reservation held by a request that stays silent: after the wait the duplicate
    answers by itself (as the in-process lock does), and does not touch the other's key."""
    a, b, keys, clock = _world()
    keys.claim(OWNER, CLIENT_ID, "still-running", clock.now)

    out = b.send()

    assert b.model.calls == 1 and out.mode != "replayed"
    assert b.sleeps >= 1
    [key] = keys.keys_of(OWNER)
    assert key.conversation_id == "still-running" and key.answered_reply_id is None


# --- the table is not available ------------------------------------------------------------


class _BrokenKeys:
    def __init__(self, error: Exception) -> None:
        self.error = error
        self.calls = 0

    def claim(self, *args: object, **kwargs: object) -> MessageKey | None:
        self.calls += 1
        raise self.error

    def retake(self, *args: object, **kwargs: object) -> bool:
        raise self.error

    def mark_answered(self, *args: object, **kwargs: object) -> None:
        raise self.error

    def release(self, *args: object, **kwargs: object) -> None:
        raise self.error

    def purge_before(self, *args: object, **kwargs: object) -> int:
        raise self.error


@pytest.mark.parametrize(
    "error", [MessageKeysUnavailable("missing"), RuntimeError("anything else at all")]
)
def test_when_the_table_cannot_be_used_the_chat_still_answers_once(error: Exception) -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id=OWNER, name="Birba", species="Cane"))
    model = _Model()
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        model,  # type: ignore[arg-type]
        pets,
        message_claims=MessageClaims(_BrokenKeys(error)),  # type: ignore[arg-type]
        in_flight=_InFlightMessages(),
    )
    values = {
        "owner_id": OWNER,
        "pet_id": "pet-1",
        "user_message": "perché mastica?",
        "client_message_id": CLIENT_ID,
    }

    first = service.execute(SendChatMessageInput.model_validate(values))
    retry = service.execute(SendChatMessageInput.model_validate(values))

    assert model.calls == 1  # the stored answer is replayed, as before QK-03b
    assert retry.mode == "replayed" and retry.reply.id == first.reply.id


def test_when_the_table_cannot_be_used_the_in_process_lock_still_holds() -> None:
    """The fallback is the lock inside the process, with the same behaviour as QK-03."""
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id=OWNER, name="Birba", species="Cane"))
    conversations = InMemoryConversationRepository()
    model = _Model()
    shared_lock = _InFlightMessages()
    service = SendChatMessageService(
        conversations,
        model,  # type: ignore[arg-type]
        pets,
        message_claims=MessageClaims(_BrokenKeys(MessageKeysUnavailable("missing"))),  # type: ignore[arg-type]
        in_flight=shared_lock,
    )
    values = {
        "owner_id": OWNER,
        "pet_id": "pet-1",
        "user_message": "BLOCCA scarpe",
        "client_message_id": CLIENT_ID,
    }
    outputs: list[SendChatMessageOutput] = []
    first = threading.Thread(
        target=lambda: outputs.append(service.execute(SendChatMessageInput.model_validate(values)))
    )
    first.start()
    assert model.entered.wait(timeout=5)
    second = threading.Thread(
        target=lambda: outputs.append(service.execute(SendChatMessageInput.model_validate(values)))
    )
    second.start()
    second.join(timeout=0.3)
    assert second.is_alive()  # waiting on the lock, not calling the model
    model.release.set()
    first.join(timeout=5)
    second.join(timeout=5)

    assert model.calls == 1 and len(outputs) == 2


def test_the_in_process_wait_constant_is_the_one_the_reservation_uses(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(send_chat_message, "DUPLICATE_WAIT_SECONDS", 3.0)
    a, b, keys, clock = _world()
    keys.claim(OWNER, CLIENT_ID, "still-running", clock.now)

    b.send()

    assert b.sleeps == 3  # 3 s of waiting in 1 s steps, then it answers by itself


# --- user B --------------------------------------------------------------------------------


def test_user_b_neither_sees_nor_blocks_user_as_keys() -> None:
    a, b, keys, clock = _world()
    keys.claim(OWNER, CLIENT_ID, "a-running", clock.now)  # A's message is in flight

    other = b.send(owner_id="owner-bbbb-2222", pet_id="pet-2")  # B, the very same client id

    assert other.mode != "replayed" and b.sleeps == 0
    assert [k.owner_id for k in keys.keys_of("owner-bbbb-2222")] == ["owner-bbbb-2222"]
    # A's key is untouched, and B's operations cannot reach it
    [a_key] = keys.keys_of(OWNER)
    assert a_key.conversation_id == "a-running" and a_key.answered_reply_id is None
    keys.release("owner-bbbb-2222", CLIENT_ID, a_key.claimed_at)
    keys.mark_answered("owner-bbbb-2222", CLIENT_ID, "x", a_key.claimed_at)
    assert keys.keys_of(OWNER)[0].answered_reply_id is None


# --- logs ----------------------------------------------------------------------------------


def test_no_personal_data_reaches_the_logs(caplog: pytest.LogCaptureFixture) -> None:
    caplog.set_level(logging.DEBUG)
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id=OWNER, name="Birba", species="Cane"))
    leaky = RuntimeError(f"duplicate key (owner_id, client_message_id)=({OWNER}, {CLIENT_ID})")
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        _Model(),  # type: ignore[arg-type]
        pets,
        message_claims=MessageClaims(_BrokenKeys(leaky)),  # type: ignore[arg-type]
        in_flight=_InFlightMessages(),
    )

    service.execute(
        SendChatMessageInput(
            owner_id=OWNER, pet_id="pet-1", user_message=SECRET_TEXT, client_message_id=CLIENT_ID
        )
    )

    logged = "\n".join(record.getMessage() for record in caplog.records)
    for secret in (OWNER, CLIENT_ID, SECRET_TEXT, "Birba"):
        assert secret not in logged
