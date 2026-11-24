"""What gives an owner their daily question back: a failure of ours, never an answer."""

from __future__ import annotations

from pathlib import Path

import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestratorResult
from packages.core.application.services.send_chat_message import not_answered
from packages.core.application.services.upload_chat_attachment import provider_rejected_the_file
from packages.core.domain.conversation.states import ConversationState
from packages.infrastructure.llm.providers import anthropic_llm_client, groq_chat_api
from packages.infrastructure.speech import groq_speech_to_text_provider
from packages.shared.errors.base import ProviderError


def _result(**fields: object) -> ChatOrchestratorResult:
    return ChatOrchestratorResult.model_validate(
        {
            "answer": "testo",
            "mode": "evidence",
            "confidence": "low",
            "ai_generated": False,
            "recommended_action": "",
            "provider": "rule-based",
            "model": "evidence-guard",
            "state": ConversationState.RETRIEVAL_FAILURE,
        }
        | fields
    )


def test_a_failure_of_the_provider_gives_the_question_back() -> None:
    assert not_answered(_result())
    assert not_answered(_result(model="natural-answer-guard", mode="natural"))
    assert not_answered(_result(model="m", mode="quota_exhausted"))


def test_no_source_about_the_question_is_an_answer_and_counts() -> None:
    assert not not_answered(_result(state=ConversationState.INSUFFICIENT_EVIDENCE))


def test_an_ordinary_answer_counts() -> None:
    assert not not_answered(
        _result(model="m", mode="natural", state=ConversationState.NO_RELEVANT_SOURCES)
    )


@pytest.mark.parametrize(
    "text",
    [
        # the sentences the three clients write: the rule reads the status from them
        "Anthropic request failed with status 413",
        "Groq vision request failed with status 400: too large",
        "Groq transcription failed with status 415: unsupported",
    ],
)
def test_a_refused_file_is_the_owners_doing(text: str) -> None:
    assert provider_rejected_the_file(ProviderError(text))


@pytest.mark.parametrize("status", [401, 403, 429, 500, 503])
def test_an_outage_is_not(status: int) -> None:
    assert not provider_rejected_the_file(
        ProviderError(f"Groq request failed with status {status}")
    )


def test_the_clients_still_write_the_status_the_rule_reads() -> None:
    for module in (anthropic_llm_client, groq_chat_api, groq_speech_to_text_provider):
        source = Path(str(module.__file__)).read_text("utf-8")
        assert "failed with status {exc." in source, module.__name__
