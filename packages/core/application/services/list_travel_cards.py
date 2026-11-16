"""Around the world: every approved travel card, for the phone to choose from.

The service takes no filter on purpose: the app downloads the whole set and
picks the country and the species on the device, so the server never learns
where a person is thinking of going (docs/compliance/17 A.14). A card older
than ``HIDDEN_AFTER_DAYS`` is sent without its content, only with the link to
the official source.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import date

from packages.core.domain.common.entity import utc_now
from packages.core.domain.travel.cards import TravelCard


class ListTravelCardsService:
    def __init__(
        self,
        cards: list[TravelCard],
        *,
        today: Callable[[], date] = lambda: utc_now().date(),
    ) -> None:
        self._cards = cards
        self._today = today

    def execute(self) -> list[dict[str, object]]:
        today = self._today()
        return [_payload(card, today) for card in self._cards]


def _payload(card: TravelCard, today: date) -> dict[str, object]:
    visibility = card.visibility(today)
    payload: dict[str, object] = {
        "id": card.id,
        "country": card.country,
        "species": card.species,
        "title": card.title,
        "checked_on": card.checked_on.isoformat(),
        "official_url": card.official_url,
        "visibility": visibility,
    }
    if visibility == "hidden":
        return payload
    payload["blocks"] = [
        {
            "kind": block.kind,
            "title": block.title,
            "sentences": [
                {
                    "text": sentence.text,
                    "origins": list(sentence.origins),
                    "own": sentence.own,
                    "source_ids": list(sentence.source_ids),
                }
                for sentence in block.sentences
            ],
        }
        for block in card.blocks
    ]
    payload["sources"] = [
        {"id": s.id, "citation": s.citation, "url": s.url, "checked_on": s.checked_on.isoformat()}
        for s in card.sources
    ]
    return payload
