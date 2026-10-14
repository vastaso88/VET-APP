"""Build 32: a general curiosity about a kind of animal shares its answer
for a day; anything about this animal is answered fresh (answer_cache.py,
ChatOrchestrator)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.answer_cache_repository import CachedAnswer
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.answer_cache import (
    cache_key,
    is_cacheable_question,
    normalize_question,
)
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.request_kind import RequestKind, classify_request
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

CURIOSITY = "I cani possono mangiare le fragole?"


def _cacheable(text: str, **kw: object) -> bool:
    options = {"pet_name": "Rex", "has_attachment": False, "has_history": False, **kw}
    return is_cacheable_question(text, kind=classify_request(text), **options)  # type: ignore[arg-type]


def test_normalization_ignores_case_accents_punctuation_and_fillers() -> None:
    assert normalize_question("Ciao! I cani possono mangiare le fragole?") == (
        "i cani possono mangiare le fragole"
    )
    assert (
        normalize_question("  Perché  i gatti FANNO le fusa?! ") == "perche i gatti fanno le fusa"
    )
    assert cache_key("I cani possono mangiare le fragole?", species="dog", language="it") == (
        cache_key("ciao, i cani possono mangiare le fragole", species="dog", language="it")
    )
    assert cache_key(CURIOSITY, species="dog", language="it") != cache_key(
        CURIOSITY, species="cat", language="it"
    )


def test_only_a_general_first_question_is_cacheable() -> None:
    assert _cacheable(CURIOSITY)
    assert _cacheable("quanto vive un criceto?")
    # About this animal, this moment, or a personal case: never.
    assert not _cacheable("il mio cane può mangiare le fragole?")
    assert not _cacheable("Rex può mangiare le fragole?")
    assert not _cacheable("può mangiare le fragole a 3 mesi?")
    assert not _cacheable("da ieri vomita, cosa faccio?")
    assert not _cacheable(CURIOSITY, has_history=True)
    assert not _cacheable(CURIOSITY, has_attachment=True)
    assert not is_cacheable_question(
        CURIOSITY, kind=RequestKind.SYMPTOM, pet_name="Rex", has_attachment=False, has_history=False
    )


def _orchestrator(
    client: RecordingLLMClient, cache: InMemoryAnswerCacheRepository
) -> ChatOrchestrator:
    return ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_cache=cache
    )


def _ask(
    orchestrator: ChatOrchestrator,
    text: str,
    *,
    species: str = "Cane",
    pet_name: str = "Rex",
    history: list[ChatMessage] | None = None,
) -> object:
    return orchestrator.answer(
        ChatOrchestratorInput(
            user_message=text,
            species=species,
            pet_name=pet_name,
            age_years=3,
            notes="allergico al pollo",
            conversation_history=history or [],
        )
    )


def test_the_same_curiosity_from_another_owner_is_served_without_the_model() -> None:
    client = RecordingLLMClient("Sì, qualche fragola ogni tanto va benissimo.")
    cache = InMemoryAnswerCacheRepository()
    orchestrator = _orchestrator(client, cache)

    first = _ask(orchestrator, CURIOSITY, pet_name="Rex")
    second = _ask(orchestrator, "ciao, i cani possono mangiare le fragole?", pet_name="Fido")

    assert len(client.requests_for("answer")) == 1
    assert second.answer == first.answer  # type: ignore[attr-defined]
    assert second.ai_generated is True and second.provider == "fake"  # type: ignore[attr-defined]
    assert second.mode == "natural"  # type: ignore[attr-defined]


def test_a_cacheable_question_is_answered_without_the_pets_own_data() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, InMemoryAnswerCacheRepository())

    _ask(orchestrator, CURIOSITY)

    prompt = client.requests_for("answer")[0].user_prompt
    assert "Species: Cane" in prompt
    assert "Rex" not in prompt and "Pet name" not in prompt
    assert "allergico" not in prompt and "Age:" not in prompt


def test_another_species_or_a_personal_question_is_answered_fresh() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, InMemoryAnswerCacheRepository())

    _ask(orchestrator, CURIOSITY, species="Cane")
    _ask(orchestrator, "I gatti possono mangiare le fragole?", species="Gatto")
    _ask(orchestrator, "il mio cane può mangiare le fragole?")
    _ask(orchestrator, "il mio cane può mangiare le fragole?")

    assert len(client.requests_for("answer")) == 4
    personal = client.requests_for("answer")[-1].user_prompt
    assert "Rex" in personal and "allergico" in personal


def test_a_follow_up_is_never_served_from_the_cache() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, InMemoryAnswerCacheRepository())
    history = [
        ChatMessage(role="user", content="da ieri vomita"),
        ChatMessage(role="assistant", content="Quante volte?"),
    ]

    _ask(orchestrator, CURIOSITY)
    _ask(orchestrator, CURIOSITY, history=history)

    assert len(client.requests_for("answer")) == 2


def test_an_expired_answer_is_regenerated() -> None:
    client = RecordingLLMClient("Risposta nuova.")
    cache = InMemoryAnswerCacheRepository()
    key = cache_key(CURIOSITY, species="dog", language="it")
    cache.put(
        CachedAnswer(
            key=key,
            species="dog",
            question=normalize_question(CURIOSITY),
            answer="Risposta vecchia.",
            provider="fake",
            model="old",
            expires_at=datetime.now(UTC) - timedelta(minutes=1),
        )
    )

    result = _ask(_orchestrator(client, cache), CURIOSITY)

    assert result.answer == "Risposta nuova."  # type: ignore[attr-defined]
    assert cache.get(key).answer == "Risposta nuova."  # type: ignore[union-attr]
