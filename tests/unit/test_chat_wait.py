"""The owner waits 20 seconds at most (owner's rule), whoever is mute (25/11/2026: with Claude
mute a turn could take sixty, 30 seconds for each of two tries).

The clock is a stand-in: a mute model lets the whole deadline of its call go by, then fails.
"""

from __future__ import annotations

import threading
import time
from types import SimpleNamespace
from typing import Any

import pytest

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services import chat_orchestrator as orchestrator_module
from packages.core.application.services import finished_text as finished_text_module
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.finished_text import generate_finished_lines
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.localization import translate
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError

LANGUAGES = ("it", "en", "es", "de", "fr")
# The classifier runs beside the turn: its own six seconds are part of the wait.
MUTE_LIMIT = 19.0


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0
        self._lock = threading.Lock()

    def monotonic(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        with self._lock:
            self.now += seconds


class MuteModel:
    """Never answers: every call takes its whole deadline, and one is always set."""

    def __init__(self, clock: Clock, *, mute: tuple[str, ...] = ()) -> None:
        self.clock = clock
        self.mute = mute
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        assert request.timeout_seconds is not None, f"{request.purpose}: no deadline"
        if not self.mute or request.purpose in self.mute:
            self.clock.advance(request.timeout_seconds)
            raise ProviderError("Anthropic request timed out")
        self.clock.advance(1)
        return LLMResponse(
            content="Spazzolalo due volte a settimana, con calma, e guarda la pelle.",
            provider="fake",
            model="fake",
            token_count=1,
        )


@pytest.fixture
def clock(monkeypatch: pytest.MonkeyPatch) -> Clock:
    clock = Clock()
    fake = SimpleNamespace(monotonic=clock.monotonic)
    monkeypatch.setattr(orchestrator_module, "time", fake)
    monkeypatch.setattr(finished_text_module, "time", fake)
    return clock


def _ask(
    client: Any, message: str, *, classifier: bool = True, v2: bool = True, **extra: Any
) -> ChatOrchestratorResult:
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        answer_v2=v2,
        urgency_classifier=(
            UrgencyClassifier(client, timeout_seconds=6) if classifier else None  # type: ignore[arg-type]
        ),
        urgent_answer_timeout_seconds=12,
    )
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species="Cane", pet_name="Rex", **extra)
    )


@pytest.mark.parametrize("v2", [True, False])
@pytest.mark.parametrize(
    "message",
    [
        "ogni quanto va spazzolato?",
        "zoppica da due giorni dalla zampa dietro, cosa faccio?",
        "ha la pancia gonfia e dura, prova a vomitare e non esce niente",
        "quante gocce di tachipirina gli do?",
        "ha mangiato un topicida dieci minuti fa",
    ],
)
def test_with_claude_mute_the_owner_waits_nineteen_seconds_at_most(
    clock: Clock, message: str, v2: bool
) -> None:
    started = clock.now
    result = _ask(MuteModel(clock), message, v2=v2)
    assert result.answer.strip()
    assert clock.now - started <= MUTE_LIMIT + 0.01


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_sentence_is_the_one_of_the_owners_language(clock: Clock, language: str) -> None:
    result = _ask(MuteModel(clock), "ogni quanto va spazzolato?", language=language)
    assert result.answer == translate("provider_failure", language)
    assert not result.ai_generated


def test_only_the_classifier_mute_costs_its_own_time_and_the_answer_comes(clock: Clock) -> None:
    started = clock.now
    client = MuteModel(clock, mute=("urgency_classifier",))
    result = _ask(client, "ogni quanto va spazzolato?")
    assert "due volte a settimana" in result.answer
    assert clock.now - started <= MUTE_LIMIT


def test_the_time_before_the_turn_is_part_of_the_wait(clock: Clock) -> None:
    client = MuteModel(clock)
    _ask(client, "ogni quanto va spazzolato?", classifier=False, turn_started_at=clock.now - 10)
    (answer,) = [r for r in client.requests if r.purpose == "answer"]
    # 19 - 10 seconds already gone - 3 for the checks
    assert answer.timeout_seconds == 6


def test_a_turn_with_no_time_left_starts_no_call(clock: Clock) -> None:
    client = MuteModel(clock)
    result = _ask(
        client, "ogni quanto va spazzolato?", classifier=False, turn_started_at=clock.now - 30
    )
    assert client.requests == []
    assert result.answer == translate("provider_failure", "it")


def test_the_answer_may_try_again_inside_its_deadline(clock: Clock) -> None:
    client = MuteModel(clock)
    _ask(client, "ogni quanto va spazzolato?", classifier=False)
    (answer,) = [r for r in client.requests if r.purpose == "answer"]
    assert answer.second_attempt and answer.timeout_seconds == 16


class SlowLibrary:
    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        time.sleep(1.0)
        return []


def test_a_slow_literature_search_is_left_behind(monkeypatch: pytest.MonkeyPatch) -> None:
    # what is kept for the answer leaves the helpers a tenth of a second
    monkeypatch.setattr(orchestrator_module, "_SECONDS_FOR_THE_ANSWER", 18.9)

    class Quick:
        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            return LLMResponse(
                content="Spazzolalo due volte a settimana, con calma, e guarda la pelle.",
                provider="fake",
                model="fake",
                token_count=1,
            )

    orchestrator = ChatOrchestrator(Quick(), SlowLibrary(), NoopPiiAnonymizer(), answer_v2=True)  # type: ignore[arg-type]
    started = time.monotonic()
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="ogni quanto va spazzolato?", species="Cane", pet_name="Rex"
        )
    )
    assert "due volte a settimana" in result.answer
    assert time.monotonic() - started < 0.9


def test_a_summary_cut_with_no_time_left_is_closed_and_not_written_again(clock: Clock) -> None:
    class Cut:
        calls = 0

        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            self.calls += 1
            clock.advance(17)
            return LLMResponse(
                content="## Motivo\n- zoppica\n- pes",
                provider="fake",
                model="fake",
                token_count=1,
                finish_reason="length",
            )

    client = Cut()
    text = generate_finished_lines(
        client, LLMGenerationRequest(system_prompt="s", user_prompt="u", timeout_seconds=19)
    )
    assert client.calls == 1 and text.endswith("zoppica")
