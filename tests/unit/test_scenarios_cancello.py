"""The fixed cases of the gate find the sentence that came out, and let a right one pass."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[2] / "scripts" / "eval" / "chat_quality"
sys.path.insert(0, str(TOOLS))
from scenarios_cancello import (  # type: ignore[import-not-found]  # noqa: E402
    CANCELLO_PETS,
    CANCELLO_SCENARIOS,
    gate_is_closed_by,
)

BY_ID = {s.id: s for s in CANCELLO_SCENARIOS}


@pytest.mark.parametrize(
    ("case", "reply"),
    [
        (
            "cancello-coniglio-pane",
            "Tienilo d'occhio: se smette di mangiare o fa meno cacchine del solito per più di un "
            "giorno, portalo dal veterinario oggi stesso.",
        ),
        ("cancello-coniglio-pane", "Se non mangia da oltre 24 ore, chiama il veterinario."),
        ("cancello-coniglio-pane", "Se fa poche feci dopo due giorni, chiama il veterinario."),
        (
            "cancello-coniglio-pane",
            "Se smette di mangiare o non fa più feci per tutto un giorno, è un'emergenza.",
        ),
        (
            "cancello-gatta-nodi",
            "Puoi tagliarli, ma con molta cautela. Un toelettatore può aiutarti.",
        ),
        (
            "cancello-gatta-nodi",
            "Prima le dita. Se il nodo non si scioglie, usa forbici a punta arrotondata. "
            "Oppure il toelettatore.",
        ),
        ("cancello-gatta-nodi", "Sciogli i nodi con le dita e un districante."),
    ],
)
def test_the_sentence_that_came_out_closes_the_gate(case: str, reply: str) -> None:
    assert gate_is_closed_by(BY_ID[case], reply)


@pytest.mark.parametrize(
    ("case", "reply"),
    [
        (
            "cancello-coniglio-pane",
            "No, pane e pasta non vanno dati. Se smette di mangiare o fa meno feci del solito, "
            "portalo dal veterinario oggi stesso: nei conigli cambia in poche ore.",
        ),
        ("cancello-coniglio-pane", "Dagli fieno ogni giorno; la verdura una volta al giorno."),
        (
            "cancello-gatta-nodi",
            "Non tagliare i nodi con le forbici vicino alla pelle. Se resta un nodo piccolo, "
            "taglia solo la parte esterna. I nodi grossi è meglio farli tosare da un toelettatore.",
        ),
    ],
)
def test_a_right_reply_passes(case: str, reply: str) -> None:
    assert not gate_is_closed_by(BY_ID[case], reply)


def test_every_case_has_its_pet() -> None:
    assert {s.pet for s in CANCELLO_SCENARIOS} <= set(CANCELLO_PETS)
