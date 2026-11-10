from typing import Protocol

from packages.core.domain.knowledge.health_cards import HealthCard


class HealthCardRepository(Protocol):
    def search(self, *, species: str, query: str, limit: int = 10) -> list[HealthCard]:
        """Approved cards for this species family (or for every species)
        that share words with the question, best first. Never raises for
        "nothing found": an empty list."""
        ...
