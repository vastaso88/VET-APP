"""Pro: 15 questions a day PER CHAT and 40 for the account; Ultra 20 and 80 (owner, 25/11/2026).

The chat's count is made by the server from the conversation it stores (the owner's messages it
marked `counted_as_question`), never from what the app sends; only the message that opens a topic
is a question; a refused turn and an apology are not; Plus and Ultra have no cap per chat."""

from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient

from apps.api.main import app
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
    questions_today_in,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.safety.harmful_requests import CHAT_LIMIT_TEXTS, LIMIT_UPGRADE_TEXTS
from packages.core.domain.subscription.limits import (
    LIMITS_BY_PLAN,
    NO_ACCESS_LIMITS,
    TRIAL_LIMITS,
    PlanLimits,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.user_clock import reset_utc_offset_minutes, set_utc_offset_minutes

GROQ = "openai/gpt-oss-120b"
TOPICS = [
    "quante crocchette deve mangiare al giorno?",
    "ogni quanto va portato a spasso?",
    "come si taglia il pelo senza stressarlo?",
    "che gioco posso comprare per lui?",
    "quanto dorme un cane adulto?",
    "come si pulisce la cuccia?",
]


@pytest.fixture(autouse=True)
def utc_clock() -> Iterator[None]:
    token = set_utc_offset_minutes(0)
    yield
    reset_utc_offset_minutes(token)


class _World:
    """Two owners, one pet each, the real budget over an in-memory ledger."""

    def __init__(self, limits: PlanLimits | None) -> None:
        self.ledger = InMemoryLlmUsageRepository()
        budget = LlmBudget(
            self.ledger, budgets={GROQ: 10_000}, default_budget=10_000, refresh_seconds=3600.0
        )
        pets = InMemoryPetProfileRepository()
        pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
        pets.save(PetProfile(id="pet-b", owner_id="owner-b", name="Luna", species="Gatto"))
        self.conversations = InMemoryConversationRepository()
        orchestrator = ChatOrchestrator(
            RecordingLLMClient(),
            InMemoryEvidenceRetriever(),
            NoopPiiAnonymizer(),
            usage_budget=budget,
            answer_models=[GROQ],
        )
        self.service = SendChatMessageService(
            self.conversations, orchestrator, pets, owner_limits=lambda _o, _e: limits
        )

    def ask(
        self,
        text: str,
        *,
        owner: str = "owner-a",
        pet: str = "pet-a",
        conversation_id: str | None = None,
        language: str | None = None,
    ) -> SendChatMessageOutput:
        extra = {} if language is None else {"language": language}
        return self.service.execute(
            SendChatMessageInput(
                owner_id=owner,
                pet_id=pet,
                user_message=text,
                conversation_id=conversation_id,
                **extra,
            )
        )


def _limits(per_chat: int | None, account: int = 40) -> PlanLimits:
    return PlanLimits(
        max_pets=8,
        max_chats_per_pet=4,
        daily_questions=account,
        daily_questions_per_chat=per_chat,
        max_devices=3,
        source="pro",
    )


# --- the numbers -----------------------------------------------------------------------------


def test_pro_has_fifteen_per_chat_and_sixty_for_the_account() -> None:
    pro, ultra = LIMITS_BY_PLAN["pro"], LIMITS_BY_PLAN["ultra"]

    assert (pro.daily_questions_per_chat, pro.daily_questions) == (15, 40)
    assert (ultra.daily_questions_per_chat, ultra.daily_questions) == (20, 80)


def test_the_trial_is_like_pro_plus_has_no_cap_per_chat_and_no_access_none() -> None:
    assert TRIAL_LIMITS.daily_questions_per_chat == 15 and TRIAL_LIMITS.daily_questions == 40
    assert LIMITS_BY_PLAN["plus"].daily_questions_per_chat is None
    assert NO_ACCESS_LIMITS.daily_questions_per_chat is None


def test_the_status_reports_the_new_field_for_every_plan() -> None:
    body = TestClient(app).get("/subscription/status").json()

    assert body["limits"]["daily_questions_per_chat"] == 15  # the public test reports Pro
    assert body["plan_limits"]["pro"]["daily_questions_per_chat"] == 15
    assert body["plan_limits"]["plus"]["daily_questions_per_chat"] is None
    assert body["plan_limits"]["ultra"]["daily_questions_per_chat"] == 20
    assert body["plan_limits"]["ultra"]["max_devices"] == 5


# --- the count, made by the server -----------------------------------------------------------


def test_the_chat_stops_at_its_limit_and_the_account_count_is_not_spent() -> None:
    world = _World(_limits(per_chat=3))
    first = world.ask(TOPICS[0])
    chat = first.conversation.id
    world.ask(TOPICS[1], conversation_id=chat)
    world.ask(TOPICS[2], conversation_id=chat)

    refused = world.ask(TOPICS[3], conversation_id=chat)

    assert refused.reply.content.startswith(
        CHAT_LIMIT_TEXTS["it"].format(limit=3, wait="|").split("|")[0]
    )
    assert "In questa chat hai usato tutte le 3 domande di oggi" in refused.reply.content
    assert "un'altra chat" in refused.reply.content
    assert LIMIT_UPGRADE_TEXTS["it"].strip()[:10] not in refused.reply.content
    stored = world.conversations.get(chat)
    assert stored is not None
    marked = [m for m in stored.messages if m.role == "user" and m.counted_as_question]
    assert len(marked) == 3  # the refused one is not a question
    # Three questions were counted for the account; the refused one cost it nothing (the next
    # message would be the fourth).
    assert world.ledger.add_user_message("owner-a", datetime.now(UTC).date()) == 4


def test_another_chat_of_the_same_pet_still_has_its_own_questions() -> None:
    world = _World(_limits(per_chat=2))
    chat = world.ask(TOPICS[0]).conversation.id
    world.ask(TOPICS[1], conversation_id=chat)
    assert "In questa chat" in world.ask(TOPICS[2], conversation_id=chat).reply.content

    elsewhere = world.ask(TOPICS[2])  # a new chat

    assert "In questa chat" not in elsewhere.reply.content
    assert elsewhere.conversation.id != chat


def test_the_account_limit_still_applies_across_chats() -> None:
    world = _World(_limits(per_chat=15, account=2))
    world.ask(TOPICS[0])
    world.ask(TOPICS[1])

    refused = world.ask(TOPICS[2])  # a third chat: the account has no questions left

    assert "In questa chat" not in refused.reply.content
    assert "2 domande" in refused.reply.content


def test_without_a_cap_per_chat_only_the_account_counts() -> None:
    world = _World(_limits(per_chat=None, account=40))
    chat = world.ask(TOPICS[0]).conversation.id
    for text in TOPICS[1:]:
        reply = world.ask(text, conversation_id=chat).reply.content
        assert "In questa chat" not in reply


def test_a_developer_without_limits_is_never_refused_for_the_chat() -> None:
    world = _World(None)
    chat = world.ask(TOPICS[0]).conversation.id
    for text in TOPICS[1:]:
        assert "In questa chat" not in world.ask(text, conversation_id=chat).reply.content


def test_owner_b_has_his_own_count_and_cannot_use_owner_as_chat() -> None:
    world = _World(_limits(per_chat=2))
    chat_a = world.ask(TOPICS[0]).conversation.id
    world.ask(TOPICS[1], conversation_id=chat_a)
    assert "In questa chat" in world.ask(TOPICS[2], conversation_id=chat_a).reply.content

    # B's own chat is untouched by A's...
    chat_b = world.ask(TOPICS[0], owner="owner-b", pet="pet-b").conversation.id
    assert (
        "In questa chat"
        not in world.ask(
            TOPICS[1], owner="owner-b", pet="pet-b", conversation_id=chat_b
        ).reply.content
    )
    # ...and B cannot write into A's chat (answered like a chat that does not exist).
    with pytest.raises(Exception, match="not found"):
        world.ask(TOPICS[3], owner="owner-b", pet="pet-a", conversation_id=chat_a)


def test_nothing_the_app_sends_can_set_the_chat_count() -> None:
    assert "chat_questions_today" not in SendChatMessageInput.model_fields
    assert "chat_daily_limit" not in SendChatMessageInput.model_fields
    sent = TestClient(app).post(
        "/chat",
        json={
            "pet_id": "x",
            "user_message": "ciao",
            "chat_questions_today": 0,
            "chat_daily_limit": 999,
            "counted_as_question": False,
        },
    )
    assert sent.status_code in {200, 400, 404, 422}  # extra keys are ignored, never trusted


def test_the_mark_stays_on_the_server() -> None:
    world = _World(_limits(per_chat=3))
    chat = world.ask(TOPICS[0]).conversation.id
    stored = world.conversations.get(chat)
    assert stored is not None
    assert any(m.counted_as_question for m in stored.messages)

    public = stored.public_dump()

    assert all("counted_as_question" not in message for message in public["messages"])


# --- what counts as today's question of a chat ----------------------------------------------


def _chat(*messages: ChatMessage) -> Conversation:
    return Conversation(owner_id="o", pet_id="p", title="t", messages=list(messages))


def _user(text: str, *, counted: bool | None, at: datetime) -> ChatMessage:
    return ChatMessage(role="user", content=text, counted_as_question=counted, created_at=at)


def test_only_marked_messages_of_the_owners_day_count() -> None:
    now = datetime(2026, 11, 25, 12, 0, tzinfo=UTC)
    chat = _chat(
        _user("ieri", counted=True, at=now - timedelta(days=1)),
        _user("oggi 1", counted=True, at=now - timedelta(hours=3)),
        _user("seguito", counted=False, at=now - timedelta(hours=2)),
        _user("vecchio, senza segno", counted=None, at=now - timedelta(hours=1)),
        ChatMessage(role="assistant", content="risposta", counted_as_question=True, created_at=now),
        _user("oggi 2", counted=True, at=now - timedelta(minutes=5)),
    )

    assert questions_today_in(chat, now) == 2


def test_the_day_is_the_owners_own() -> None:
    now = datetime(2026, 11, 25, 23, 30, tzinfo=UTC)
    chat = _chat(_user("a", counted=True, at=datetime(2026, 11, 25, 21, 30, tzinfo=UTC)))
    assert questions_today_in(chat, now) == 1

    # For a phone two hours ahead the question was at 23:30 of the 25th and it is now the 26th.
    token = set_utc_offset_minutes(120)
    try:
        assert questions_today_in(chat, now) == 0
    finally:
        reset_utc_offset_minutes(token)


# --- the orchestrator ------------------------------------------------------------------------


def _orchestrator() -> tuple[ChatOrchestrator, InMemoryLlmUsageRepository]:
    ledger = InMemoryLlmUsageRepository()
    budget = LlmBudget(ledger, budgets={GROQ: 10_000}, default_budget=10_000)
    return (
        ChatOrchestrator(
            RecordingLLMClient(),
            InMemoryEvidenceRetriever(),
            NoopPiiAnonymizer(),
            usage_budget=budget,
            answer_models=[GROQ],
        ),
        ledger,
    )


def _input(**values: object) -> ChatOrchestratorInput:
    base: dict[str, object] = {
        "user_message": "quante crocchette deve mangiare al giorno?",
        "species": "Cane",
        "pet_name": "Milo",
        "owner_id": "owner-a",
        "user_daily_limit": 40,
        "chat_daily_limit": 15,
    }
    return ChatOrchestratorInput(**{**base, **values})  # type: ignore[arg-type]


def test_a_message_that_continues_a_topic_is_not_stopped_by_the_chat_limit() -> None:
    orchestrator, _ = _orchestrator()

    result = orchestrator.answer(_input(chat_questions_today=15, continues_topic=True))

    assert result.mode != "user_limit_reached"
    assert result.question_counted is False


def test_the_message_that_opens_a_topic_is_counted_and_a_refused_one_is_not() -> None:
    orchestrator, _ = _orchestrator()

    opened = orchestrator.answer(_input(chat_questions_today=14))
    refused = orchestrator.answer(_input(chat_questions_today=15))

    assert opened.question_counted is True
    assert refused.mode == "user_limit_reached" and refused.question_counted is False


@pytest.mark.parametrize(
    ("language", "start"),
    [
        ("it", "In questa chat hai usato tutte le 15 domande di oggi"),
        ("en", "In this chat you have used all 15 questions for today"),
        ("es", "En este chat has usado las 15 preguntas de hoy"),
        ("de", "In diesem Chat haben Sie alle 15 Fragen für heute verbraucht"),
        ("fr", "Dans cette conversation, vous avez utilisé les 15 questions d'aujourd'hui"),
    ],
)
def test_the_message_is_calm_and_in_the_owners_language(language: str, start: str) -> None:
    orchestrator, _ = _orchestrator()

    result = orchestrator.answer(_input(chat_questions_today=15, language=language))

    assert result.answer.startswith(start)
    assert result.ai_generated is False
    assert "Pro" not in result.answer  # no plan to move up to: Ultra has no cap per chat
    assert not any(word in result.answer.lower() for word in ("credit", "acquista", "€"))


# --- an apology is not a question -------------------------------------------------------------


class _Apologising(ChatOrchestrator):
    """Counted the question, then the provider failed: an apology instead of an answer."""

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        real = super().answer(data)
        return real.model_copy(update={"mode": "quota_exhausted", "question_counted": True})


def test_a_turn_ended_by_an_apology_is_given_back_and_not_marked() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a", owner_id="owner-a", name="Milo", species="Cane"))
    conversations = InMemoryConversationRepository()
    given_back: list[bool] = []
    service = SendChatMessageService(
        conversations,
        _Apologising(RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        owner_limits=lambda _o, _e: _limits(per_chat=3),
        quota_refund=lambda: given_back.append(True),
    )

    out = service.execute(
        SendChatMessageInput(owner_id="owner-a", pet_id="pet-a", user_message=TOPICS[0])
    )

    assert given_back == [True]
    assert all(not m.counted_as_question for m in out.conversation.messages)
    assert questions_today_in(out.conversation) == 0
