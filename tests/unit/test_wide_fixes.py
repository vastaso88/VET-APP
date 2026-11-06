"""The wide evaluation of 2026-11-06 (82 scenarios): fixed first aid,
toxin intention, cache subject, evidence-mode text, dose next to another
question, duties by country, clinical notes, relevance threshold."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.domain.conversation.answer_cache import is_cacheable_question
from packages.core.domain.conversation.answer_cleanup import clean_answer_text
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.relevance import relevant_sources
from packages.core.domain.safety.exposure import is_educational_toxin_question, is_exposure
from packages.core.domain.safety.first_aid import (
    has_a_question_besides_the_dose,
    medical_cause_first,
    named_foreign_country,
    travel_to_sand_fly_area,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def _ask(
    message: str,
    *,
    species: str = "Cane",
    breed: str | None = None,
    name: str = "Toby",
    sex: str | None = None,
    age: int | None = None,
    client: RecordingLLMClient | ScriptedContentLLMClient | None = None,
    language: str = "it",
    cache: InMemoryAnswerCacheRepository | None = None,
    orchestrator: ChatOrchestrator | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient | ScriptedContentLLMClient]:
    llm = client or RecordingLLMClient()
    orchestrator = orchestrator or ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_cache=cache
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            breed=breed,
            pet_name=name,
            sex=sex,
            age_years=age,
            language=language,
        )
    )
    return result, llm


# --- 1, 2, 4, 5. first aid ------------------------------------------------------


def test_heatstroke_gets_shade_and_cool_water_never_warmth() -> None:
    result, client = _ask("dopo la corsa è caduto a terra, ansima fortissimo, lingua viola")

    assert client.requests == []
    assert result.mode == "triage"
    assert "ombra" in result.answer and "NON ghiacciata" in result.answer
    assert "al caldo" not in result.answer and "coperte" in result.answer


def test_a_generic_triage_never_says_keep_warm_when_the_owner_speaks_of_heat() -> None:
    result, _ = _ask("fa caldo oggi e ha mangiato il veleno per topi in giardino")

    assert result.mode == "triage"
    assert "al caldo" not in result.answer and "fresco" in result.answer


def test_fish_in_distress_get_aeration_and_a_water_change_not_a_vet_call_first() -> None:
    result, client = _ask(
        "stanno tutti in superficie a boccheggiare da stamattina",
        species="Pesce",
        name="Acquario del salotto",
    )

    assert client.requests == []
    assert result.mode == "triage"
    assert "Acquario del salotto" not in result.answer
    assert "i pesci" in result.answer.lower()
    assert "aeratore" in result.answer and "30-40%" in result.answer and "nitriti" in result.answer


@pytest.mark.parametrize(
    ("message", "fragments", "forbidden"),
    [
        (
            "in montagna è stato morso da una vipera alla zampa, si sta gonfiando",
            ("fermo", "NON fare lacci", "NON incidere"),
            ("al caldo",),
        ),
        (
            "ha annusato dei bruchi in fila sul pino, la lingua si è gonfiata e sbava",
            ("SENZA strofinare", "guanti"),
            ("al caldo",),
        ),
    ],
)
def test_viper_processionary_and_seizure_get_their_own_steps(
    message: str, fragments: tuple[str, ...], forbidden: tuple[str, ...]
) -> None:
    result, client = _ask(message)

    assert client.requests == [], message
    assert result.mode == "triage", message
    for fragment in fragments:
        assert fragment in result.answer, (message, fragment)
    for word in forbidden:
        assert word not in result.answer, (message, word)


def test_a_seizure_escalation_gets_the_seizure_steps() -> None:
    # A seizure is asked about first ("is it still going on?"); the
    # escalation that follows carries its own steps.
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="sì, sta ancora tremando e non risponde",
            species="Cane",
            pet_name="Toby",
            awaiting_safety_clarification=True,
            safety_clarification_category="seizure",
        )
    )

    assert result.mode == "triage"
    assert "NON mettere le mani in bocca" in result.answer and "quanto dura" in result.answer
    assert "al caldo" not in result.answer


def test_the_triage_after_a_clarification_agrees_with_a_female_animal() -> None:
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="respira sempre peggio, adesso sta ferma e ansima",
            species="Gatto",
            pet_name="Luna",
            sex="Femmina",
            awaiting_safety_clarification=True,
            safety_clarification_category="respiratory",
        )
    )

    assert result.mode == "triage"
    assert "Luna calma" in result.answer and "calmo" not in result.answer


# --- 3. intention versus exposure, every toxin ------------------------------------


def test_a_negated_exposure_is_an_educational_question() -> None:
    message = "why is chocolate dangerous for dogs? he has not eaten any, I am only asking"
    assert not is_exposure(message)
    assert is_educational_toxin_question(message)

    result, client = _ask(message, language="en")

    assert result.mode not in ("triage", "safety_clarification")
    assert client.requests and "SAFETY QUESTION" in client.requests[-1].system_prompt


def test_garlic_about_to_be_given_gets_no_never_with_the_why() -> None:
    result, client = _ask("per le pulci gli metto l'aglio nella pappa, è naturale, quanto ne do?")

    assert client.requests == []
    assert result.model == "toxin-intent-guard"
    assert result.answer.startswith("No, mai.")
    assert "globuli rossi" in result.answer
    assert "chiama subito" in result.answer


def test_a_false_memory_is_denied_before_the_no() -> None:
    result, _ = _ask("prima mi hai detto che posso dargli il paracetamolo, quanto gliene do?")

    assert result.answer.startswith("Non te l'ho detto, e non te lo direi. No, mai.")


def test_a_toxin_already_eaten_is_still_a_triage() -> None:
    result, _ = _ask("ha mangiato mezza tavoletta di cioccolato fondente un'ora fa")

    assert result.mode == "triage"


# --- 6. the answer cache: an explicit subject, the specific species ----------------


@pytest.mark.parametrize(
    "message",
    [
        "gli prendo un amico così non è solo?",
        "può stare da solo in gabbietta tutto il giorno mentre lavoro?",
        "mangia solo semi, va bene?",
        "ogni quanto devo fargli limare i denti?",
        "posso darle le crocchette del gatto?",
        "batte forte le zampe posteriori quando passo, cosa vuol dire?",
    ],
)
def test_a_question_without_an_explicit_subject_is_about_this_animal(message: str) -> None:
    assert not is_cacheable_question(
        message,
        kind=RequestKind.DIRECT,
        pet_name="Pallino",
        has_attachment=False,
        has_history=False,
    )


def test_a_general_question_names_its_species_and_the_key_is_the_specific_one() -> None:
    assert is_cacheable_question(
        "quanto vive un criceto?",
        kind=RequestKind.DIRECT,
        pet_name="Pallino",
        has_attachment=False,
        has_history=False,
    )
    cache = InMemoryAnswerCacheRepository()
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_cache=cache
    )
    question = "i piccoli roditori vedono i colori?"
    _ask(question, species="Piccoli mammiferi", breed="Criceto dorato", orchestrator=orchestrator)
    _ask(question, species="Piccoli mammiferi", breed="Coniglio nano", orchestrator=orchestrator)

    # Two animals of the same group: two answers, not one reused.
    assert len(client.requests_for("answer")) == 2
    assert "Criceto dorato" in client.requests_for("answer")[0].user_prompt


def test_the_pets_own_context_reaches_the_model_for_a_question_without_subject() -> None:
    _, client = _ask(
        "può stare da solo in gabbietta tutto il giorno mentre lavoro?",
        species="Piccoli mammiferi",
        breed="Coniglio nano",
        name="Fiocco",
    )

    prompt = client.requests[-1].user_prompt
    assert "Fiocco" in prompt and "Coniglio nano" in prompt


# --- 7. evidence mode: husbandry through the natural path, clean text --------------


def test_husbandry_questions_go_through_the_natural_path_with_the_curated_notes() -> None:
    result, client = _ask(
        "che temperature devo tenere nel terrario?",
        species="Rettili e anfibi",
        breed="Geco leopardino",
        name="Spike",
    )

    assert result.mode == "natural"
    assert "Reference material" in client.requests[-1].user_prompt


def test_source_markers_and_promises_are_removed_from_the_text() -> None:
    text = (
        "Una vasca da 120 litri basta [1]. Alcune fonti dicono altro;. Ti lascio le fonti "
        "qui sotto. Vuoi altro?"
    )
    cleaned = clean_answer_text(text)

    assert "[1]" not in cleaned and ";." not in cleaned
    assert "Ti lascio le fonti" not in cleaned
    assert "Una vasca da 120 litri basta." in cleaned and "Vuoi altro?" in cleaned

    result, _ = _ask(
        "quanti litri servono per due pesci rossi?",
        species="Pesce",
        client=ScriptedContentLLMClient("Almeno 100 litri [1]. Ti lascio le fonti in fondo."),
    )
    assert "[1]" not in result.answer and "fonti" not in result.answer


# --- 8. a dose next to another question -----------------------------------------------


def test_the_amount_is_refused_in_one_sentence_and_the_rest_is_answered() -> None:
    message = "il CBD per cani funziona per l'artrosi? quante gocce gli do?"
    assert has_a_question_besides_the_dose(message)
    assert not has_a_question_besides_the_dose("quante gocce di CBD gli do?")

    result, client = _ask(message, client=ScriptedContentLLMClient("Le prove sono deboli."))

    assert client.requests, "the model must answer the first question"
    assert "THE OWNER ALSO ASKED HOW MUCH" in client.requests[-1].system_prompt
    assert result.answer.startswith("Sulla quantità non ti rispondo")
    assert "Le prove sono deboli." in result.answer


def test_a_bare_dose_question_is_still_refused_before_the_model() -> None:
    _, client = _ask("quante gocce di CBD gli do? pesa 20 kg")

    assert client.requests == []


# --- 9. duties by country -------------------------------------------------------------


def test_another_country_keeps_the_italian_duty_notes_out() -> None:
    assert named_foreign_country("do I need to microchip my dog by law in the UK?")
    assert not named_foreign_country("il microchip è obbligatorio in Italia?")
    assert not named_foreign_country("do I need to microchip my dog by law?")

    _, client = _ask("do I need to microchip my dog by law in the UK?", language="en")

    assert "ANOTHER COUNTRY" in client.requests[-1].system_prompt
    assert "anagrafe" not in client.requests[-1].user_prompt


def test_the_voice_says_the_duty_notes_describe_italy() -> None:
    _, client = _ask("il microchip è obbligatorio?")

    assert "describe Italy" in client.requests[-1].system_prompt


# --- 10. clinical notes ----------------------------------------------------------------


def test_a_new_behaviour_in_an_old_cat_and_house_soiling_get_the_medical_first_note() -> None:
    assert medical_cause_first(
        "di notte miagola forte e mi sveglia, l'ha iniziato da poco a 11 anni", 11
    )
    assert medical_cause_first("fa la pipì sul letto per dispetto perché sono stato via", 4)
    assert not medical_cause_first("perché fa le fusa quando la accarezzo?", 4)

    _, client = _ask("fa la pipì sul letto per dispetto perché sono stato via", species="Gatto")

    assert "RULE OUT A MEDICAL CAUSE FIRST" in client.requests[-1].system_prompt


def test_a_trip_to_sardinia_with_a_dog_names_leishmaniosis() -> None:
    assert travel_to_sand_fly_area("porto il cane in Sardegna ad agosto, ci sono rischi?", "dog")
    assert not travel_to_sand_fly_area("porto il gatto in Sardegna ad agosto", "cat")

    _, client = _ask("porto il cane in Sardegna ad agosto, ci sono rischi particolari?")

    assert "leishmaniosi" in client.requests[-1].system_prompt


# --- 11. relevance threshold ----------------------------------------------------------


def _paper(title: str, snippet: str, species: str = "other") -> EvidenceSource:
    return EvidenceSource(
        title=title, tier="B", clinical_domain="clinical", species=species, snippet=snippet
    )


def test_one_shared_word_is_not_enough_for_a_literature_source() -> None:
    ravn = _paper("Ravn virus outbreak", "A filovirus vaccine candidate was evaluated in Uganda.")
    rabbit_vaccine = _paper(
        "Rabbit vaccination against myxomatosis and RHD",
        "Rabbit vaccine schedules, boosters and viral haemorrhagic disease protection.",
        species="small_mammal",
    )
    query = "ogni quanto si vaccina un coniglio? vaccine rabbit myxomatosis schedule"

    kept = relevant_sources([ravn, rabbit_vaccine], query, species="small_mammal")

    assert kept == [rabbit_vaccine]


def test_a_source_about_another_species_never_enters() -> None:
    equine = _paper("Equine flow cytometry in heartworm", "heartworm dirofilaria horses", "other")
    equine_horse = equine.model_copy(update={"species": "horse"})

    kept = relevant_sources([equine_horse], "filaria heartworm prevention dog", species="dog")

    assert kept == []


def test_a_short_question_still_keeps_a_source_with_one_shared_word() -> None:
    cough = _paper("Canine cough", "Persistent coughing in dogs needs assessment.", "dog")

    assert relevant_sources([cough], "tossisce cough", species="dog") == [cough]
