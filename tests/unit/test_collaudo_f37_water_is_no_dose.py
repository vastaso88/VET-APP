"""Collaudo F37: an amount of water or milk is not a dose ("how many mls of water in the dish"
was answered with the refusal of doses, then with the figure). A medicine asked in the same
message is still a dose."""

from __future__ import annotations

import pytest

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.domain.safety.dosage_request import asks_an_amount, is_dosage_request


@pytest.mark.parametrize(
    "message",
    [
        "heatwave in Sydney, is 77°F ok for a horned frog? and how many mls of water in the dish?",
        "Quanti ml di acqua deve bere al giorno?",
        "Quanta acqua gli metto nella ciotola?",
        "Quanto latte di capra do al gattino?",
        "Wie viel ml Wasser braucht er am Tag?",
        "Combien de ml d'eau par jour ?",
        "¿Cuánta agua debe beber al día?",
    ],
)
def test_water_or_milk_is_no_dose(message: str) -> None:
    assert not ChatOrchestrator._is_dosage_request(message.lower())
    assert not is_dosage_request(message) and not asks_an_amount(message)


@pytest.mark.parametrize(
    "message",
    [
        "Quanti ml di paracetamolo gli do con l'acqua?",
        "How many ml of paracetamol in the water?",
        "Quante gocce di antibiotico nell'acqua gli do?",
        "Wie viel ml Schmerzmittel gebe ich ins Wasser?",
        "Quanti mg di antidolorifico per 30 kg?",
    ],
)
def test_a_medicine_stays_a_dose_even_with_water_in_the_message(message: str) -> None:
    assert ChatOrchestrator._is_dosage_request(message.lower()) or asks_an_amount(message)
