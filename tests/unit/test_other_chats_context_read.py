"""QK-11: the v2 "other chats" context is a bounded read, not every conversation of the pet.

Flag off: that context is not read at all. Flag on: the same lines as the old selection
(recent, expired, empty, legacy rows, other owner, other pet, the current chat itself) from
a read limited to this owner and pet, not this chat, active in the last 72 hours. The
Supabase adapter is exercised with a fake client (nothing leaves the machine) that also
counts the rows and bytes it hands back. Fake provider only."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseConversationRepository,
)

NOW = datetime.now(UTC)
OWNER = "owner-a"
PET = "pet-a1"


def _chat(
    *texts: str,
    owner: str = OWNER,
    pet: str = PET,
    hours_ago: float = 1.0,
    consent: bool | None = None,
    identifier: str | None = None,
) -> Conversation:
    start = NOW - timedelta(hours=hours_ago)
    values: dict[str, Any] = {
        "owner_id": owner,
        "pet_id": pet,
        "title": "x",
        "medical_record_consent": consent,
        "messages": [
            ChatMessage(
                role="user" if i % 2 == 0 else "assistant",
                content=text,
                created_at=start + timedelta(minutes=i),
            )
            for i, text in enumerate(texts)
        ],
    }
    if identifier:
        values["id"] = identifier
    return Conversation(**values)


# --- a Supabase fake that counts what it returns ----------------------------------------------


class _Result:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, client: _Client, columns: str) -> None:
        self._client = client
        self._columns = columns
        self._filters: list[Any] = []
        self._order: tuple[str, bool] | None = None
        self._limit: int | None = None

    def eq(self, column: str, value: Any) -> _Query:
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def neq(self, column: str, value: Any) -> _Query:
        self._filters.append(lambda row: row.get(column) != value)
        return self

    def gte(self, column: str, value: str) -> _Query:
        self._filters.append(
            lambda row: row.get(column) is not None and row[column] >= value  # ISO strings
        )
        return self

    def is_(self, column: str, value: str) -> _Query:
        assert value == "null"
        self._filters.append(lambda row: row.get(column) is None)
        return self

    def order(self, column: str, *, desc: bool = False) -> _Query:
        self._order = (column, desc)
        return self

    def limit(self, count: int) -> _Query:
        self._limit = count
        return self

    def execute(self) -> _Result:
        client = self._client
        if self._columns != "*":
            for column in self._columns.split(","):
                if column in client.missing_columns:
                    raise RuntimeError(f"column conversations.{column} does not exist")
        rows = [row for row in client.rows if all(f(row) for f in self._filters)]
        if self._order is not None:
            column, desc = self._order
            rows.sort(key=lambda row: row.get(column) or "", reverse=desc)
        if self._limit is not None:
            rows = rows[: self._limit]
        if self._columns != "*":
            wanted = self._columns.split(",")
            rows = [{k: v for k, v in row.items() if k in wanted} for row in rows]
        client.reads += 1
        client.rows_returned += len(rows)
        client.bytes_returned += len(json.dumps(rows, default=str))
        return _Result(rows)


class _Table:
    def __init__(self, client: _Client) -> None:
        self._client = client

    def select(self, columns: str) -> _Query:
        return _Query(self._client, columns)


class _Client:
    def __init__(self, *missing_columns: str) -> None:
        self.rows: list[dict[str, Any]] = []
        self.missing_columns = set(missing_columns)
        self.reads = 0
        self.rows_returned = 0
        self.bytes_returned = 0

    def table(self, name: str) -> _Table:
        assert name == "conversations"
        return _Table(self)

    def store(self, conversation: Conversation, *, dated: bool = True) -> None:
        row = conversation.model_dump(mode="json")
        row["last_message_at"] = (
            conversation.messages[-1].created_at.isoformat()
            if dated and conversation.messages
            else None
        )
        self.rows.append(row)

    def reset(self) -> None:
        self.reads = self.rows_returned = self.bytes_returned = 0


# --- the service on both adapters -------------------------------------------------------------


class _Orchestrator:
    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        return ChatOrchestratorResult(
            answer="ok", mode="natural", confidence="medium", ai_generated=True,
            provider="fake", model="fake",
        )  # fmt: skip


def _service(repo: Any, *, v2: bool = True) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id=PET, owner_id=OWNER, name="Cicci", species="Uccelli"))
    return SendChatMessageService(repo, _Orchestrator(), pets, recent_other_chats=v2)  # type: ignore[arg-type]


def _lines(
    service: SendChatMessageService, current: Conversation, allowed: bool = True
) -> list[str]:
    return [m.content for m in service._recent_other_chat_lines(current, allowed, NOW)]


def _legacy_lines(chats: list[Conversation], current: Conversation, allowed: bool) -> list[str]:
    """The selection as it was before QK-11, kept here as the reference (list_by_pet + filters)."""
    repo = InMemoryConversationRepository()
    for chat in chats:
        repo.save(chat)
    old = _service(repo)
    window = old._OTHER_CHATS_WINDOW
    others = [
        c
        for c in repo.list_by_pet(current.pet_id)
        if c.id != current.id
        and c.owner_id == current.owner_id
        and c.messages
        and NOW - c.messages[-1].created_at <= window
    ]
    others.sort(key=lambda c: c.messages[-1].created_at)
    from packages.core.domain.conversation.models import history_without_record

    lines: list[ChatMessage] = []
    for other in others[-old._OTHER_CHATS_MAX :]:
        messages = other.messages
        if not allowed:
            messages = history_without_record(
                messages, conversation_had_consent=other.medical_record_consent is True
            )
        first = next((m for m in messages if m.role == "user"), None)
        chosen = [first] if first is not None else []
        chosen += [m for m in messages[-old._OTHER_CHATS_LINES :] if m is not first]
        lines += [m for m in chosen if NOW - m.created_at <= window]
    return [m.content for m in lines]


def _scenarios() -> dict[str, tuple[list[Conversation], Conversation]]:
    current = _chat("domanda di adesso", hours_ago=0.1, identifier="current")
    recent_two = [
        _chat("prima A", "risposta A", "ultima A", hours_ago=30),
        _chat("prima B", "risposta B", "ultima B", hours_ago=2),
    ]
    return {
        "two recent": ([*recent_two, current], current),
        "three recent, only the latest two": (
            [_chat("t1", "t2", hours_ago=60), *recent_two, current],
            current,
        ),
        "expired": ([_chat("vecchia", "ok", hours_ago=100), current], current),
        "empty chat": ([Conversation(owner_id=OWNER, pet_id=PET, title="x"), current], current),
        "a chat spans the window: old start, recent end": (
            [_chat("inizio vecchio", "x", "y", "ancora z", hours_ago=73.5), current],
            current,
        ),
        "other owner, other pet": (
            [
                _chat("segreto", "no", owner="owner-b"),
                _chat("altro animale", "no", pet="pet-a2"),
                current,
            ],
            current,
        ),
        "with the record consent given in the other chat": (
            [_chat("u", "a", "u2", "a2", hours_ago=3, consent=True), current],
            current,
        ),
        "nothing else": ([current], current),
    }


@pytest.mark.parametrize("scenario", list(_scenarios()))
@pytest.mark.parametrize("allowed", [True, False])
@pytest.mark.parametrize("dated", [True, False], ids=["dated", "legacy-undated"])
def test_the_bounded_read_gives_the_same_lines_as_the_old_selection(
    scenario: str, allowed: bool, dated: bool
) -> None:
    chats, current = _scenarios()[scenario]
    expected = _legacy_lines(chats, current, allowed)

    memory = InMemoryConversationRepository()
    client = _Client()
    for chat in chats:
        memory.save(chat)
        client.store(chat, dated=dated)  # undated = rows from before last_message_at existed

    assert _lines(_service(memory), current, allowed) == expected
    supabase = SupabaseConversationRepository(client)  # type: ignore[arg-type]
    assert _lines(_service(supabase), current, allowed) == expected


def test_a_live_table_without_the_columns_falls_back_to_the_whole_pet_and_still_agrees() -> None:
    chats, current = _scenarios()["three recent, only the latest two"]
    client = _Client("last_message_at")  # the retention script was never run
    for chat in chats:
        client.store(chat)
    supabase = SupabaseConversationRepository(client)  # type: ignore[arg-type]

    assert _lines(_service(supabase), current) == _legacy_lines(chats, current, True)


# --- flag off, flag on, user B ----------------------------------------------------------------


class _CountingRepo(InMemoryConversationRepository):
    def __init__(self) -> None:
        super().__init__()
        self.context_reads = 0
        self.whole_pet_reads = 0

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        self.whole_pet_reads += 1
        return super().list_by_pet(pet_id)

    def list_recent_for_context(self, *args: Any, **kwargs: Any) -> list[Conversation]:
        self.context_reads += 1
        return super().list_recent_for_context(*args, **kwargs)


def test_with_the_flag_off_that_context_is_never_read() -> None:
    repo = _CountingRepo()
    repo.save(_chat("una", "due", hours_ago=2))
    current = _chat("adesso", identifier="current")

    lines = _service(repo, v2=False)._recent_other_chat_lines(current, True, NOW)

    assert lines == [] and repo.context_reads == 0 and repo.whole_pet_reads == 0


def test_with_the_flag_on_a_new_message_makes_one_bounded_read_and_no_whole_pet_read() -> None:
    repo = _CountingRepo()
    repo.save(_chat("una", "due", hours_ago=2))
    service = _service(repo, v2=True)

    service.execute(SendChatMessageInput(owner_id=OWNER, pet_id=PET, user_message="ciao"))

    assert repo.context_reads == 1
    assert repo.whole_pet_reads == 1  # only QK-03's single candidates read of the new chat


def test_user_b_never_gets_user_as_chats_from_the_bounded_read() -> None:
    client = _Client()
    client.store(_chat("SEGRETO-A", "no", hours_ago=1))
    supabase = SupabaseConversationRepository(client)  # type: ignore[arg-type]
    intruder = _chat("adesso", owner="owner-b", pet=PET, identifier="b-current")

    lines = _lines(_service(supabase), intruder)

    assert lines == []
    assert client.rows_returned == 0  # not even read: the query was scoped to owner-b


# --- rows and bytes before and after ----------------------------------------------------------


def test_rows_and_bytes_read_before_and_after(capsys: pytest.CaptureFixture[str]) -> None:
    """Fixture: one pet with 4 chats of 30 long messages (1 recent, 3 older than 72 hours) and
    2 chats of other pets of the same owner."""
    chats = [
        _chat(*[f"messaggio {i} " + "lungo " * 60 for i in range(30)], hours_ago=1 + 100 * n)
        for n in range(4)
    ]
    other_pets = [_chat("altro", "ok", pet="pet-a2"), _chat("altro 2", "ok", pet="pet-a3")]
    current = _chat("adesso", identifier="current")
    client = _Client()
    for chat in [*chats, *other_pets]:
        client.store(chat)
    supabase = SupabaseConversationRepository(client)  # type: ignore[arg-type]

    supabase.list_by_pet(PET)  # before: every conversation of the pet, whole
    before = (client.rows_returned, client.bytes_returned)
    client.reset()
    _lines(_service(supabase), current)  # after
    after = (client.rows_returned, client.bytes_returned)

    with capsys.disabled():
        print(f"\nQK-11 rows/bytes: before={before} after={after}")
    assert after[0] < before[0] and after[1] * 3 < before[1]
