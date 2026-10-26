"""Build 33: small talk costs nothing, a cached question never carries a
name, and the usage ledger has a retention job."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.ports.answer_cache_repository import CachedAnswer
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.maintain_chat_usage import ChatUsageMaintenanceService
from packages.core.domain.llm_usage.models import LlmUsageEvent
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
    InMemoryLlmUsageRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer

NOON = datetime(2026, 10, 14, 12, 0, tzinfo=UTC)


def _ask(orchestrator: ChatOrchestrator, text: str, **kw: object) -> object:
    fields: dict[str, object] = {"species": "Cane", "pet_name": "Rex", "owner_id": "anna", **kw}
    return orchestrator.answer(ChatOrchestratorInput(user_message=text, **fields))  # type: ignore[arg-type]


# --- small talk -------------------------------------------------------------------


@pytest.mark.parametrize(
    ("message", "expected"),
    [
        ("ciao", "Ciao! Sono qui per Rex"),
        ("Buongiorno!", "Ciao! Sono qui per Rex"),
        ("grazie mille", "Di niente!"),
        ("ok", "Perfetto."),
        ("chi sei?", "Sono l'assistente dell'app"),
        ("cosa sai fare", "Non faccio diagnosi e non do dosaggi"),
    ],
)
def test_small_talk_is_answered_by_fixed_text_without_the_model(
    message: str, expected: str
) -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = _ask(orchestrator, message)

    assert expected in result.answer  # type: ignore[attr-defined]
    assert result.mode == "general"  # type: ignore[attr-defined]
    assert result.ai_generated is False  # type: ignore[attr-defined]
    assert "veterinario" not in result.answer or "chi sei" in message or "sai" in message  # type: ignore[attr-defined]
    assert client.requests == []


def test_small_talk_is_not_counted_against_the_owners_allowance() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = LlmBudget(
        repository,
        budgets={"m": 1000},
        default_budget=1000,
        user_daily_limit=1,
        clock=lambda: NOON,
        refresh_seconds=3600.0,
    )
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        usage_budget=budget,
        answer_models=["m"],
    )

    for _ in range(3):
        assert _ask(orchestrator, "grazie!").mode == "general"  # type: ignore[attr-defined]
    assert _ask(orchestrator, "quante volte al giorno deve mangiare?").mode == "natural"  # type: ignore[attr-defined]
    assert repository.add_user_message("anna", NOON.date()) == 2


# --- cached questions carry no personal data -----------------------------------------


def test_a_question_with_the_owners_name_is_neither_cached_nor_stored() -> None:
    client = RecordingLLMClient()
    cache = InMemoryAnswerCacheRepository()
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), RuleBasedPiiAnonymizer(), answer_cache=cache
    )

    _ask(
        orchestrator,
        "Sono Mario Rossi, i cani possono mangiare le fragole?",
        owner_names=["Mario Rossi"],
    )
    _ask(
        orchestrator,
        "Sono Mario Rossi, i cani possono mangiare le fragole?",
        owner_names=["Mario Rossi"],
    )

    assert len(client.requests_for("answer")) == 2
    assert cache._items == {}  # noqa: SLF001 - the in-memory double's own store
    # The plain curiosity still is cached, and what is stored has no name.
    _ask(orchestrator, "i cani possono mangiare le fragole?", owner_names=["Mario Rossi"])
    [stored] = cache._items.values()  # noqa: SLF001
    assert stored.question == "i cani possono mangiare le fragole"
    assert "Mario" not in stored.question and "Mario" not in stored.answer


# --- retention ------------------------------------------------------------------------


def test_the_maintenance_job_deletes_what_has_aged_out() -> None:
    usage = InMemoryLlmUsageRepository()
    cache = InMemoryAnswerCacheRepository()
    today = NOON.date()
    for days_ago in (0, 89, 90, 200):
        usage.record(
            LlmUsageEvent(
                occurred_at=NOON - timedelta(days=days_ago),
                model="m",
                purpose="answer",
                total_tokens=10,
            )
        )
    usage.add_user_message("anna", today)
    usage.add_user_message("bruno", today - timedelta(days=31))
    for key, offset in (("fresh", +1), ("stale", -1)):
        cache.put(
            CachedAnswer(
                key=key,
                species="dog",
                question="q",
                answer="a",
                provider="p",
                model="m",
                expires_at=NOON + timedelta(hours=offset),
            )
        )

    output = ChatUsageMaintenanceService(usage, cache).run(NOON)

    assert output.deleted == {
        "llm_usage": 2,
        "chat_user_daily_usage": 1,
        "chat_answer_cache": 1,
    }
    assert {e.day for e in usage.events} == {today, today - timedelta(days=89)}
    assert usage.add_user_message("anna", today) == 2  # kept
    assert cache.get("fresh") is not None and cache.get("stale") is None
    # Idempotent.
    assert ChatUsageMaintenanceService(usage, cache).run(NOON).deleted == {
        "llm_usage": 0,
        "chat_user_daily_usage": 0,
        "chat_answer_cache": 0,
    }


def test_the_maintenance_route_is_for_developers_only(monkeypatch: pytest.MonkeyPatch) -> None:
    reset_container()
    try:
        client = TestClient(app)
        assert client.post("/chat/maintenance").status_code == 401

        container = get_container()
        email = container.auth_provider.get_current_user().email.strip().lower()
        monkeypatch.setattr(container, "developer_emails", frozenset({email}))
        response = client.post("/chat/maintenance")

        assert response.status_code == 200
        assert set(response.json()["deleted"]) >= {
            "llm_usage",
            "chat_user_daily_usage",
            "chat_answer_cache",
        }
    finally:
        reset_container()


def test_retention_defaults_match_the_sql_comment() -> None:
    from packages.core.application.services.maintain_chat_usage import (
        USAGE_RETENTION_DAYS,
        USER_COUNTER_RETENTION_DAYS,
    )

    assert (USAGE_RETENTION_DAYS, USER_COUNTER_RETENTION_DAYS) == (90, 30)
    assert isinstance(date.today(), date)
