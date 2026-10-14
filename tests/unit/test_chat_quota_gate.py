"""Build 32: a turn that cannot be answered today is refused kindly, with
the time to wait, and never an emergency or a dosage question (those are
answered by fixed text that uses no model)."""

from __future__ import annotations

from datetime import UTC, datetime

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.llm_budget import LlmBudget, QuotaExhausted
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

MAIN = "openai/gpt-oss-120b"
NOON = datetime(2026, 10, 14, 12, 0, tzinfo=UTC)


def _budget(**kw: object) -> LlmBudget:
    return LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={MAIN: 1000},
        default_budget=1000,
        clock=lambda: NOON,
        refresh_seconds=3600.0,
        **kw,  # type: ignore[arg-type]
    )


def _orchestrator(client: RecordingLLMClient, budget: LlmBudget) -> ChatOrchestrator:
    return ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=budget,
        answer_models=[MAIN],
    )


def _ask(orchestrator: ChatOrchestrator, text: str, *, quota_exempt: bool = False) -> object:
    return orchestrator.answer(
        ChatOrchestratorInput(
            user_message=text,
            species="Cane",
            pet_name="Rex",
            owner_id="anna",
            quota_exempt=quota_exempt,
        )
    )


def test_after_the_daily_allowance_the_owner_is_told_when_to_come_back() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, _budget(user_daily_limit=2))

    _ask(orchestrator, "quante volte al giorno deve mangiare?")
    _ask(orchestrator, "e quanta acqua deve bere?")
    calls_before = len(client.requests)
    result = _ask(orchestrator, "posso dargli le carote?")

    assert result.mode == "user_limit_reached"  # type: ignore[attr-defined]
    assert result.ai_generated is False  # type: ignore[attr-defined]
    assert "2 messaggi" in result.answer  # type: ignore[attr-defined]
    assert "12 ore" in result.answer  # type: ignore[attr-defined]
    assert "Rex" in result.answer  # type: ignore[attr-defined]
    assert len(client.requests) == calls_before


def test_emergencies_and_dosage_questions_are_never_refused() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, _budget(user_daily_limit=1))
    _ask(orchestrator, "quante volte al giorno deve mangiare?")
    _ask(orchestrator, "posso dargli le carote?")  # over the allowance from here

    emergency = _ask(orchestrator, "respira a bocca aperta e fa molta fatica a respirare")
    dosage = _ask(orchestrator, "quanti ml di sciroppo gli posso dare?")

    assert emergency.mode == "triage"  # type: ignore[attr-defined]
    assert emergency.model == "safety-triage-guard"  # type: ignore[attr-defined]
    assert dosage.model == "dosage-guard"  # type: ignore[attr-defined]


def test_developer_accounts_are_not_limited() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, _budget(user_daily_limit=1))

    for _ in range(4):
        result = _ask(orchestrator, "quante volte al giorno deve mangiare?", quota_exempt=True)
        assert result.mode == "natural"  # type: ignore[attr-defined]


def test_with_every_model_exhausted_the_reply_says_the_assistant_is_busy() -> None:
    client = RecordingLLMClient()
    budget = _budget()
    budget.note_usage(MAIN, 1000)
    orchestrator = _orchestrator(client, budget)

    result = _ask(orchestrator, "quante volte al giorno deve mangiare?")

    assert result.mode == "quota_exhausted"  # type: ignore[attr-defined]
    assert "molto richiesto" in result.answer  # type: ignore[attr-defined]
    assert "Riprova tra circa 12 ore" in result.answer  # type: ignore[attr-defined]
    assert client.requests == []


def test_a_quota_refusal_from_the_provider_mid_turn_gets_the_same_kind_reply() -> None:
    client = RecordingLLMClient(by_purpose={"answer": QuotaExhausted(3600)})
    orchestrator = _orchestrator(client, _budget())

    result = _ask(orchestrator, "quante volte al giorno deve mangiare?")

    assert result.mode == "quota_exhausted"  # type: ignore[attr-defined]
    assert "1 ora" in result.answer  # type: ignore[attr-defined]
    assert "non disponibile" not in result.answer  # type: ignore[attr-defined]
