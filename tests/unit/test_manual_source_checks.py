"""Four fixed texts checked against their sources for the "Capire il tuo
animale" manual project (2026-11-08): the dog leash and muzzle duty, the
growl, the socialisation window, the ferret's first aid."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.knowledge.duty_notes import DUTY_CATALOG
from packages.core.domain.localization import translate
from packages.core.domain.pet_profile.species_facts import species_facts
from packages.infrastructure.llm.retrieval.curated_awareness_evidence_retriever import (
    AWARENESS_CATALOG,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def _dog_texts() -> list[str]:
    return [
        species_facts("Cane", ethology=True),
        *(source.snippet or "" for source in AWARENESS_CATALOG if source.species == "dog"),
    ]


def test_the_leash_and_muzzle_note_states_the_2013_ordinance() -> None:
    # Ordinanza 6-8-2013, art. 1 c. 3 (GU 209 of 6-9-2013), extended
    # unchanged to 5-9-2027 (GU 206 of 5-9-2026).
    (note,) = [s.snippet or "" for s in DUTY_CATALOG if "leash and muzzle" in s.title]
    assert "1.5 m" in note
    assert "muzzle" in note
    assert len(note) <= 300


def test_no_text_says_punishing_a_growl_removes_the_warning() -> None:
    for text in _dog_texts():
        assert "removes the warning" not in text
    assert "never punish" in species_facts("Cane", ethology=True)


def test_socialisation_is_not_a_closed_window_and_never_forced() -> None:
    for text in _dog_texts():
        assert "12-14 weeks" not in text
    facts = species_facts("Cane", ethology=True)
    assert "first three months" in facts
    assert "goes on after" in facts
    assert "never forced" in facts


def _first_aid_for(species: str, breed: str | None, message: str) -> str:
    result = ChatOrchestrator(
        RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    ).answer(
        ChatOrchestratorInput(user_message=message, species=species, pet_name="Zorro", breed=breed)
    )
    assert result.mode == "triage", result.answer
    return result.answer


def test_a_ferret_does_not_get_the_rabbits_hay_steps() -> None:
    hay = translate("triage_steps_small_mammal_stasis", "it", pet_name="Zorro")
    exotic = translate("triage_steps_exotic", "it", pet_name="Zorro")

    for breed, message in (
        ("Furetto", "Zorro non mangia da ieri e non fa la cacca"),
        (None, "il mio furetto Zorro non mangia da ieri e non fa la cacca"),
    ):
        answer = _first_aid_for("Piccoli mammiferi", breed, message)
        assert hay not in answer
        assert "fieno" not in answer
        assert exotic in answer


def test_a_rabbit_keeps_the_stasis_steps() -> None:
    answer = _first_aid_for("Piccoli mammiferi", "Coniglio nano", "Zorro non mangia da ieri")

    assert translate("triage_steps_small_mammal_stasis", "it", pet_name="Zorro") in answer
