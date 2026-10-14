"""Build 33: the light-model helpers and the literature search run side by
side; a chain of missing models fails at once; a reserve that is also the
light model goes last."""

from __future__ import annotations

import time
from typing import Any

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.domain.knowledge.models import EvidenceSource
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings

DELAY = 0.15
NORMAL = '{"level": "normal", "category": null}'
KEYWORDS = '{"keywords": ["dog", "lameness"]}'
QUESTION = "da due giorni zoppica dopo le passeggiate"


class SlowClient(RecordingLLMClient):
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        time.sleep(DELAY)
        return super().generate(request)


class SlowRetriever:
    def __init__(self) -> None:
        self.requests: list[EvidenceRetrievalRequest] = []

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        time.sleep(DELAY)
        self.requests.append(request)
        return [
            EvidenceSource(
                title="Zoppica dopo le passeggiate nel cane",
                species="dog",
                clinical_domain="clinical_question",
                snippet="zoppia passeggiate cane",
            )
        ]


def _orchestrator(client: RecordingLLMClient, retriever: Any) -> ChatOrchestrator:
    return ChatOrchestrator(
        client,
        retriever,
        NoopPiiAnonymizer(),
        urgency_classifier=UrgencyClassifier(client),
        evidence_query_normalizer=EvidenceQueryNormalizer(client),
    )


def _ask(orchestrator: ChatOrchestrator, text: str = QUESTION) -> Any:
    return orchestrator.answer(
        ChatOrchestratorInput(user_message=text, species="Cane", pet_name="Rex")
    )


def test_the_helpers_and_the_search_overlap_instead_of_queueing() -> None:
    client = SlowClient(by_purpose={"urgency_classifier": NORMAL, "evidence_query": KEYWORDS})
    retriever = SlowRetriever()
    orchestrator = _orchestrator(client, retriever)

    started = time.perf_counter()
    result = _ask(orchestrator)
    wall = time.perf_counter() - started

    # Four waits of DELAY (classifier, keywords, retrieval, answer): in series
    # that is 4 x DELAY; overlapped, the classifier runs beside keywords +
    # retrieval, then the answer: about 3 x DELAY.
    assert wall < 3.6 * DELAY, wall
    assert result.mode == "natural"
    assert len(result.sources) == 1
    assert [r.purpose for r in client.requests].count("evidence_query") == 1
    assert len(retriever.requests) == 1  # the prefetched search is the one used
    assert retriever.requests[0].query == "dog lameness"


def test_an_emergency_verdict_still_wins_and_no_answer_is_generated() -> None:
    client = SlowClient(
        by_purpose={
            "urgency_classifier": '{"level": "emergency", "category": "toxin_medication"}',
            "evidence_query": KEYWORDS,
        }
    )
    orchestrator = _orchestrator(client, SlowRetriever())

    result = _ask(orchestrator, "ha leccato il liquido blu colato dalla macchina")

    assert result.mode == "triage"
    assert client.requests_for("answer") == []


def test_a_failing_helper_thread_never_costs_the_answer() -> None:
    client = SlowClient(
        by_purpose={"urgency_classifier": RuntimeError("boom"), "evidence_query": KEYWORDS}
    )
    orchestrator = _orchestrator(client, SlowRetriever())

    result = _ask(orchestrator)

    assert result.mode == "natural"


def test_small_talk_and_fixed_replies_start_no_helper_at_all() -> None:
    client = SlowClient(by_purpose={"urgency_classifier": NORMAL, "evidence_query": KEYWORDS})
    retriever = SlowRetriever()
    orchestrator = _orchestrator(client, retriever)

    _ask(orchestrator, "grazie!")
    _ask(orchestrator, "ha mangiato del veleno per topi")

    assert client.requests == []
    assert retriever.requests == []


# --- the provider side -----------------------------------------------------------------


def _settings(**overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "llm_provider": "groq",
        "llm_model": "openai/gpt-oss-120b",
        "llm_api_key": "test-key",
        "llm_fallback_models": "openai/gpt-oss-20b,qwen/qwen3.8-27b",
        "llm_model_light": "openai/gpt-oss-20b",
        "llm_light_fallback_models": "qwen/qwen3.8-27b",
        **overrides,
    }
    return Settings().model_copy(update=values)


def test_a_reserve_that_is_also_the_light_model_goes_last() -> None:
    client = GroqLLMClient(_settings(), transport=lambda *_: {})

    assert client.main_models == ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"]
    assert client.light_models == ["openai/gpt-oss-20b", "qwen/qwen3.8-27b"]
    # Without a light model the configured order is kept as it is.
    plain = GroqLLMClient(_settings(llm_model_light=""), transport=lambda *_: {})
    assert plain.main_models == ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"]
