"""Question or exposure (repositioning, docs/product/11 §4 2.2).

"Perché il cioccolato fa male ai cani?" is an owner trying to understand
and gets the explanation with the safety list; "ha mangiato cioccolato"
is an exposure and stays a triage. Every existing emergency fixture in
the five languages must still be an exposure.
"""

from __future__ import annotations

import pytest
import safety_phrasings
import safety_phrasings_de
import safety_phrasings_fr
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.domain.safety.exposure import is_educational_toxin_question
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

# (language, species label, message): the owner asks, nothing was eaten.
EDUCATIONAL: tuple[tuple[str, str, str], ...] = (
    ("it", "Cane", "Perché il cioccolato fa male ai cani?"),
    ("it", "Cane", "è vero che l'uva è tossica per i cani?"),
    ("it", "Gatto", "quali piante sono velenose per i gatti? ho un giglio in salotto"),
    ("it", "Gatto", "come mai la tachipirina è pericolosa per il gatto?"),
    ("it", "Piccoli mammiferi", "quali cibi sono tossici per un coniglio?"),
    ("it", "Uccello", "perché l'avocado è velenoso per i pappagalli?"),
    ("it", "Cane", "cosa succede se un cane mangia la cipolla? voglio capire per prevenire"),
    ("en", "Cane", "Why is chocolate toxic to dogs?"),
    ("en", "Gatto", "Is it true that lilies are dangerous for cats?"),
    ("en", "Cane", "Which foods are toxic for dogs?"),
    ("en", "Gatto", "How dangerous is paracetamol for a cat?"),
    ("es", "Cane", "¿Por qué el chocolate es tóxico para los perros?"),
    ("es", "Gatto", "¿Es verdad que los lirios son peligrosos para los gatos?"),
    ("es", "Cane", "¿Qué alimentos son tóxicos para un perro?"),
    ("de", "Cane", "Warum ist Schokolade für Hunde giftig?"),
    ("de", "Gatto", "Stimmt es, dass Lilien für Katzen gefährlich sind?"),
    ("de", "Cane", "Welche Lebensmittel sind für Hunde giftig?"),
    ("fr", "Cane", "Pourquoi le chocolat est-il toxique pour les chiens ?"),
    ("fr", "Gatto", "Est-ce vrai que les lys sont dangereux pour les chats ?"),
    ("fr", "Cane", "Quels aliments sont toxiques pour un chien ?"),
)

# The same substances, but the animal got them or is about to.
EXPOSURES: tuple[tuple[str, str, str], ...] = (
    ("it", "Cane", "perché il cioccolato fa male? ne ha mangiato mezza tavoletta ieri"),
    ("it", "Cane", "il cane ha mangiato il cioccolato, è pericoloso?"),
    ("it", "Gatto", "è tossica la tachipirina? vorrei dargliene mezza per la febbre"),
    ("it", "Gatto", "ha leccato il giglio, quanto è pericoloso?"),
    ("it", "Cane", "posso dargli l'ibuprofene? fa male?"),
    ("en", "Cane", "why is chocolate toxic? he just ate a bar"),
    ("en", "Gatto", "can I give her paracetamol? is it dangerous?"),
    ("es", "Cane", "¿por qué es tóxico el chocolate? se comió media tableta"),
    ("es", "Gatto", "¿puedo darle paracetamol? ¿es peligroso?"),
    ("de", "Cane", "warum ist Schokolade giftig? er hat gestern eine Tafel gefressen"),
    ("de", "Gatto", "darf ich ihr Paracetamol geben? ist das gefährlich?"),
    ("fr", "Cane", "pourquoi le chocolat est toxique ? il a mangé une tablette"),
    ("fr", "Gatto", "puis-je lui donner du paracétamol ? est-ce dangereux ?"),
)


@pytest.mark.parametrize(("language", "species", "message"), EDUCATIONAL)
def test_a_question_about_a_toxin_with_no_exposure_is_educational(
    language: str, species: str, message: str
) -> None:
    assert is_educational_toxin_question(message), (language, message)


@pytest.mark.parametrize(("language", "species", "message"), EXPOSURES)
def test_an_exposure_or_an_intent_to_give_is_not_educational(
    language: str, species: str, message: str
) -> None:
    assert not is_educational_toxin_question(message), (language, message)


def _all_fixtures(kind: str) -> list[tuple[str, str]]:
    cases: list[tuple[str, str]] = []
    for module in (safety_phrasings, safety_phrasings_de, safety_phrasings_fr):
        if kind == "emergency":
            for group in module.EMERGENCIES.values():
                cases += list(group)
        else:
            cases += list(module.DOSAGE)
    return cases


@pytest.mark.parametrize(("species", "message"), _all_fixtures("dosage"))
def test_no_existing_dose_fixture_is_mistaken_for_a_question(species: str, message: str) -> None:
    assert not is_educational_toxin_question(message), message


@pytest.mark.parametrize(
    ("species", "message"), _all_fixtures("emergency") + _all_fixtures("dosage")
)
def test_no_existing_fixture_slips_past_the_gate(species: str, message: str) -> None:
    # The orchestrator lifts the gate only for a toxin/medicine category
    # with a question and no exposure: no fixture of the three languages
    # may qualify. "Torsione dello stomaco?" is a question, but not about
    # a toxin: its category keeps it a triage regardless.
    flags = SafetyGate().evaluate(message.lower(), species=species)
    if flags:
        assert not ChatOrchestrator._is_educational_toxin_question(flags, message), message  # noqa: SLF001


def _answer(
    message: str, *, species: str, language: str
) -> tuple[RecordingLLMClient, ChatOrchestratorResult]:
    client = RecordingLLMClient()
    result = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message, species=species, pet_name="Birba", language=language
        )
    )
    return client, result


@pytest.mark.parametrize(
    ("language", "species", "message"),
    [case for case in EDUCATIONAL if case[0] in ("it", "en")],
)
def test_the_educational_question_reaches_the_model_with_the_safety_note(
    language: str, species: str, message: str
) -> None:
    client, result = _answer(message, species=species, language=language)

    assert result.mode not in ("triage", "safety_clarification"), result.mode
    assert client.requests, "the model was never asked"
    system_prompt = client.requests[-1].system_prompt
    # The safety note travels when the fixed lists would have fired
    # ("cioccolato", "tachipirina"); a question the lists do not know
    # ("quali piante sono velenose?") is an ordinary direct question.
    flagged = bool(SafetyGate().evaluate(message.lower(), species=species))
    assert ("SAFETY QUESTION" in system_prompt) is flagged, message
    assert ("Never a dose" in system_prompt) is flagged, message


def test_the_exposure_keeps_todays_triage() -> None:
    client, result = _answer(
        "il cane ha mangiato mezza tavoletta di cioccolato fondente", species="Cane", language="it"
    )

    assert result.mode in ("triage", "safety_clarification")
    assert client.requests == []


def test_an_intent_to_give_a_human_medicine_gets_no_never_before_the_model() -> None:
    # Wide eval 2026-11-06: not given yet, so "no, never" with the why; the
    # triage stays for a cat that already got it.
    client, result = _answer(
        "è tossica la tachipirina? vorrei dargliene mezza", species="Gatto", language="it"
    )

    assert result.model == "toxin-intent-guard"
    assert result.answer.startswith("No, mai.") and "tossico per il gatto" in result.answer
    assert client.requests == []
