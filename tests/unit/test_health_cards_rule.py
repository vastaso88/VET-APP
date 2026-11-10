"""Plan stage 2 (2026-11-10): health answers only from approved cards, cited
as [S1]; without cards the safe path; a fixed reply for off-topic messages.
Management and education stay as they were."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.health_card_selector import (
    SELECTOR_MARKER,
    HealthCardSelector,
)
from packages.core.application.services.urgency_classifier import (
    UrgencyClassifier,
    UrgencyVerdict,
)
from packages.core.domain.knowledge.health_cards import HealthCard, format_cards_for_prompt
from packages.core.domain.safety.harmful_requests import OFF_TOPIC_TEXTS
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_health_cards import (
    InMemoryHealthCardRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

DIARRHOEA = HealthCard(
    id="cane-diarrea-acuta",
    species=("dog",),
    topic="diarrea",
    title="Diarrea nel cane: quando osservare e quando andare dal veterinario",
    body=(
        "Una diarrea di poche ore in un cane adulto vivace che beve può essere osservata a "
        "casa per un giorno. Sangue nelle feci, vomito ripetuto, abbattimento o un cucciolo "
        "sono motivi per il veterinario lo stesso giorno."
    ),
    source="WSAVA, linee guida gastroenteriche (esempio di prova)",
    source_level=1,
)
CAT_CARD = DIARRHOEA.model_copy(update={"id": "gatto-diarrea", "species": ("cat",)})


class _Classifier(UrgencyClassifier):
    def __init__(self, topic: str | None) -> None:  # noqa: D107
        self.topic = topic

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        return UrgencyVerdict(level="normal", topic=self.topic)


def _ask(
    message: str,
    *,
    cards: tuple[HealthCard, ...] = (),
    answer: str = "Risposta di prova, concreta e breve.",
    topic: str | None = None,
    rule: bool = True,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = RecordingLLMClient(answer)
    selector = HealthCardSelector(InMemoryHealthCardRepository(cards), llm) if rule else None
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=_Classifier(topic),
        health_card_selector=selector,
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species="Cane", pet_name="Toby")
    )
    return result, llm


def test_a_health_question_with_cards_gets_only_the_cards_and_must_cite_them() -> None:
    result, llm = _ask(
        "Toby ha la diarrea da stamattina ma gioca e beve, cosa faccio?",
        cards=(DIARRHOEA, CAT_CARD),
        answer="Per qualche ora puoi osservarlo a casa [S1].",
    )

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION, APPROVED CARDS" in request.system_prompt
    assert format_cards_for_prompt([DIARRHOEA]) in request.user_prompt
    assert "gatto-diarrea" not in request.user_prompt  # another species' card
    assert "Reference material" not in request.user_prompt  # no unapproved notes
    assert result.answer.startswith("Per qualche ora")
    assert [source.title for source in result.sources] == [DIARRHOEA.title]
    # The licence attribution, written by the code under the answer.
    assert result.answer.rstrip().endswith(f"Fonte: {DIARRHOEA.source}")


def test_the_source_line_names_each_source_once_in_the_owners_language() -> None:
    from packages.core.domain.knowledge.health_cards import source_line

    other = DIARRHOEA.model_copy(update={"id": "x", "source": "ISFM, 2024"})
    assert source_line([DIARRHOEA, DIARRHOEA], "it") == f"Fonte: {DIARRHOEA.source}"
    assert source_line([DIARRHOEA, other], "en") == f"Sources: {DIARRHOEA.source}; ISFM, 2024"
    assert source_line([other], "fr") == "Source : ISFM, 2024"
    assert source_line([], "it") == ""


def test_a_health_question_without_cards_takes_the_safe_path() -> None:
    _, llm = _ask("Toby ha la diarrea da stamattina, cosa faccio?")

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION, NO APPROVED CARD" in request.system_prompt
    assert "<fonti_approvate>" not in request.user_prompt


def test_an_invented_card_label_is_refused() -> None:
    result, _ = _ask(
        "Toby ha la diarrea da stamattina, cosa faccio?",
        cards=(DIARRHOEA,),
        answer="Dagli riso in bianco [S2].",
    )

    assert "riso in bianco" not in result.answer
    assert result.ai_generated is False


def test_the_classifier_health_topic_puts_an_everyday_message_under_the_rule() -> None:
    _, llm = _ask("ogni quanto va spazzolato Toby?", topic="health")

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION" in request.system_prompt


def test_management_and_education_stay_as_they_were() -> None:
    _, llm = _ask("come insegno a Toby a non tirare al guinzaglio?", topic="care")

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION" not in request.system_prompt


def test_with_the_rule_off_nothing_changes() -> None:
    _, llm = _ask("Toby ha la diarrea da stamattina, cosa faccio?", rule=False)

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION" not in request.system_prompt


def test_more_than_three_cards_are_chosen_by_the_light_model() -> None:
    cards = tuple(
        DIARRHOEA.model_copy(update={"id": f"cane-diarrea-{n}", "title": f"Diarrea {n}"})
        for n in range(5)
    )
    llm = RecordingLLMClient(
        by_purpose={"health_card_selection": '{"ids": ["cane-diarrea-3", "inventata"]}'}
    )
    selector = HealthCardSelector(InMemoryHealthCardRepository(cards), llm)

    chosen = selector.select(species="dog", question="Toby ha la diarrea, cosa faccio?")

    assert [card.id for card in chosen] == ["cane-diarrea-3"]
    (request,) = llm.requests_for("health_card_selection")
    assert SELECTOR_MARKER in request.system_prompt
    assert request.model_class == "light"


def test_a_failed_selection_keeps_the_store_order() -> None:
    cards = tuple(DIARRHOEA.model_copy(update={"id": f"c{n}"}) for n in range(5))
    llm = RecordingLLMClient(by_purpose={"health_card_selection": "non è json"})

    chosen = HealthCardSelector(InMemoryHealthCardRepository(cards), llm).select(
        species="dog", question="diarrea"
    )

    assert [card.id for card in chosen] == ["c0", "c1", "c2"]


# --- off topic --------------------------------------------------------------------


def test_an_off_topic_message_gets_the_fixed_reply_without_an_answer_call() -> None:
    result, llm = _ask("come si cambia l'olio della macchina?", topic="off_topic")

    assert result.answer == OFF_TOPIC_TEXTS["it"].format(name="Toby")
    assert llm.requests_for("answer") == []


def test_a_message_with_an_animal_is_never_off_topic() -> None:
    for message in (
        "posso portare Toby in macchina per tre ore?",
        "il mio gatto può mangiare la pasta?",
        "il cucciolo del vicino abbaia sempre",
    ):
        result, llm = _ask(message, topic="off_topic")

        assert result.answer != OFF_TOPIC_TEXTS["it"].format(name="Toby"), message
        assert llm.requests_for("answer"), message


def test_the_off_topic_reply_exists_in_five_languages_with_the_name() -> None:
    assert set(OFF_TOPIC_TEXTS) == {"it", "en", "es", "de", "fr"}
    for text in OFF_TOPIC_TEXTS.values():
        assert "{name}" in text
    assert " du " not in OFF_TOPIC_TEXTS["de"]  # Sie, as every German text


# --- the manual project's export -----------------------------------------------------


def test_the_export_loads_only_approved_cards_unless_an_evaluation_asks() -> None:
    from packages.core.domain.knowledge.health_cards import CARDS_FILE, load_cards_file

    if not CARDS_FILE.exists():
        pytest.skip("no export yet")
    everything = load_cards_file(include_drafts=True)
    approved = load_cards_file()

    assert everything
    assert all(card.status == "approved" for card in approved)
    assert len(approved) <= len(everything)
    for card in everything:
        assert not card.source.lower().startswith(("fonte:", "fonti:")), card.id
        assert card.species and card.title and card.body


def test_a_rabbits_card_is_not_a_hamsters() -> None:
    from packages.core.domain.knowledge.health_cards import card_species_key

    assert card_species_key("small_mammal", "Coniglio nano") == "rabbit"
    assert card_species_key("small_mammal", "", "", "il mio coniglio non mangia") == "rabbit"
    assert card_species_key("small_mammal", "Criceto dorato") == "small_mammal"
    assert card_species_key("dog", "coniglio") == "dog"


def test_drafts_are_refused_in_production() -> None:
    from packages.shared.config.settings import Settings

    with pytest.raises(ValueError, match="HEALTH_CARDS_INCLUDE_DRAFTS"):
        Settings(  # type: ignore[call-arg]
            ENVIRONMENT="production",
            AUTH_BACKEND="supabase",
            PERSISTENCE_BACKEND="supabase",
            HEALTH_CARDS_INCLUDE_DRAFTS=True,
        )
