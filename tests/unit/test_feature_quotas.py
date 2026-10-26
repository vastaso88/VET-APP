"""Security audit BE-4/LLM-4: photo readings, dictation and vet summaries
have a per-owner daily allowance on the same ledger as the messages, and
the owner is told clearly, in their language, when it is used up."""

from __future__ import annotations

import io
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from llm_fakes import RecordingLLMClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.services.llm_budget import LlmBudget, format_wait
from packages.core.application.services.transcribe_audio import (
    TranscribeAudioInput,
    TranscribeAudioService,
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


class _Transcriber:
    def __init__(self) -> None:
        self.calls = 0

    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str:
        self.calls += 1
        return "testo dettato"


def _budget() -> LlmBudget:
    return LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={},
        default_budget=1_000_000,
        clock=lambda: NOON,
        refresh_seconds=3600.0,
    )


def _audio(
    owner: str = "anna", *, quota_exempt: bool = False, language: str = "it"
) -> TranscribeAudioInput:
    return TranscribeAudioInput(
        audio_bytes=b"RIFF",
        filename="a.wav",
        content_type="audio/wav",
        owner_id=owner,
        quota_exempt=quota_exempt,
        language=language,
    )


def test_dictation_stops_at_the_daily_allowance_with_a_clear_message() -> None:
    transcriber = _Transcriber()
    service = TranscribeAudioService(transcriber, budget=_budget(), daily_limit=2)

    service.execute(_audio())
    service.execute(_audio())
    with pytest.raises(QuotaExceededError) as raised:
        service.execute(_audio())

    assert transcriber.calls == 2
    assert raised.value.kind == "dictation" and raised.value.limit == 2
    assert "2 dettature" in raised.value.message
    assert "12 ore" in raised.value.message
    assert raised.value.retry_after_seconds == 12 * 3600


def test_the_refusal_speaks_the_owners_language_and_exempt_accounts_are_not_counted() -> None:
    transcriber = _Transcriber()
    service = TranscribeAudioService(transcriber, budget=_budget(), daily_limit=1)

    service.execute(_audio(language="de"))
    with pytest.raises(QuotaExceededError) as raised:
        service.execute(_audio(language="de"))
    assert "Diktate" in raised.value.message and "12 Stunden" in raised.value.message

    for _ in range(3):
        service.execute(_audio(quota_exempt=True))
    # Another owner has an allowance of their own.
    service.execute(_audio(owner="bruno"))
    assert transcriber.calls == 5


def test_each_feature_has_its_own_counter() -> None:
    budget = _budget()
    dictation = TranscribeAudioService(_Transcriber(), budget=budget, daily_limit=1)
    conversations = InMemoryConversationRepository()
    conversations.save(
        Conversation(
            id="c1",
            owner_id="anna",
            pet_id="p1",
            title="t",
            messages=[ChatMessage(role="user", content="ciao")],
        )
    )
    summaries = VetSummaryService(
        conversations,
        InMemoryPetProfileRepository(),
        RecordingLLMClient("Riassunto."),
        NoopPiiAnonymizer(),
        budget=budget,
        daily_limit=1,
    )

    dictation.execute(_audio())
    summaries.execute(VetSummaryInput(owner_id="anna", conversation_id="c1"))  # still allowed
    with pytest.raises(QuotaExceededError) as raised:
        summaries.execute(VetSummaryInput(owner_id="anna", conversation_id="c1"))

    assert raised.value.kind == "summary"
    assert "riassunti" in raised.value.message


def test_no_limit_or_no_budget_means_no_refusal() -> None:
    transcriber = _Transcriber()
    for service in (
        TranscribeAudioService(transcriber, budget=_budget(), daily_limit=0),
        TranscribeAudioService(transcriber),
    ):
        for _ in range(5):
            service.execute(_audio())
    assert transcriber.calls == 10


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
            container.settings, "chat_daily_dictation_limit_per_user", 1, raising=False
        )
        monkeypatch.setattr(container, "developer_emails", frozenset())
        # The bootstrap provider is the demo echo; the service goes through
        # the container's budget with the patched limit.
        monkeypatch.setattr(
            type(container.speech_to_text_provider),
            "transcribe",
            lambda self, *a, **k: "testo",
            raising=False,
        )

        def upload() -> Any:
            return client.post(
                "/speech-to-text",
                files={"file": ("a.wav", io.BytesIO(b"RIFF" * 10), "audio/wav")},
                headers={"Accept-Language": "en"},
            )

        first = upload()
        second = upload()

        assert first.status_code == 200, first.text
        assert second.status_code == 429, second.text
        body = second.json()
        assert body["code"] == "quota_exceeded" and body["kind"] == "dictation"
        assert body["detail"].startswith("quota_exceeded: ")
        assert "dictations available today" in body["detail"]
        assert int(second.headers["Retry-After"]) >= 60
    finally:
        reset_container()
