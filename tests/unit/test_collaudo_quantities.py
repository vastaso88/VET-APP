"""Collaudo, wave 2 (K26, K27): an amount of food or water that no source, owner or profile gives
is not said. Read again on 24/11/2026 on 183 real replies: 9 alarms, all of the intended kind."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.knowledge.quantities import (
    unsourced_quantities,
    without_unsourced_quantities,
)

# --- quantities (K26, K27) ---------------------------------------------------------------------


@pytest.mark.parametrize(
    "sentence",
    [
        "Per un Labrador di 30 kg servono 600-900 g di cibo secco al giorno.",
        "Dai il 2-3% del peso in cibo secco.",
        "Una ciotola d'acqua da 200 ml basta.",
        "Per un pesce rosso servono almeno 75-100 litri nella vasca.",
        "About 10 gallons of water per inch of shell.",
        "Give one cup of kibble per 10 kg.",
        "Ein Aquarium mit mindestens 100 Litern Wasser ist nötig.",
        "La dose quotidienne est de 300 g de croquettes.",
        "Necesita unos 120 litros de agua en el acuario.",
        "Dagli mezza tazza di verdura al giorno.",
    ],
)
def test_an_amount_of_food_or_water_with_no_source_loses_its_sentence(sentence: str) -> None:
    text = f"Osservalo con calma. {sentence}"
    assert without_unsourced_quantities(text, "Rex, labrador, 30 kg") == "Osservalo con calma."


@pytest.mark.parametrize(
    "sentence",
    [
        "Dagli da mangiare due volte al giorno.",
        "Rex pesa 30 kg e ha 4 anni.",
        "Fai passeggiate di 40 minuti, due volte al giorno.",
        "La temperatura dell'acqua deve essere stabile.",
        "Tienilo al caldo e chiama il veterinario.",
    ],
)
def test_what_is_not_an_amount_of_food_or_water_stays(sentence: str) -> None:
    assert unsourced_quantities(sentence, "Rex, labrador, 30 kg") == []


def test_an_amount_the_owner_or_a_source_gives_stays() -> None:
    sentence = "I tuoi 300 g di secco al giorno sono nella norma."
    assert unsourced_quantities(sentence, "Mangia 2 volte al giorno 300 g di secco") == []
    tank = "Per una vasca di 60 litri serve un filtro adatto."
    assert unsourced_quantities(tank, "2 pesci in una vasca da 60 litri") == []


def test_the_answer_with_an_unsourced_ration_is_cut_end_to_end() -> None:
    reply = (
        "Un adulto mangia in genere due volte al giorno, e la cosa migliore è guardare il corpo. "
        "Il Labrador da 30 kg mangia 600-900 g di crocchette al giorno. Se le costole si sentono "
        "e la vita si vede dall'alto, la quantità va bene."
    )
    client = CuttingClient(answer=[(reply, "stop")])
    result = _ask(client, "Quanto mangia Rex, 30 kg?", species="Cane", name="Rex")
    assert "600" not in result.answer and "900" not in result.answer
    assert "due volte al giorno" in result.answer


def test_the_owners_own_ration_divided_into_meals_is_no_figure_of_the_model() -> None:
    known = "Mangia 2 volte al giorno 300 g di secco. È troppo?"
    assert unsourced_quantities("300 grammi al giorno, vuol dire 150 grammi a pasto.", known) == []
    # a weight in kilos divided by three is no ration
    assert unsourced_quantities("Servono 10 g di cibo al giorno.", "Rex pesa 30 kg.") != []


def test_a_cup_named_to_advise_against_it_is_no_quantity() -> None:
    assert (
        unsourced_quantities("Pesa la razione con una bilancia invece di usare una tazza.", "")
        == []
    )
