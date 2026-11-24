"""Collaudo, wave 2 (K24): "ok and the wheel size?" was taken for a greeting and the question was
lost. Small talk is what is ONLY a greeting, a thanks or an ok, in any of the five languages.
On 1388 messages of the collaudo and of the 1200 questions, two change routing: both are the
reported ones."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.application.services.chat_orchestrator import ChatOrchestrator

# --- small talk that swallows a question (K24) --------------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "ok and the wheel size?",
        "hello, how big a cage?",
        "danke, und das Futter?",
        "grazie, e il vaccino?",
        "merci, et l'eau?",
        "gracias, y la comida?",
        "ok quanto deve dormire",
        "hallo, darf er Käse?",
    ],
)
def test_a_greeting_with_a_question_is_not_small_talk(message: str) -> None:
    assert ChatOrchestrator._classify_intent(message.lower()) != "general_info"


@pytest.mark.parametrize(
    "message",
    [
        "ciao",
        "Grazie mille!",
        "ok",
        "hello",
        "thank you",
        "danke",
        "hola",
        "bonjour",
        "merci beaucoup",
        "ciao, come va oggi?",
        "guten Morgen",
        "who are you",
        "wer bist du",
    ],
)
def test_only_a_greeting_is_small_talk(message: str) -> None:
    assert ChatOrchestrator._classify_intent(message.lower()) == "general_info"


def test_thanks_in_german_and_french_get_a_thanks_reply() -> None:
    for message, language in (("danke", "de"), ("merci", "fr"), ("thanks", "en")):
        client = CuttingClient(answer=[("x", "stop")])
        result = _ask(client, message, language=language)
        assert result.model == "small-talk"
        assert client.of("answer") == []
