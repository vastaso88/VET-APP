"""QK-12: the chat list without message bodies (GET /conversations/summaries), the messages of
one chat (GET /conversations/{id}) and the full history kept for the apps already installed
(GET /conversations), through the real API with two owners ("utente B")."""

import json
from collections.abc import Callable, Iterator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.conversation.models import ChatMessage, Conversation

OWNER_A = "aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa"
OWNER_B = "bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb"
BASE = datetime(2026, 11, 1, 9, 0, tzinfo=UTC)

INTERNAL_KEYS = {
    "situation_model",
    "coverage_score",
    "state",
    "interview_turns_used",
    "medical_record_consent",
    "awaiting_medical_record_consent",
    "awaiting_safety_clarification",
    "safety_clarification_category",
    "escalate_next_health",
    "awaiting_anamnesis",
}


@pytest.fixture
def as_user(monkeypatch: pytest.MonkeyPatch) -> Iterator[Callable[[str], None]]:
    """Switch who the fake sign-in says the caller is."""
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    current = {"id": OWNER_A}
    monkeypatch.setattr(
        inner,
        "get_current_user",
        lambda: AuthenticatedUser(id=current["id"], email="owner@example.com"),
    )

    def switch(user_id: str) -> None:
        current["id"] = user_id

    yield switch


def _chat(
    owner: str,
    *,
    title: str,
    minutes: int,
    turns: int = 1,
    pet_id: str = "pet-1",
    text: str = "domanda",
) -> Conversation:
    """A stored chat of [turns] owner/assistant exchanges, the last one at BASE + [minutes]."""
    messages = []
    for turn in range(turns):
        when = BASE + timedelta(minutes=minutes - (turns - 1 - turn))
        messages.append(ChatMessage(role="user", content=f"{text} {turn}", created_at=when))
        messages.append(
            ChatMessage(
                role="assistant",
                content=f"risposta {turn} " + "x" * 300,
                created_at=when + timedelta(seconds=5),
                ai_generated=True,
            )
        )
    conversation = Conversation(owner_id=owner, pet_id=pet_id, title=title, messages=messages)
    return get_container().conversation_repository.save(conversation)


def _ids(items: list[dict[str, object]]) -> list[str]:
    return [str(item["id"]) for item in items]


def test_two_pages_cover_every_chat_once_newest_activity_first(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    oldest = _chat(OWNER_A, title="Vecchia", minutes=0)
    middle = _chat(OWNER_A, title="Media", minutes=10)
    newest = _chat(OWNER_A, title="Nuova", minutes=20)

    first = client.get("/conversations/summaries", params={"limit": 2}).json()

    assert _ids(first["conversations"]) == [newest.id, middle.id]
    assert first["next_cursor"]
    second = client.get(
        "/conversations/summaries", params={"limit": 2, "cursor": first["next_cursor"]}
    ).json()
    assert _ids(second["conversations"]) == [oldest.id]
    assert second["next_cursor"] is None


def test_a_row_has_the_light_fields_and_no_messages(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    chat = _chat(OWNER_A, title="Zampa", minutes=5, turns=3)

    [row] = client.get("/conversations/summaries").json()["conversations"]

    assert set(row) == {
        "id",
        "pet_id",
        "title",
        "last_activity_at",
        "last_message_role",
        "last_message_preview",
        "message_count",
    }
    assert row["id"] == chat.id and row["pet_id"] == "pet-1" and row["title"] == "Zampa"
    assert row["message_count"] == 6 and row["last_message_role"] == "assistant"
    assert str(row["last_message_preview"]).startswith("risposta 2")
    assert len(str(row["last_message_preview"])) <= 160  # a preview, not the body


def test_a_chat_with_no_message_is_listed_at_the_bottom_with_no_activity(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    with_messages = _chat(OWNER_A, title="Con messaggi", minutes=1)
    empty = get_container().conversation_repository.save(
        Conversation(owner_id=OWNER_A, pet_id="pet-1", title="Vuota")
    )

    rows = client.get("/conversations/summaries").json()["conversations"]

    assert _ids(rows) == [with_messages.id, empty.id]
    assert rows[1]["last_activity_at"] is None and rows[1]["message_count"] == 0


def test_a_legacy_title_is_replaced_in_the_list_like_in_the_full_history(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    chat = _chat(OWNER_A, title="Chat for pet-1", minutes=0, text="il gatto starnutisce")

    [row] = client.get("/conversations/summaries").json()["conversations"]

    assert row["title"] != "Chat for pet-1" and row["title"].startswith("Il gatto starnutisce")
    stored = get_container().conversation_repository.get(chat.id)
    assert stored is not None and stored.title == row["title"]  # persisted, as the old list does


def test_user_b_sees_none_of_user_as_chats(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    mine = _chat(OWNER_A, title="Privata", minutes=0)
    first = client.get("/conversations/summaries").json()
    assert _ids(first["conversations"]) == [mine.id]

    as_user(OWNER_B)
    assert client.get("/conversations/summaries").json()["conversations"] == []
    # A's cursor in B's hands does not reveal anything either.
    cursor = client.get("/conversations/summaries", params={"limit": 1}).json()["next_cursor"]
    assert cursor is None
    stolen = client.get(f"/conversations/{mine.id}")
    missing = client.get("/conversations/does-not-exist")
    assert stolen.status_code == missing.status_code == 400
    assert stolen.json() == {"detail": "conversation not found"} == missing.json()


def test_the_detail_returns_the_messages_of_the_owners_chat_without_internals(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    chat = _chat(OWNER_A, title="Zampa", minutes=0, turns=2)

    body = client.get(f"/conversations/{chat.id}").json()["conversation"]

    assert body["id"] == chat.id and body["pet_id"] == "pet-1"
    assert [m["role"] for m in body["messages"]] == ["user", "assistant", "user", "assistant"]
    assert not INTERNAL_KEYS & set(body)
    assert all("state_after" not in m and "record_shared" not in m for m in body["messages"])
    assert {"id", "role", "content", "created_at"} <= set(body["messages"][0])


def test_the_old_full_history_is_unchanged_for_apps_already_installed(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    chat = _chat(OWNER_A, title="Zampa", minutes=0, turns=2)

    listed = client.get("/conversations").json()

    assert list(listed) == ["conversations"]  # no new top-level key the old app could choke on
    [row] = listed["conversations"]
    assert row["id"] == chat.id and len(row["messages"]) == 4
    assert {"id", "pet_id", "title", "messages"} <= set(row)
    assert not INTERNAL_KEYS & set(row)


def test_a_rename_does_not_move_the_chat_and_a_delete_does_not_shift_the_next_page(
    as_user: Callable[[str], None],
) -> None:
    client = TestClient(app)
    c3 = _chat(OWNER_A, title="Terza", minutes=30)
    c2 = _chat(OWNER_A, title="Seconda", minutes=20)
    c1 = _chat(OWNER_A, title="Prima", minutes=10)

    first = client.get("/conversations/summaries", params={"limit": 1}).json()
    assert _ids(first["conversations"]) == [c3.id]

    assert client.patch(f"/conversations/{c3.id}", json={"title": "Rinominata"}).status_code == 200
    assert client.delete(f"/conversations/{c3.id}").status_code == 204  # the cursor's own chat
    second = client.get(
        "/conversations/summaries", params={"limit": 5, "cursor": first["next_cursor"]}
    ).json()

    assert _ids(second["conversations"]) == [c2.id, c1.id]  # nothing skipped, nothing repeated
    renamed = client.get("/conversations/summaries").json()["conversations"]
    assert _ids(renamed) == [c2.id, c1.id]


def test_a_rename_shows_in_the_list_in_the_same_position(as_user: Callable[[str], None]) -> None:
    client = TestClient(app)
    top = _chat(OWNER_A, title="Alta", minutes=30)
    low = _chat(OWNER_A, title="Bassa", minutes=10)

    client.patch(f"/conversations/{low.id}", json={"title": "Esami di settembre"})

    rows = client.get("/conversations/summaries").json()["conversations"]
    assert _ids(rows) == [top.id, low.id]
    assert rows[1]["title"] == "Esami di settembre"


@pytest.mark.parametrize("cursor", ["not-a-cursor", "e30", "%%%"])
def test_a_bad_cursor_is_a_clean_400(as_user: Callable[[str], None], cursor: str) -> None:
    client = TestClient(app)

    response = client.get("/conversations/summaries", params={"cursor": cursor})

    assert response.status_code == 400
    assert response.json() == {"detail": "invalid_cursor"}


@pytest.mark.parametrize("limit", [0, 51, -1])
def test_the_page_size_is_bounded(as_user: Callable[[str], None], limit: int) -> None:
    client = TestClient(app)

    assert client.get("/conversations/summaries", params={"limit": limit}).status_code == 422


def test_bytes_the_home_downloads_before_and_after(
    as_user: Callable[[str], None], capsys: pytest.CaptureFixture[str]
) -> None:
    """The measurement asked by QK-12: 4 chats of 20 exchanges each. Before, the start
    downloaded all of it; now only the rows, and the messages of the chat the owner opens."""
    client = TestClient(app)
    chats = [_chat(OWNER_A, title=f"Chat {n}", minutes=n * 60, turns=20) for n in range(4)]

    legacy = len(client.get("/conversations").content)
    light = len(client.get("/conversations/summaries").content)
    opened = len(client.get(f"/conversations/{chats[0].id}").content)

    with capsys.disabled():
        print(
            "\nQK-12 bytes: before(GET /conversations)="
            f"{legacy} after(summaries)={light} + one chat opened={opened}"
        )
    assert light * 10 < legacy  # the list costs a tenth or less of the full history
    assert json.loads(client.get("/conversations/summaries").content)["next_cursor"] is None
