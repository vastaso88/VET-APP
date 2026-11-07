"""Three corrections after the first round on Claude Haiku 5.5 (2026-11-07):
another species than the profile's, the clarifying question's gender and
fit in every language, no invented reasons next to the first-aid steps."""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.natural_answer_prompt import build_emergency_prompt
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.safety.clarification_fit import clarifying_question_fits
from packages.core.domain.safety.triage_clarification import clarifying_question
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def _ask(
    message: str,
    *,
    species: str = "Cane",
    name: str = "Toby",
    sex: str | None = None,
    language: str = "it",
    notes: str | None = None,
    reminders: str | None = None,
    history: tuple[tuple[str, str], ...] = (),
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = RecordingLLMClient()
    result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            pet_name=name,
            sex=sex,
            language=language,
            notes=notes,
            weight_label="30 kg",
            age_years=7,
            reminders_context=reminders,
            medical_record_consent=True,
            conversation_history=[ChatMessage(role=r, content=c) for r, c in history],
        )
    )
    return result, llm


# --- 1. another animal than the profile's -------------------------------------------


def test_a_message_about_another_species_leaves_the_profile_out_of_the_prompt() -> None:
    _, llm = _ask(
        "il mio gatto vomita da stamattina, cosa faccio?",
        notes="Toby soffre di artrosi",
        reminders="Antibiotico (terapia in corso)",
    )

    (request,) = llm.requests_for("answer")
    assert "ANOTHER ANIMAL" in request.system_prompt
    assert "Species: cat" in request.user_prompt
    assert "belongs to a different animal, Toby (Cane)" in request.user_prompt
    for leaked in ("30 kg", "artrosi", "Antibiotico", "Age:", "Weight:"):
        assert leaked not in request.user_prompt, leaked


def test_the_profiles_own_animal_keeps_its_data() -> None:
    _, llm = _ask("Toby vomita da stamattina, cosa faccio?", notes="Toby soffre di artrosi")

    (request,) = llm.requests_for("answer")
    assert "ANOTHER ANIMAL" not in request.system_prompt
    assert "artrosi" in request.user_prompt
    assert "30 kg" in request.user_prompt


# --- 2. the clarifying question: sex and fit ----------------------------------------


def test_the_urinary_question_follows_the_animals_sex() -> None:
    assert "non lo vedi urinare" in (clarifying_question("urinary", "it") or "")
    assert "non la vedi urinare" in (clarifying_question("urinary", "it", female=True) or "")
    assert "n'a-t-elle pas uriné" in (clarifying_question("urinary", "fr", female=True) or "")
    # Neutral languages keep the one text.
    assert clarifying_question("urinary", "en", female=True) == clarifying_question("urinary", "en")
    assert clarifying_question("gi_stasis", "it", female=True) == clarifying_question(
        "gi_stasis", "it"
    )


def test_a_female_cat_is_asked_in_the_feminine() -> None:
    result, _ = _ask(
        "Nina non urina da stamattina, va nella lettiera e non esce niente",
        species="Gatto",
        name="Nina",
        sex="Femmina",
    )

    assert result.mode == "safety_clarification"
    assert "non la vedi urinare" in result.answer
    assert " lo vedi" not in result.answer


def test_house_soiling_skips_the_urinary_question_in_every_language() -> None:
    for message in (
        "la gata orina fuera del arenero desde hace dos días y se esfuerza",
        "the cat pees outside the litter box since yesterday and strains",
        "die Katze pinkelt seit gestern neben das Katzenklo",
        "la chatte fait pipi à côté de la litière depuis deux jours",
        "la gatta fa la pipì fuori dalla lettiera da due giorni",
    ):
        assert clarifying_question_fits("urinary", message) is False, message
    assert clarifying_question_fits("urinary", "da stamattina non riesce a fare pipì") is True


def test_the_spanish_cat_that_urinates_outside_the_box_gets_an_answer_not_the_question() -> None:
    result, llm = _ask(
        "mi gata orina fuera del arenero desde hace dos días y hace fuerza",
        species="Gato",
        name="Nina",
        sex="Femmina",
        language="es",
    )

    assert result.mode != "safety_clarification"
    assert llm.requests_for("answer")


# --- 3. the first-aid steps as written ----------------------------------------------


def test_the_emergency_prompt_forbids_invented_reasons() -> None:
    prompt = build_emergency_prompt(first_aid="1) chiama il veterinario")

    assert "never add a reason of your own" in prompt
    assert "può peggiorare le cose" in prompt
