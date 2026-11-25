"""No service reads the photos (owner decision 2026-11-25): the photo is saved,
nothing is sent, nothing is invented, the chat says it cannot see it.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.bootstrap.container import ApplicationContainer
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.localization import translate
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.vision.disabled_image_analyzer import (
    DisabledImageAnalyzer,
    PhotoReadingOff,
)
from packages.infrastructure.vision.echo_image_analyzer import EchoImageAnalyzer
from packages.shared.config.settings import Settings

# --- which analyzer -------------------------------------------------------------------------


@pytest.mark.parametrize("value", ["off", "groq", "a-service-of-the-past", ""])
def test_anything_but_the_local_stand_in_is_off(value: str) -> None:
    container = ApplicationContainer(Settings(VISION_PROVIDER=value))

    assert isinstance(container.image_analyzer, DisabledImageAnalyzer)
    assert container.photo_reading_enabled is False


def test_an_unknown_value_is_said_in_the_log_without_the_value(
    caplog: pytest.LogCaptureFixture,
) -> None:
    ApplicationContainer(Settings(VISION_PROVIDER="some-value-of-the-past"))

    assert "VISION_PROVIDER" in caplog.text
    assert "some-value-of-the-past" not in caplog.text


def test_the_stand_in_is_for_local_work_only() -> None:
    settings = Settings(VISION_PROVIDER="echo")

    local = ApplicationContainer(settings)
    production = ApplicationContainer(settings.model_copy(update={"environment": "production"}))

    assert isinstance(local.image_analyzer, EchoImageAnalyzer)
    assert isinstance(production.image_analyzer, DisabledImageAnalyzer)


def test_the_disabled_analyzer_sends_nothing_and_invents_nothing() -> None:
    with pytest.raises(PhotoReadingOff):
        DisabledImageAnalyzer().analyze(b"\xff\xd8", "image/jpeg", context="")


# --- the chat is honest ---------------------------------------------------------------------


def _ask(message: str, client: RecordingLLMClient | None = None) -> tuple[str, RecordingLLMClient]:
    llm = client or RecordingLLMClient()
    result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message, species="Cane", pet_name="Rex", photo_reading_off=True
        )
    )
    return result.answer, llm


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_the_honest_sentence_exists_in_every_language(language: str) -> None:
    text = translate("photo_reading_off", language)
    assert text and "{" not in text


def test_a_photo_alone_gets_the_honest_sentence_and_no_model_call() -> None:
    answer, client = _ask("")
    assert answer == translate("photo_reading_off", "it")
    assert client.requests == []


def test_a_photo_with_a_question_opens_with_the_sentence_and_the_model_knows_nothing() -> None:
    answer, client = _ask(
        "cosa ne pensi di questa macchia sulla pelle?",
        RecordingLLMClient("Una macchia sulla pelle può avere molte cause."),
    )
    # no document is named: the notice without its clause on booklets and reports (T10)
    assert answer.startswith("Per ora non posso vedere il contenuto delle foto")
    assert "Descrivimi a parole cosa vedi." in answer and "libretto" not in answer
    prompt = client.requests_for("answer")[-1].user_prompt
    assert "photo reading is switched off" in prompt
    assert "Never describe it or guess" in prompt
