"""A small mammal that stops eating is never made to wait a day (measure of 24/11/2026)."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.safety.waiting_small_mammal import without_a_waiting_day


@pytest.mark.parametrize(
    ("said", "kept"),
    [
        (
            "Tienilo d'occhio: se smette di mangiare o fa meno cacchine del solito per più di un "
            "giorno, portalo dal veterinario oggi stesso.",
            "Tienilo d'occhio: se smette di mangiare o fa meno cacchine del solito, portalo dal "
            "veterinario oggi stesso.",
        ),
        (
            "Se non mangia da oltre 24 ore, chiama il veterinario.",
            "Se non mangia, chiama il veterinario.",
        ),
        (
            "If he stops eating for more than a day, take him to the vet.",
            "If he stops eating, take him to the vet.",
        ),
        ("Si deja de comer durante más de un día, llévalo.", "Si deja de comer, llévalo."),
        (
            "Se smette di mangiare o non fa più feci per tutto un giorno, è un'emergenza.",
            "Se smette di mangiare o non fa più feci, è un'emergenza.",
        ),
        (
            "Wenn er länger als einen Tag nicht frisst, ruf in der Praxis an.",
            "Wenn er nicht frisst, ruf in der Praxis an.",
        ),
        (
            "Wenn er mehr als 24 Stunden nichts mehr frisst, geh hin.",
            "Wenn er nichts mehr frisst, geh hin.",
        ),
        ("S'il ne mange rien depuis 24 heures, allez-y.", "S'il ne mange rien, allez-y."),
    ],
)
def test_the_waiting_goes_and_the_advice_stays(said: str, kept: str) -> None:
    assert without_a_waiting_day(said, "small_mammal") == kept


@pytest.mark.parametrize(
    "text",
    [
        "Cambia il fieno ogni giorno, per due giorni.",
        "Se non mangia per 12 ore, portalo dal veterinario.",
        "Introduci una verdura nuova per tre giorni e guarda se la mangia.",
        "Give a new vegetable for two days.",
        "Se smette di mangiare, portalo subito.\n\nFieno sempre a disposizione.",
    ],
)
def test_other_durations_are_left_alone(text: str) -> None:
    assert without_a_waiting_day(text, "small_mammal") == text


def test_only_small_mammals() -> None:
    text = "Se non mangia da oltre 24 ore, chiama il veterinario."
    assert without_a_waiting_day(text, "dog") == text


@pytest.mark.parametrize("species", ["Piccoli mammiferi", "Cane"])
def test_the_answer_path_uses_the_species_of_the_message_not_only_the_profile(
    species: str,
) -> None:
    # A question on a rabbit asked with a dog's profile open (the bench's h- cases, 24/11/2026).
    reply = (
        "Pane e pasta non vanno bene: la base è il fieno, con poche verdure. Se il coniglio "
        "smette di mangiare o fa meno feci per più di un giorno, portalo dal veterinario subito."
    )
    client = CuttingClient(answer=[(reply, "stop")])
    result = _ask(
        client,
        "Il pane secco posso darlo al coniglio?",
        species=species,
        name="Toby",
    )
    assert "per più di un giorno" not in result.answer and "portalo" in result.answer
