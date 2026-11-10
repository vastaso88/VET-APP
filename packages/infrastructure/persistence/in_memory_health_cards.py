"""Approved health cards held in memory: tests, local runs, the evaluation.

The seed is empty on purpose: cards come from the manual project and are
approved by the owner before they exist anywhere (stage 2 of the plan).
"""

from __future__ import annotations

from collections.abc import Iterable

from packages.core.application.ports.health_card_repository import HealthCardRepository
from packages.core.domain.knowledge.health_cards import HealthCard, score


class InMemoryHealthCardRepository(HealthCardRepository):
    def __init__(self, cards: Iterable[HealthCard] = ()) -> None:
        self._cards = list(cards)

    def add(self, card: HealthCard) -> None:
        self._cards.append(card)

    def search(self, *, species: str, query: str, limit: int = 10) -> list[HealthCard]:
        scored = [(score(card, query), card) for card in self._cards if card.applies_to(species)]
        ranked = sorted(
            ((points, card) for points, card in scored if points > 0),
            key=lambda pair: -pair[0],
        )
        return [card for _, card in ranked[:limit]]
