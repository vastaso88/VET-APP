"""Around the world: the travel cards (docs/product/18, docs/compliance/17 A).

A card is a short summary of the official rules for taking a dog, a cat or a
ferret to one country, written in our own words from an official source and
approved by the owner before the app shows it. It carries no personal data
and is the same for everybody, so the app downloads every approved card and
picks the one it needs on the phone: the pair of countries a person looks at
never reaches the server (privacy note A.14).

A card ages: after ``OLD_AFTER_DAYS`` the app warns that the rules may have
changed; after ``HIDDEN_AFTER_DAYS`` the content is not shown at all and only
the link to the official source remains.
"""

from __future__ import annotations

import json
from datetime import date, timedelta
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field

# The warning and the hiding of an old card (docs/compliance/17 A.5, A.12 C).
OLD_AFTER_DAYS = 90
HIDDEN_AFTER_DAYS = 180

TravelSpecies = Literal["dog", "cat", "ferret"]
# "EU" is the common card for every member state; otherwise an ISO 3166 code.
EU_CODE = "EU"
# Where the traveller starts from: a member state of the Union, or not.
Origin = Literal["EU", "non_EU"]

Visibility = Literal["fresh", "old", "hidden"]

# Where the manual project's export is written (scripts/manuale/check_manuale.py --viaggi).
TRAVEL_CARDS_FILE = (
    Path(__file__).resolve().parents[4] / "data" / "manuale" / "viaggi" / "travel_cards.json"
)


class TravelSource(BaseModel):
    id: str = Field(max_length=80)
    # The readable citation the app shows under the card ("Fonte: ...").
    citation: str = Field(max_length=1500)
    url: str = Field(max_length=500)
    checked_on: date


class TravelSentence(BaseModel):
    text: str = Field(max_length=1200)
    # Which origin it applies to; empty = both.
    origins: tuple[Origin, ...] = ()
    # Our own advice, not the source's (shown as such, at most 3 per card).
    own: bool = False
    source_ids: tuple[str, ...] = ()


class TravelBlock(BaseModel):
    kind: str = Field(max_length=40)
    title: str = Field(max_length=120)
    sentences: tuple[TravelSentence, ...]


class TravelCard(BaseModel):
    id: str = Field(max_length=80)
    country: str = Field(min_length=2, max_length=2)
    species: TravelSpecies
    title: str = Field(max_length=200)
    checked_on: date
    # The page of the official authority the app links when the card is old.
    official_url: str = Field(max_length=500)
    blocks: tuple[TravelBlock, ...] = ()
    sources: tuple[TravelSource, ...] = ()
    # "approved" cards only reach the app, unless an evaluation asks for drafts.
    status: Literal["draft", "approved"] = "draft"

    def age_days(self, today: date) -> int:
        return (today - self.checked_on).days

    def visibility(self, today: date) -> Visibility:
        age = self.age_days(today)
        if age > HIDDEN_AFTER_DAYS:
            return "hidden"
        if age > OLD_AFTER_DAYS:
            return "old"
        return "fresh"

    def expires_on(self) -> date:
        """The day after which the app warns that the card may be out of date."""
        return self.checked_on + timedelta(days=OLD_AFTER_DAYS)


def load_travel_cards(
    path: Path = TRAVEL_CARDS_FILE, *, include_drafts: bool = False
) -> list[TravelCard]:
    """The export of the manual project: approved cards, or every card when
    [include_drafts] (evaluation only)."""
    if not path.exists():
        return []
    cards = [TravelCard.model_validate(row) for row in json.loads(path.read_text("utf-8"))]
    return [card for card in cards if include_drafts or card.status == "approved"]
