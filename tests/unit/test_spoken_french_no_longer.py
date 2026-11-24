"""Spoken French: "mange plus" without "ne" means "no longer eats"."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.common.spoken_french import says_no_longer_in_spoken_french

_WHOLE = "Une grenouille qui ne mange plus depuis dix jours doit être vue par un vétérinaire."


@pytest.mark.parametrize(
    "message",
    [
        "ma grenouille cornue mange plus depuis 10 jours, le terrarium est à 24 °C c trop froid ?",
        "Mon chat boit plus depuis hier",
        "mon lapin bouge plus, il est dans son coin",
        "mes poules pondent plus du tout",
        "il fait plus caca",
        "Elle veut plus manger",
    ],
)
def test_a_dropped_ne_is_recognised(message: str) -> None:
    assert says_no_longer_in_spoken_french(message)


@pytest.mark.parametrize(
    "message",
    [
        "Mon chat mange plus que d'habitude",
        "Il mange plus de croquettes que son frère",
        "Elle dort plus longtemps depuis l'hiver",
        "Il court plus vite qu'avant",
        "Ma cavia ne veut plus toucher au foin",
        "Ma rainette ne sort plus de sa cachette",
        "Elle n'est plus malade",
        "Il mange bien.",
        "Mi gato no come más",
        "Il cane mangia di più",
    ],
)
def test_a_comparison_or_a_full_negation_is_not(message: str) -> None:
    assert not says_no_longer_in_spoken_french(message)


def test_the_rule_travels_only_with_such_a_message() -> None:
    def prompt(message: str) -> str:
        client = CuttingClient(answer=[(_WHOLE, "stop")])
        _ask(client, message, name="Gren", species="Rettili e anfibi", language="fr")
        (request,) = client.of("answer")
        return str(request.system_prompt)

    assert "SPOKEN FRENCH" in prompt("ma grenouille mange plus depuis 10 jours, c'est grave ?")
    assert "SPOKEN FRENCH" not in prompt("ma grenouille mange plus de grillons, c'est grave ?")
