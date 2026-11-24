"""Collaudo F36: an answer of the length the owner asked for."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.conversation.asked_length import asked_words

_LONG = "La cosa piu importante per il tuo cane e una routine tranquilla e regolare. " * 14
_SHORT = "Una routine tranquilla, acqua fresca, passeggiate brevi e un controllo all'anno."


@pytest.mark.parametrize(
    ("message", "expected"),
    [
        ("Riassumi in 3 righe", 42),
        ("Dimmelo in tre righe", 42),
        ("Summarise it in three lines", 42),
        ("In 5 parole", 25),
        ("In fifty words? No: in 50 words", 50),
        ("Rispondi in una frase", 30),
        ("Answer in one sentence", 30),
        ("Sag es kurz und bündig", 70),
        ("En bref, que faire ?", 70),
        ("Respuesta corta, por favor", 70),
        ("In breve: cosa devo fare?", 70),
    ],
)
def test_the_length_asked_is_read(message: str, expected: int) -> None:
    assert asked_words(message) == expected


@pytest.mark.parametrize(
    "message",
    [
        "Quante passeggiate brevi servono?",
        "Kurz nach dem Essen schläft er.",
        "Ha tre righe nere sul muso.",
        "He knows 3 words of English.",
        "Quanto deve mangiare?",
    ],
)
def test_other_messages_ask_for_no_length(message: str) -> None:
    assert asked_words(message) is None


def test_a_long_answer_is_brought_to_the_length_asked() -> None:
    client = CuttingClient(answer=[(_LONG, "stop")], shorten=[(_SHORT, "stop")])
    result = _ask(client, "Riassumi in 3 righe come gestire Rex", name="Rex", species="Cane")
    assert result.answer.startswith("Una routine")
    (request,) = client.of("shorten")
    assert "at most 42 words" in request.system_prompt
    (answer,) = client.of("answer")
    assert "THE OWNER ASKED FOR A SHORT ANSWER: about 42 words" in answer.system_prompt


def test_without_a_length_the_prompt_and_the_limit_are_as_before() -> None:
    client = CuttingClient(answer=[(_SHORT * 3, "stop")])
    _ask(client, "Come gestire Rex in casa?", name="Rex", species="Cane")
    (answer,) = client.of("answer")
    assert "SHORT ANSWER" not in answer.system_prompt
    assert client.of("shorten") == []
