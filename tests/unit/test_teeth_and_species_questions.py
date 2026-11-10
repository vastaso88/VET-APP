"""Two fixes after the measurements of 2026-11-10: dental questions are health
questions (the rabbit's teeth card was never found), and the gut-stasis
clarifying question goes only to rabbits and rodents (it was asked about a dog
that vomited)."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.health_card_selector import HealthCardSelector
from packages.core.application.services.urgency_classifier import (
    UrgencyClassifier,
    UrgencyVerdict,
)
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.safety.triage_clarification import clarifying_question
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_health_cards import (
    InMemoryHealthCardRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

# --- teeth ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "ogni quanto devo fargli limare i denti?",
        "ha i denti lunghi e sbava un po'",
        "mangia da un lato solo da ieri",
        "my rabbit's teeth look too long",
        "mi conejo tiene los dientes largos",
        "mein Kaninchen sabbert und hat lange Zähne",
        "mon lapin a les dents trop longues",
    ],
)
def test_dental_questions_are_health_questions(message: str) -> None:
    assert ChatOrchestrator._is_health_question(
        RequestKind.DIRECT, "everyday_question", None, message
    )


@pytest.mark.parametrize(
    "message",
    [
        "quando gli tolgo il gioco mostra i denti",
        "he shows his teeth when I go near the bowl",
        "ogni quanto va spazzolato?",
    ],
)
def test_showing_the_teeth_or_other_care_is_not_health(message: str) -> None:
    assert not ChatOrchestrator._is_health_question(
        RequestKind.DIRECT, "everyday_question", None, message
    )


def test_the_rabbit_teeth_question_now_reaches_the_cards_rule() -> None:
    llm = RecordingLLMClient()
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        health_card_selector=HealthCardSelector(InMemoryHealthCardRepository(), llm),
    )

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="ogni quanto devo fargli limare i denti?",
            species="Piccoli mammiferi",
            breed="Coniglio nano",
            pet_name="Fiocco",
        )
    )

    (request,) = llm.requests_for("answer")
    assert "HEALTH QUESTION" in request.system_prompt


# --- the clarifying question follows the species ---------------------------------------------


class _Maybe(UrgencyClassifier):
    def __init__(self, category: str) -> None:  # noqa: D107
        self.category = category

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        return UrgencyVerdict(level="maybe", category=self.category)


def _ask(species: str, breed: str | None, message: str) -> ChatOrchestratorResult:
    return ChatOrchestrator(
        RecordingLLMClient(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=_Maybe("gi_stasis"),
    ).answer(
        ChatOrchestratorInput(user_message=message, species=species, breed=breed, pet_name="Bobo")
    )


def test_the_gut_stasis_question_is_never_asked_about_a_dog_or_a_cat() -> None:
    stasis = clarifying_question("gi_stasis", "it")
    for species, message in (
        ("Cane", "Bobo is weird today, he vomited this morning"),
        ("Gatto", "Bobo oggi è strano, ha vomitato stamattina"),
    ):
        result = _ask(species, None, message)

        assert result.mode != "safety_clarification", species
        assert stasis is None or stasis not in result.answer


def test_the_gut_stasis_question_is_still_asked_about_a_rabbit() -> None:
    result = _ask("Piccoli mammiferi", "Coniglio nano", "Bobo oggi è strano e sta fermo")

    assert result.mode == "safety_clarification"
    assert result.answer == clarifying_question("gi_stasis", "it")


def test_the_question_catalogue_filters_by_family() -> None:
    assert clarifying_question("gi_stasis", "en", family="dog") is None
    assert clarifying_question("gi_stasis", "en", family="cat") is None
    assert clarifying_question("gi_stasis", "en", family="small_mammal") is not None
    assert clarifying_question("gi_stasis", "en") is not None  # no species given: unchanged
    assert clarifying_question("respiratory", "it", family="dog") is not None
