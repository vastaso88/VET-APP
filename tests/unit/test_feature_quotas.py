"""Security audit BE-4/LLM-4: photo readings and vet summaries have a
per-owner daily allowance on the same ledger as the messages, and the owner
is told clearly, in their language, when it is used up."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.services.llm_budget import (
    LlmBudget,
    format_wait,
    require_feature_allowance,
)
from packages.core.application.services.vet_summary import VetSummaryInput, VetSummaryService
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import QuotaExceededError

NOON = datetime(2026, 10, 26, 12, 0, tzinfo=UTC)


def _budget() -> LlmBudget:
    return LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={},
        default_budget=1_000_000,
        clock=lambda: NOON,
        refresh_seconds=3600.0,
    )


def _summaries(
    budget: LlmBudget | None, daily_limit: int = 0
) -> tuple[VetSummaryService, RecordingLLMClient]:
    conversations = InMemoryConversationRepository()
    for owner in ("anna", "bruno"):
        conversations.save(
            Conversation(
                id=f"chat-of-{owner}",
                owner_id=owner,
                pet_id="p1",
                title="t",
                messages=[ChatMessage(role="user", content="ciao")],
            )
        )
    client = RecordingLLMClient("Riassunto.")
    service = VetSummaryService(
        conversations,
        InMemoryPetProfileRepository(),
        client,
        NoopPiiAnonymizer(),
        budget=budget,
        daily_limit=daily_limit,
    )
    return service, client


def _request(
    owner: str = "anna", *, quota_exempt: bool = False, language: str = "it"
) -> VetSummaryInput:
    return VetSummaryInput(
        owner_id=owner,
        conversation_id=f"chat-of-{owner}",
        quota_exempt=quota_exempt,
        language=language,
    )


def test_a_feature_stops_at_the_daily_allowance_with_a_clear_message() -> None:
    service, client = _summaries(_budget(), 2)

    service.execute(_request())
    service.execute(_request())
    with pytest.raises(QuotaExceededError) as raised:
        service.execute(_request())

    assert len(client.requests) == 2
    assert raised.value.kind == "summary" and raised.value.limit == 2
    assert "2 riassunti" in raised.value.message
    assert "12 ore" in raised.value.message
    assert raised.value.retry_after_seconds == 12 * 3600


def test_the_refusal_speaks_the_owners_language_and_exempt_accounts_are_not_counted() -> None:
    service, client = _summaries(_budget(), 1)

    service.execute(_request(language="de"))
    with pytest.raises(QuotaExceededError) as raised:
        service.execute(_request(language="de"))
    assert "Zusammenfassungen" in raised.value.message and "12 Stunden" in raised.value.message

    for _ in range(3):
        service.execute(_request(quota_exempt=True))
    # Another owner has an allowance of their own.
    service.execute(_request(owner="bruno"))
    assert len(client.requests) == 5


def test_each_feature_has_its_own_counter() -> None:
    budget = _budget()
    service, _ = _summaries(budget, 1)

    require_feature_allowance(budget, owner_id="anna", kind="vision", limit=1)
    service.execute(_request())  # still allowed
    with pytest.raises(QuotaExceededError) as raised:
        service.execute(_request())

    assert raised.value.kind == "summary"
    assert "riassunti" in raised.value.message
    with pytest.raises(QuotaExceededError) as photos:
        require_feature_allowance(budget, owner_id="anna", kind="vision", limit=1)
    assert photos.value.kind == "vision"


def test_no_limit_or_no_budget_means_no_refusal() -> None:
    for budget in (_budget(), None):
        service, client = _summaries(budget, 0)
        for _ in range(5):
            service.execute(_request())
        assert len(client.requests) == 5


def test_waits_are_worded_per_language() -> None:
    assert format_wait(90, "en") == "a few minutes"
    assert format_wait(20 * 60, "es") == "20 minutos"
    assert format_wait(2 * 3600, "fr") == "2 heures"
    assert format_wait(3600 + 20 * 60, "de") == "1 Stunde und 20 Minuten"
    assert format_wait(3600, "xx") == "1 ora"


def test_the_api_answers_429_with_the_message_and_a_retry_header(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    reset_container()
    try:
        client = TestClient(app)
        container = get_container()
        monkeypatch.setattr(
            container.settings, "chat_daily_summary_limit_per_user", 1, raising=False
        )
        monkeypatch.setattr(container, "developer_emails", frozenset())
        pet = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()["pet_profile"]
        asked = client.post("/chat", json={"pet_id": pet["id"], "user_message": "Mangia poco"})
        conversation_id = asked.json()["conversation"]["id"]

        def summary() -> Any:
            return client.get(
                f"/conversations/{conversation_id}/summary", headers={"Accept-Language": "en"}
            )

        first = summary()
        second = summary()

        assert first.status_code == 200, first.text
        assert second.status_code == 429, second.text
        body = second.json()
        assert body["code"] == "quota_exceeded" and body["kind"] == "summary"
        assert body["detail"].startswith("quota_exceeded: ")
        assert "vet summaries available today" in body["detail"]
        assert int(second.headers["Retry-After"]) >= 60
    finally:
        reset_container()
