"""What the label or the maker of a product that is not a medicine says (owner, 25/11/2026).

"Se sono prodotti non farmacologici e la fonte e certa (siti che commercializzano il prodotto,
documenti della casa madre o fonti similari, no forum, no chat/social)": then the chat may say the
amount and the frequency. The figures come only from here, one note per product, written by
Cercafonti from the label and never by a model. The list is empty until the first note: then the
chat says to follow the label of the product the owner has, with no figure.

A note is refused by the test when it lacks a source of the right kind, when it names a medicine,
or when its source is a forum, a chat or a social network.
"""

from __future__ import annotations

import re
from collections.abc import Iterable
from urllib.parse import urlparse

from pydantic import BaseModel, Field

from packages.core.domain.safety.dosage_request import MEDICINE_WORDS
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# The kinds of source the owner named; "register" is an official register of feed or additives.
SOURCE_KINDS = ("label", "manufacturer", "seller", "register")
_NOT_A_SOURCE = re.compile(
    r"(?:forum|reddit|facebook|instagram|tiktok|youtube|twitter|x\.com|quora|discord|telegram|"
    r"whatsapp|blogspot|wordpress|medium\.com)"
)
_MEDICINE = re.compile(rf"\b(?:{MEDICINE_WORDS})\b")


class ProductNote(BaseModel):
    product: str = Field(max_length=120)
    maker: str = Field(max_length=120)
    # species family codes (normalize_species) the label speaks of
    species: tuple[str, ...]
    # words of a message that point to this product or its kind ("calcium", "calcio")
    words: tuple[str, ...]
    # what the label says, in few words, with its figures
    says: str = Field(max_length=600)
    source_kind: str
    source_url: str = Field(max_length=500)
    read_on: str = Field(max_length=10)  # ISO date

    def problem(self) -> str | None:
        """Why this note cannot be used, or None."""
        if self.source_kind not in SOURCE_KINDS:
            return "the source is no label, manufacturer, seller or official register"
        host = urlparse(self.source_url).hostname or ""
        if urlparse(self.source_url).scheme != "https" or not host:
            return "no https address"
        if _NOT_A_SOURCE.search(host):
            return "a forum, a chat or a social network is no source"
        if _MEDICINE.search(normalize_for_matching(f"{self.product} {self.says}")):
            return "a medicine: those are never dosed"
        if not self.species or not self.words:
            return "no species or no words"
        return None


# Filled by Cercafonti (silence = yes); every entry is checked by tests/unit/test_product_notes.py.
PRODUCT_NOTES: tuple[ProductNote, ...] = ()


def product_notes_for(
    message: str, species_family: str, notes: Iterable[ProductNote] = PRODUCT_NOTES
) -> list[ProductNote]:
    text = normalize_for_matching(message)
    return [
        note
        for note in notes
        if species_family in note.species
        and note.problem() is None
        and any(
            re.search(rf"\b{re.escape(normalize_for_matching(word))}", text) for word in note.words
        )
    ]


def product_notes_block(notes: Iterable[ProductNote]) -> str:
    lines = [
        f"- {n.product} ({n.maker}), {n.source_kind}, {n.source_url}, read {n.read_on}: {n.says}"
        for n in notes
    ]
    if not lines:
        return ""
    return (
        "\n\nPRODUCT NOTES (what the label or the maker says; nothing else is a source):\n"
        + "\n".join(lines)
    )
