"""Off-topic messages get a fixed reply without an answer call; a message that names an
animal is never off topic. (Moved from the cards tests when the cards were removed:
schede non più usate dal piano nuovo, 20/11/2026.)"""

from __future__ import annotations

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.urgency_classifier import (
    UrgencyClassifier,
    UrgencyVerdict,
)
from packages.core.domain.safety.harmful_requests import OFF_TOPIC_TEXTS
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class _Classifier(UrgencyClassifier):
    def __init__(self, topic: str | None) -> None:  # noqa: D107
        self.topic = topic

    def classify(self, message: str, species: str) -> UrgencyVerdict | None:
        return UrgencyVerdict(level="normal", topic=self.topic)


def _ask(
    message: str, *, topic: str | None = None
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = RecordingLLMClient("Risposta di prova, concreta e breve.")
    orchestrator = ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        urgency_classifier=_Classifier(topic),
    )
    result = orchestrator.answer(
        ChatOrchestratorInput(user_message=message, species="Cane", pet_name="Toby")
    )
    return result, llm


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
