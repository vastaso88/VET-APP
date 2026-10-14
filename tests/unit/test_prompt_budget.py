"""Build 32: fewer tokens per answer — a compact, stable system prompt,
two short sources at most, a bounded history, a calibrated reply budget,
English keywords for the literature search."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.knowledge.models import EvidenceSource
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError

# Before build 32 the longest variant was about 7700 characters (1750
# tokens on the o200k tokenizer); the ceiling leaves room for a rule or
# two, not for drifting back.
SYSTEM_PROMPT_MAX_CHARS = 6400
QUESTION = "da due giorni zoppica dopo le passeggiate"


class FakeRetriever:
    def __init__(self, sources: list[EvidenceSource]) -> None:
        self.sources = sources
        self.requests: list[EvidenceRetrievalRequest] = []

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.requests.append(request)
        return list(self.sources)


def _source(index: int) -> EvidenceSource:
    return EvidenceSource(
        title=f"Zoppica dopo le passeggiate nel cane: studio {index}",
        journal="Journal of Test Veterinary Science",
        year=2024,
        tier="B",
        species="dog",
        clinical_domain="clinical_question",
        snippet=("zoppia passeggiate " * 60).strip(),
    )


def _ask(orchestrator: ChatOrchestrator, text: str, **kw: object) -> object:
    fields: dict[str, object] = {"species": "Cane", "pet_name": "Rex", **kw}
    return orchestrator.answer(ChatOrchestratorInput(user_message=text, **fields))  # type: ignore[arg-type]


def test_the_system_prompt_stays_under_its_size_ceiling() -> None:
    for kind in RequestKind:
        for may_ask in (True, False):
            prompt = build_system_prompt(kind, may_ask=may_ask, has_reference_material=True)
            assert len(prompt) <= SYSTEM_PROMPT_MAX_CHARS, (kind, may_ask, len(prompt))


def test_the_system_prompt_is_identical_between_owners_so_the_provider_can_cache_it() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    _ask(orchestrator, QUESTION, age_years=2, weight_label="12 kg")
    _ask(orchestrator, QUESTION, pet_name="Luna", age_years=9, notes="artrosi")

    first, second = client.requests_for("answer")
    assert first.system_prompt == second.system_prompt
    assert first.user_prompt != second.user_prompt
    # What varies lives in the user message, after the stable prefix.
    assert "Luna" in second.user_prompt and "artrosi" in second.user_prompt


def test_at_most_two_sources_go_into_the_prompt_with_short_snippets() -> None:
    client = RecordingLLMClient()
    retriever = FakeRetriever([_source(i) for i in range(1, 5)])
    orchestrator = ChatOrchestrator(
        client, retriever, NoopPiiAnonymizer(), prompt_max_sources=2, prompt_source_chars=120
    )

    result = _ask(orchestrator, QUESTION)

    prompt = client.requests_for("answer")[0].user_prompt
    assert "[1]" in prompt and "[2]" in prompt and "[3]" not in prompt
    snippet_lines = [line for line in prompt.splitlines() if line.startswith("Snippet:")]
    assert len(snippet_lines) == 2
    assert all(len(line) <= len("Snippet: ") + 120 for line in snippet_lines)
    assert all(line.endswith("...") for line in snippet_lines)
    assert len(result.sources) == 2  # type: ignore[attr-defined]


def test_a_long_history_is_sent_as_recent_turns_plus_a_line_of_older_topics() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        history_recent_messages=4,
        history_message_chars=100,
    )
    history: list[ChatMessage] = []
    for turn in range(1, 6):
        history.append(ChatMessage(role="user", content=f"domanda numero {turn} " * 20))
        history.append(ChatMessage(role="assistant", content=f"risposta numero {turn} " * 20))

    _ask(orchestrator, "e per le scale?", conversation_history=history)

    prompt = client.requests_for("answer")[0].user_prompt
    assert "Earlier topics in this conversation: domanda numero 1" in prompt
    assert "domanda numero 3" in prompt.split("Earlier in this conversation:")[0]
    recent = prompt.split("Earlier in this conversation:")[1]
    assert "risposta numero 4" in recent and "risposta numero 5" in recent
    assert "risposta numero 3" not in recent
    # Each recent message cut at the configured length.
    for line in recent.splitlines():
        if line.startswith(("user:", "assistant:")):
            assert len(line) <= len("assistant: ") + 100
    assert ("domanda numero 1 " * 20).strip() not in prompt


def test_the_reply_budget_is_calibrated_per_kind_of_request() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    _ask(orchestrator, QUESTION)
    _ask(orchestrator, "grazie!")  # small talk: fixed text, no call at all (build 33)

    [answer] = client.requests_for("answer")
    assert answer.max_tokens == 450
    assert client.requests_for("general_answer") == []

    custom = RecordingLLMClient()
    ChatOrchestrator(
        custom, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_max_tokens=200
    ).answer(ChatOrchestratorInput(user_message=QUESTION, species="Cane", pet_name="Rex"))
    assert custom.requests_for("answer")[0].max_tokens == 200


def test_the_literature_is_searched_with_english_keywords_from_the_light_model() -> None:
    client = RecordingLLMClient(
        by_purpose={"evidence_query": '{"keywords": ["dog", "lameness", "hind limb", "dog"]}'}
    )
    retriever = FakeRetriever([])
    orchestrator = ChatOrchestrator(
        client,
        retriever,
        NoopPiiAnonymizer(),
        evidence_query_normalizer=EvidenceQueryNormalizer(client),
    )

    _ask(orchestrator, QUESTION)

    assert retriever.requests[0].query == "dog lameness hind limb"
    [request] = client.requests_for("evidence_query")
    assert request.model_class == "light" and request.json_mode is True


def test_without_keywords_the_owners_words_are_the_query() -> None:
    for outcome in (ProviderError("down"), "nonsense", '{"keywords": []}'):
        client = RecordingLLMClient(by_purpose={"evidence_query": outcome})
        retriever = FakeRetriever([])
        orchestrator = ChatOrchestrator(
            client,
            retriever,
            NoopPiiAnonymizer(),
            evidence_query_normalizer=EvidenceQueryNormalizer(client),
        )

        _ask(orchestrator, QUESTION)

        assert retriever.requests[0].query == QUESTION
