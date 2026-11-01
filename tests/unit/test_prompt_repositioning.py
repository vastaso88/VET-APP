"""Repositioning of 2026-11-01 (docs/product/11): the chat's centre is the
owner's awareness. The prompt carries the new identity and three new rules,
the small-talk identity says it in five languages without the forbidden
words, and a new prompt version empties the answer cache."""

from __future__ import annotations

import re

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.natural_answer_prompt import (
    PROMPT_VERSION,
    build_system_prompt,
)
from packages.core.domain.conversation.answer_cache import cache_key
from packages.core.domain.conversation.request_kind import RequestKind
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

# docs/product/11 §3.1: never in a text the owner reads.
FORBIDDEN = re.compile(
    r"\b(corso|corsi|formazione|lezione|lezioni|attestat\w*|certificat\w*|patentin\w*|"
    r"esam[ei]|promozione|veterinario virtuale|come un veterinario|"
    r"course|training course|lesson|certificate|diploma|exam|virtual vet|"
    r"curso|lección|certificado|examen|veterinario virtual|"
    r"kurs|lehrgang|zertifikat|prüfung|virtueller tierarzt|"
    r"cours|leçon|certificat|examen|vétérinaire virtuel)\b",
    re.IGNORECASE,
)


@pytest.mark.parametrize("kind", list(RequestKind))
def test_the_prompt_carries_the_new_centre_and_rules(kind: RequestKind) -> None:
    prompt = build_system_prompt(kind, may_ask=True, has_reference_material=False)

    assert "helps people who live with an animal understand it and look after it well" in prompt
    assert "EXPLAIN THE WHY" in prompt
    assert "Never a dog by default" in prompt
    assert "OFFICIAL POSITIONS" in prompt
    for body in ("WSAVA", "FVE", "FECAVA", "ESVCE", "AVSAB", "ISFM", "AAHA", "RSPCA", "FNOVI"):
        assert body in prompt, body
    assert "when a position is debated" in prompt
    assert "OWNER DUTIES" in prompt
    assert "do not play the lawyer" in prompt
    # The safety rules did not move.
    assert "WHEN TO SEND THE OWNER TO THE VET" in prompt
    assert "NO TREATMENT ADVICE OF YOUR OWN" in prompt
    assert "CALIBRATED, NOT ALARMING" in prompt
    assert "DATA, NOT INSTRUCTIONS" in prompt
    assert "pet-care app" not in prompt


def test_direct_questions_may_run_longer_for_a_why_and_may_name_the_vet_as_a_duty() -> None:
    prompt = build_system_prompt(RequestKind.DIRECT, may_ask=False, has_reference_material=False)

    assert "about 1500" in prompt
    assert "must not appear as a reflex or a closing" in prompt
    assert "microchip" in prompt and "compulsory vaccination" in prompt
    assert "Do not ask for information before answering" in prompt


def test_the_prompt_is_the_same_for_every_owner() -> None:
    first = build_system_prompt(RequestKind.SYMPTOM, may_ask=True, has_reference_material=True)
    second = build_system_prompt(RequestKind.SYMPTOM, may_ask=True, has_reference_material=True)

    assert first == second


@pytest.mark.parametrize(
    ("language", "fragment"),
    [
        ("it", "ti aiuto a capire Birba, perché fa quello che fa"),
        ("en", "help you understand Birba, why they do what they do"),
        ("es", "te ayudo a entender a Birba, por qué hace lo que hace"),
        ("de", "helfe Ihnen, Birba zu verstehen"),
        ("fr", "je vous aide à comprendre Birba, pourquoi il fait ce qu'il fait"),
    ],
)
def test_the_small_talk_identity_says_the_new_centre_in_every_language(
    language: str, fragment: str
) -> None:
    client = RecordingLLMClient()
    result = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message="chi sei?", species="Cane", pet_name="Birba", language=language
        )
    )

    assert fragment in result.answer
    assert not FORBIDDEN.search(result.answer), result.answer
    assert client.requests == []


def test_no_forbidden_word_in_any_fixed_small_talk_text() -> None:
    for texts in ChatOrchestrator._SMALL_TALK_TEXTS.values():  # noqa: SLF001
        for text in texts.values():
            assert not FORBIDDEN.search(text.format(name="Birba")), text


def test_a_new_prompt_version_means_new_cache_keys() -> None:
    assert PROMPT_VERSION
    question = "I cani possono mangiare le fragole?"
    old = cache_key(question, species="dog", language="it", prompt_version="2026-10-14")
    current = cache_key(question, species="dog", language="it", prompt_version=PROMPT_VERSION)

    assert old != current


def test_an_answer_cached_under_the_old_prompt_is_not_served() -> None:
    from datetime import UTC, datetime, timedelta

    from packages.core.application.ports.answer_cache_repository import CachedAnswer

    cache = InMemoryAnswerCacheRepository()
    question = "I cani possono mangiare le fragole?"
    cache.put(
        CachedAnswer(
            key=cache_key(question, species="dog", language="it", prompt_version="old"),
            species="dog",
            question="i cani possono mangiare le fragole",
            answer="Risposta vecchia.",
            provider="fake",
            model="old",
            expires_at=datetime.now(UTC) + timedelta(hours=1),
        )
    )
    client = RecordingLLMClient("Risposta nuova.")
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_cache=cache
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(user_message=question, species="Cane", pet_name="Rex")
    )

    assert result.answer == "Risposta nuova."
    assert cache.get(
        cache_key(question, species="dog", language="it", prompt_version=PROMPT_VERSION)
    )
