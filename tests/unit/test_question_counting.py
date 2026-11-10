"""Plan "fratello maggiore", stage 4 (2026-11-10): only the message that opens a
topic counts as a question of the plan. Replies to the chat's own questions,
the second try after "Non mi ha aiutato" and urgencies do not. Read only from
the conversation's state, never from a field the app sends. The counters are
Pricing's (llm_budget.py): a continuation has its own ceiling there."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.domain.conversation.models import ChatMessage
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryLlmUsageRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

LIMIT_MODE = "user_limit_reached"
QUESTION = "come insegno a Toby a non tirare al guinzaglio?"


def _setup() -> tuple[ChatOrchestrator, RecordingLLMClient]:
    budget = LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={"main": 10_000_000},
        default_budget=10_000_000,
        user_daily_limit=1,
    )
    llm = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=budget,
        answer_models=["main"],
        urgent_answer_timeout_seconds=12,
    )
    return orchestrator, llm


def _ask(
    orchestrator: ChatOrchestrator,
    message: str,
    *,
    last_reply: str | None = None,
    health: bool = False,
    escalate: bool = False,
    consent_pending: bool = False,
    anamnesis: bool = False,
) -> ChatOrchestratorResult:
    history = []
    if last_reply is not None:
        history = [
            ChatMessage(role="user", content=QUESTION),
            ChatMessage(role="assistant", content=last_reply, health_answer=health or None),
        ]
    return orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Toby",
            owner_id="owner-1",
            user_daily_limit=1,
            conversation_history=history,
            escalate_health=escalate,
            awaiting_medical_record_consent=consent_pending,
            awaiting_anamnesis=anamnesis,
        )
    )


def test_a_second_new_topic_hits_the_limit() -> None:
    orchestrator, _ = _setup()

    assert _ask(orchestrator, QUESTION).mode != LIMIT_MODE
    assert _ask(orchestrator, "e quante volte al giorno va portato fuori?").mode == LIMIT_MODE


def test_after_a_courtesy_question_the_next_message_counts() -> None:
    # "Vuoi sapere altro?" closes an answer: it is not an anamnesis, and the
    # next message is a question of the plan (Orchestratore 2026-11-10).
    orchestrator, _ = _setup()
    _ask(orchestrator, QUESTION)

    result = _ask(
        orchestrator,
        "sì, e quante volte al giorno va portato fuori?",
        last_reply="Premia quando il guinzaglio è morbido. Vuoi sapere altro?",
    )

    assert result.mode == LIMIT_MODE


def test_the_answer_to_an_anamnesis_question_does_not_count() -> None:
    orchestrator, _ = _setup()
    _ask(orchestrator, QUESTION)

    result = _ask(
        orchestrator,
        "da due giorni, e mangia meno del solito",
        last_reply="Da quanto tempo succede? Mangia come sempre?",
        anamnesis=True,
    )

    assert result.mode != LIMIT_MODE


def test_a_new_topic_after_an_anamnesis_question_counts() -> None:
    orchestrator, _ = _setup()
    _ask(orchestrator, QUESTION)

    result = _ask(
        orchestrator,
        "ogni quanto va fatto il vaccino della rabbia?",
        last_reply="Da quanto tempo succede? Mangia come sempre?",
        anamnesis=True,
    )

    assert result.mode == LIMIT_MODE


def test_the_pipeline_marks_only_its_own_anamnesis_turns() -> None:
    questions_only = RecordingLLMClient("Da quanto tempo è così? Mangia come sempre?")
    full_answer = RecordingLLMClient("Può essere stanchezza dopo il caldo. Vuoi sapere altro?")
    for llm, expected in ((questions_only, True), (full_answer, False)):
        result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
            ChatOrchestratorInput(user_message="Toby è mogio", species="Cane", pet_name="Toby")
        )
        assert result.awaiting_anamnesis is expected


def test_the_anamnesis_flag_never_leaves_the_backend() -> None:
    from packages.core.domain.conversation.models import Conversation

    dump = Conversation(owner_id="o", pet_id="p", title="t", awaiting_anamnesis=True).public_dump()
    assert "awaiting_anamnesis" not in dump


def test_the_second_try_after_the_button_is_not_a_question() -> None:
    orchestrator, _ = _setup()
    _ask(orchestrator, "Toby ha la diarrea da due giorni, cosa faccio?")

    result = _ask(
        orchestrator,
        "ha la diarrea da due giorni e non mangia",
        last_reply="Osservalo a casa.",
        health=True,
        escalate=True,
    )

    assert result.mode != LIMIT_MODE


def test_the_reply_to_the_record_consent_question_is_not_a_question() -> None:
    orchestrator, _ = _setup()
    _ask(orchestrator, QUESTION)

    result = _ask(orchestrator, "sì", consent_pending=True)

    assert result.mode != LIMIT_MODE


def test_an_urgency_is_never_a_question_of_the_plan() -> None:
    orchestrator, _ = _setup()
    _ask(orchestrator, QUESTION)  # the day's only question

    urgent = _ask(orchestrator, "Toby ha appena mangiato il topicida e adesso trema e sbava")
    after = _ask(orchestrator, "e quante volte al giorno va portato fuori?")

    assert urgent.mode == "triage"
    assert after.mode == LIMIT_MODE  # the urgency did not use a question, the first one did
