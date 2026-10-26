"""The German and French equivalents of the Italian triage stress test
(2026-10-26): the same five emergency groups and the dose requests take the
fixed rule-based path, ordinary messages do not, and the fixed replies use
the formal address ("Sie", "vous"). Deterministic, no model calls."""

from __future__ import annotations

import re

import pytest
import safety_phrasings as it
import safety_phrasings_de as de
import safety_phrasings_fr as fr
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.safety_gate import (
    SPECIES_SPECIFIC_RED_FLAGS,
    URGENT_RED_FLAG_KEYWORDS,
)
from packages.core.domain.safety.dosage_request import is_dosage_request
from packages.core.domain.safety.emergency_patterns import PATTERNS_BY_LANGUAGE, emergency_flags
from packages.core.domain.safety.red_flags_de_fr import (
    SPECIES_DE,
    SPECIES_FR,
    URGENT_DE,
    URGENT_FR,
    all_urgent_keywords,
)
from packages.core.domain.safety.triage_clarification import (
    RED_FLAG_CATEGORIES,
    categorize,
    requires_immediate_escalation,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

SUITES = {"de": de, "fr": fr}
# The profile stores the species in the app's canonical labels.
SPECIES = {"Hund": "Cane", "Katze": "Gatto", "Chien": "Cane", "Chat": "Gatto"}
TRIAGE_LINE = {"de": "Wenden Sie sich sofort", "fr": "contactez tout de suite"}
INFORMAL = {
    "de": re.compile(r"\b(du|dich|dir|dein|deine|deinen|deinem|deiner)\b", re.IGNORECASE),
    "fr": re.compile(r"\b(tu|toi|ton|ta|tes)\b", re.IGNORECASE),
}
# French formal address shows in "vous"/"votre" or in the verb ending ("contactez").
FORMAL = {
    "de": re.compile(r"\b(Sie|Ihnen|Ihr|Ihre|Ihren)\b"),
    "fr": re.compile(r"\b(vous|votre|vos)\b|\w+ez\b"),
}

_EMERGENCY_CASES = [
    pytest.param(language, species, message, id=f"{language} {name}: {message}")
    for language, suite in SUITES.items()
    for name, cases in suite.EMERGENCIES.items()
    for species, message in cases
]
_DOSAGE_CASES = [
    pytest.param(language, species, message, id=f"{language}: {message}")
    for language, suite in SUITES.items()
    for species, message in suite.DOSAGE
]
_ORDINARY_CASES = [
    pytest.param(language, species, message, id=f"{language}: {message}")
    for language, suite in SUITES.items()
    for species, message in suite.ORDINARY
]


def _answer(
    language: str, species: str, message: str
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    client = RecordingLLMClient("risposta del modello")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message, species=SPECIES[species], pet_name="Birba", language=language
        )
    )
    return result, client


# --- the suites mirror the Italian one -------------------------------------------------


def test_the_suites_have_the_same_shape_as_the_italian_one() -> None:
    for suite in SUITES.values():
        assert set(suite.EMERGENCIES) == set(it.EMERGENCIES)
        for name, cases in it.EMERGENCIES.items():
            assert len(suite.EMERGENCIES[name]) == len(cases), name
        assert sum(len(c) for c in suite.EMERGENCIES.values()) == 56
        assert len(suite.DOSAGE) == len(it.DOSAGE) == 15
        assert len(suite.ORDINARY) == len(it.ORDINARY) == 20


def test_every_italian_emergency_group_has_a_german_and_a_french_pattern() -> None:
    italian_flags = {rule.flag for rule in PATTERNS_BY_LANGUAGE["it"]}
    for language in ("de", "fr"):
        assert {rule.flag for rule in PATTERNS_BY_LANGUAGE[language]} == italian_flags, language


# --- emergencies ----------------------------------------------------------------------------


@pytest.mark.parametrize(("language", "species", "message"), _EMERGENCY_CASES)
def test_every_phrasing_of_an_emergency_gets_the_fixed_emergency_text(
    language: str, species: str, message: str
) -> None:
    result, client = _answer(language, species, message)

    assert result.mode == "triage", result.answer
    assert TRIAGE_LINE[language] in result.answer
    assert not result.ai_generated
    assert client.requests == []


@pytest.mark.parametrize(("language", "species", "message"), _DOSAGE_CASES)
def test_every_dose_request_is_stopped_before_the_model(
    language: str, species: str, message: str
) -> None:
    result, client = _answer(language, species, message)

    assert result.model in ("dosage-guard", "safety-triage-guard"), result.answer
    assert client.requests == []


@pytest.mark.parametrize(("language", "species", "message"), _ORDINARY_CASES)
def test_ordinary_messages_raise_no_alarm(language: str, species: str, message: str) -> None:
    result, client = _answer(language, species, message)

    assert result.mode == "natural", result.answer
    assert len(client.requests) >= 1


# --- formal address in the fixed replies -------------------------------------------------------


@pytest.mark.parametrize("language", ["de", "fr"])
def test_the_fixed_replies_address_the_owner_formally(language: str) -> None:
    suite = SUITES[language]
    poison, _ = _answer(language, *suite.RODENTICIDE[0])
    bloat, _ = _answer(language, *suite.BLOAT[3])
    dose, _ = _answer(language, *suite.DOSAGE[0])
    greeting, _ = _answer(language, "Hund" if language == "de" else "Chien", "ciao")

    for reply in (poison.answer, bloat.answer, dose.answer, greeting.answer):
        assert FORMAL[language].search(reply), reply
        assert not INFORMAL[language].search(reply), reply


# --- the lists themselves -----------------------------------------------------------------------


def test_the_italian_lists_are_untouched() -> None:
    # The Italian suite keeps running unchanged (test_emergency_phrasings);
    # here: the Italian keywords still exist and the new ones are foreign.
    assert "non riesce a respirare" in URGENT_RED_FLAG_KEYWORDS
    assert "non fa le feci" in SPECIES_SPECIFIC_RED_FLAGS["small_mammal"]
    assert all_urgent_keywords() <= URGENT_RED_FLAG_KEYWORDS
    assert "atemnot" in URGENT_RED_FLAG_KEYWORDS and "ne respire plus" in URGENT_RED_FLAG_KEYWORDS


def test_every_new_universal_keyword_has_a_category_and_the_same_groups_as_italian() -> None:
    assert set(URGENT_DE) == set(URGENT_FR)
    for catalog in (URGENT_DE, URGENT_FR):
        for category, keywords in catalog.items():
            for keyword in keywords:
                assert categorize([keyword]) == category, keyword
    assert set(SPECIES_DE) == set(SPECIES_FR) == set(SPECIES_SPECIFIC_RED_FLAGS)
    for category in ("respiratory", "collapse", "seizure", "bleeding_trauma", "urinary"):
        assert any(k in RED_FLAG_CATEGORIES[category] for k in URGENT_DE[category])


@pytest.mark.parametrize(
    ("message", "language"),
    [
        ("er ist bewusstlos und atmet nicht mehr", "de"),
        ("il est inconscient et ne respire plus", "fr"),
        ("das Zahnfleisch ist weiß und er blutet stark", "de"),
    ],
)
def test_unambiguous_severity_skips_the_clarifying_question(message: str, language: str) -> None:
    assert requires_immediate_escalation(message)
    result, _ = _answer(language, "Hund" if language == "de" else "Chien", message)
    assert result.mode == "triage"


@pytest.mark.parametrize(
    ("message", "family"),
    [
        # Whole words only: never found inside another word.
        # A cat named Lilie, nothing eaten: the exposure word is required.
        ("sie heißt Lilie und ist eine weiße Katze", "cat"),
        ("il a mangé une tarte au lilas", "cat"),
        # Lilies are a cat emergency, not a dog one.
        ("der Hund hat eine Lilie gefressen", "dog"),
        ("le chien a mangé un lys", "dog"),
        # A swollen belly alone is not the dog's torsion in a cat.
        ("hat einen aufgeblähten Bauch", "cat"),
        ("il a le ventre gonflé", "cat"),
        # A poison named without any exposure is a prevention question.
        ("wo bewahre ich das Rattengift sicher vor dem Hund auf?", "dog"),
        ("où ranger la mort-aux-rats loin du chien ?", "dog"),
    ],
)
def test_no_flag_outside_what_the_rule_is_for(message: str, family: str) -> None:
    assert emergency_flags(message, family) == []


@pytest.mark.parametrize(
    "message",
    [
        "was kostet Metacam in der Apotheke?",
        "wie lange wirkt das Antibiotikum?",
        "wie viele Impfdosen braucht der Welpe?",
        "wie viele Kroketten gebe ich ihm pro Mahlzeit?",
        "combien coûte le Metacam en pharmacie ?",
        "combien de temps dure l'effet de l'antibiotique ?",
        "combien de doses de vaccin doit faire le chiot ?",
        "combien de croquettes je lui donne par repas ?",
    ],
)
def test_not_a_dose_request(message: str) -> None:
    assert not is_dosage_request(message)
