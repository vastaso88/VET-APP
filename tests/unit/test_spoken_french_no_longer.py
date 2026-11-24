"""Spoken French: "mange plus" without "ne" means "no longer eats"."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.domain.common.spoken_french import (
    IF_IT_NO_LONGER_DRINKS_OR_URINATES,
    says_no_longer_in_spoken_french,
)

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
        "ça fait 3 jours qu'il boit plus et qu'il urine plus",
        "mon lapin mange pu",
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


_DRINKS = "ça fait 3 jours qu'il boit plus et qu'il urine plus"


def _french_answer(message: str, reply: str) -> str:
    client = CuttingClient(answer=[(reply, "stop")])
    return str(_ask(client, message, name="Tigrou", species="Gatto", language="fr").answer)


def test_the_urgent_reading_is_said_when_the_reply_misses_it() -> None:
    reply = (
        "Boire et uriner davantage pendant trois jours chez un chat mérite un examen. Prenez "
        "rendez-vous avec le vétérinaire dans les prochains jours et gardez l'eau à disposition."
    )
    answer = _french_answer(_DRINKS, reply)
    assert answer.startswith(IF_IT_NO_LONGER_DRINKS_OR_URINATES.strip())
    assert "davantage" in answer


def test_nothing_is_added_when_the_reply_already_says_it() -> None:
    reply = (
        "Si Tigrou ne boit plus ou n'urine plus, appelez le vétérinaire maintenant. S'il boit "
        "davantage, prenez rendez-vous dans les prochains jours et gardez l'eau à disposition."
    )
    assert not _french_answer(_DRINKS, reply).startswith("Si vous voulez dire")


def test_the_sentence_is_only_for_drinking_and_urinating_in_french() -> None:
    reply = (
        "Une grenouille qui ne mange plus depuis dix jours doit être vue par un vétérinaire "
        "aujourd'hui, sans attendre, et vous pouvez vérifier la température du terrarium."
    )
    assert not _french_answer("ma grenouille mange plus depuis 10 jours", reply).startswith(
        "Si vous voulez dire"
    )
