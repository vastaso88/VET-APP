"""Stress test of the Italian triage (2026-10-14): realistic phrasings of five
emergencies and of dose requests must take the fixed rule-based path, and
ordinary messages must not. Deterministic, no model calls."""

import pytest
from safety_phrasings import DOSAGE, EMERGENCIES, ORDINARY
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.domain.safety.dosage_request import is_dosage_request
from packages.core.domain.safety.emergency_patterns import (
    emergency_flags,
    normalize_for_matching,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

_EMERGENCY_CASES = [
    pytest.param(species, message, id=f"{name}: {message}")
    for name, cases in EMERGENCIES.items()
    for species, message in cases
]


def _answer(species: str, message: str) -> tuple[ChatOrchestratorResult, ScriptedContentLLMClient]:
    client = ScriptedContentLLMClient("risposta del modello")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name="Birba")
    )
    return result, client


@pytest.mark.parametrize(("species", "message"), _EMERGENCY_CASES)
def test_every_phrasing_of_an_emergency_gets_the_fixed_emergency_text(
    species: str, message: str
) -> None:
    result, client = _answer(species, message)

    assert result.mode == "triage", result.answer
    assert "contatta subito il tuo veterinario" in result.answer
    assert not result.ai_generated
    assert client.requests == []


def test_poisons_get_the_substance_opening_and_body_signs_the_symptom_one() -> None:
    poison, _ = _answer("Cane", "ha mangiato il veleno per topi")
    bloat, _ = _answer("Cane", "credo abbia una torsione gastrica")

    assert poison.answer.startswith("Meglio non rischiare: quello di cui mi parli")
    assert bloat.answer.startswith("Hai fatto bene a scrivermi subito.")


@pytest.mark.parametrize(("species", "message"), DOSAGE)
def test_every_dose_request_is_stopped_before_the_model(species: str, message: str) -> None:
    result, client = _answer(species, message)

    assert result.model in ("dosage-guard", "safety-triage-guard"), result.answer
    assert client.requests == []


@pytest.mark.parametrize(("species", "message"), ORDINARY)
def test_ordinary_messages_raise_no_alarm(species: str, message: str) -> None:
    result, client = _answer(species, message)

    assert result.mode == "natural", result.answer
    assert len(client.requests) >= 1


# --- the rules themselves ----------------------------------------------------------


def test_text_is_normalised_the_way_owners_type_it() -> None:
    assert normalize_for_matching("L’ANTIGELO  è lì") == "l'antigelo e li"


@pytest.mark.parametrize(
    ("message", "family"),
    [
        # Whole words only: never found inside another word.
        ("Gigliola ha mangiato con noi", "cat"),
        ("ha leccato il prosciutto glicolato", "dog"),
        ("ha mangiato un antitopografico", "dog"),
        # Lilies are a cat emergency, not a dog one.
        ("il cane ha mangiato un giglio", "dog"),
        # A swollen belly alone is not the dog's torsion in a cat.
        ("ha la pancia gonfia", "cat"),
        # A poison named without any exposure is a prevention question.
        ("dove tengo il topicida lontano dal cane?", "dog"),
    ],
)
def test_no_flag_outside_what_the_rule_is_for(message: str, family: str) -> None:
    assert emergency_flags(message, family) == []


def test_a_rabbit_with_a_swollen_belly_is_an_emergency_too() -> None:
    assert emergency_flags("ha la pancia gonfia e dura", "small_mammal") == ["torsione gastrica"]


@pytest.mark.parametrize(
    "message",
    [
        "quanto costa il metacam in farmacia?",
        "quanto dura l'effetto dell'antibiotico?",
        "quante dosi di vaccino deve fare?",
        "quante crocchette gli do a pasto?",
        "la dose di crocchette va bene?",
        "raddoppio la pappa la sera?",
    ],
)
def test_not_a_dose_request(message: str) -> None:
    assert not is_dosage_request(message)
