"""Groq preview models are outside Groq's data agreement (docs/compliance/19,
2026-11-16): never in a chat chain, as the light model or for photos. And
photo reading switched off is honest: the photo is saved, nothing is sent,
nothing is invented, the chat says it cannot see it.
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
from packages.infrastructure.vision.groq_image_analyzer import GroqImageAnalyzer
from packages.shared.config.groq_models import (
    GROQ_PREVIEW_MODELS,
    GROQ_PRODUCTION_MODELS,
    production_models_only,
)
from packages.shared.config.settings import Settings

PREVIEW = "qwen/qwen3.8-27b"
CHAINS = ("llm_fallback_models", "llm_light_fallback_models", "vision_fallback_models")


def _names(chain: str) -> list[str]:
    return [name.strip() for name in chain.split(",") if name.strip()]


# --- the models -----------------------------------------------------------------------------------


def test_no_preview_model_is_a_default_anywhere() -> None:
    defaults = {name: Settings.model_fields[name].default for name in CHAINS}
    defaults["llm_model_light"] = Settings.model_fields["llm_model_light"].default
    defaults["vision_model"] = Settings.model_fields["vision_model"].default
    for field, value in defaults.items():
        for model in _names(str(value)):
            assert model not in GROQ_PREVIEW_MODELS, (field, model)
            assert model in GROQ_PRODUCTION_MODELS, (field, model)


def test_preview_models_are_dropped_whatever_the_environment_says() -> None:
    settings = Settings(
        LLM_FALLBACK_MODELS=f"openai/gpt-oss-20b,{PREVIEW}",
        LLM_LIGHT_FALLBACK_MODELS=PREVIEW,
        VISION_FALLBACK_MODELS=PREVIEW,
        LLM_MODEL_LIGHT=PREVIEW,
    )
    for name in CHAINS:
        assert PREVIEW not in _names(getattr(settings, name)), name
    assert settings.llm_fallback_models == "openai/gpt-oss-20b"
    assert settings.llm_model_light == "openai/gpt-oss-20b"


def test_production_models_only_keeps_the_order() -> None:
    kept, dropped = production_models_only(
        f"llama-3.3-70b-versatile, {PREVIEW} ,openai/gpt-oss-20b"
    )
    assert kept == "llama-3.3-70b-versatile,openai/gpt-oss-20b"
    assert dropped == [PREVIEW]


# --- photo reading: which analyzer ----------------------------------------------------------------


@pytest.mark.parametrize("vision_model", [PREVIEW, ""])
def test_a_preview_or_missing_vision_model_switches_photo_reading_off(vision_model: str) -> None:
    container = ApplicationContainer(
        Settings(VISION_PROVIDER="groq", VISION_MODEL=vision_model, LLM_API_KEY="test-key")
    )
    assert isinstance(container.image_analyzer, DisabledImageAnalyzer)
    assert container.photo_reading_enabled is False


def test_off_is_off() -> None:
    container = ApplicationContainer(Settings(VISION_PROVIDER="off"))
    assert isinstance(container.image_analyzer, DisabledImageAnalyzer)


def test_a_production_vision_model_on_groq_is_still_allowed() -> None:
    model = "llama-3.3-70b-versatile"  # any name of the production list
    container = ApplicationContainer(
        Settings(VISION_PROVIDER="groq", VISION_MODEL=model, LLM_API_KEY="test-key")
    )
    assert isinstance(container.image_analyzer, GroqImageAnalyzer)


def test_the_demo_analyzer_never_runs_outside_local_work() -> None:
    local = ApplicationContainer(Settings(VISION_PROVIDER="echo"))
    assert isinstance(local.image_analyzer, EchoImageAnalyzer)


def test_the_disabled_analyzer_sends_nothing_and_invents_nothing() -> None:
    with pytest.raises(PhotoReadingOff):
        DisabledImageAnalyzer().analyze(b"\xff\xd8", "image/jpeg", context="")


# --- photo reading off: the chat is honest ------------------------------------------------


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
    assert answer.startswith(translate("photo_reading_off", "it"))
    prompt = client.requests_for("answer")[-1].user_prompt
    assert "photo reading is switched off" in prompt
    assert "Never describe it or guess" in prompt
