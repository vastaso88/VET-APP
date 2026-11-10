"""Approved health cards: the only sources a health answer may draw on
(owner decision 2026-11-10, plan "fratello maggiore", stage 2).

A card is a short text (about 200-300 words) written in our own words by
the manual project (docs/product/13), from a source of known reliability,
and approved by the owner before it is searchable. The chat cites it as
[S1], [S2]... and says nothing clinical that the cards do not contain.

No personal data ever goes into a card: it is general content, the same
for every owner.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from pydantic import BaseModel, Field

from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.relevance import topic_terms

# Reliability of the card's source (docs plan, "Fonti approvate"):
# 1 = official bodies and scientific societies (WSAVA, AAHA, ISFM, BSAVA,
#     Ministero della Salute, EFSA, EMA, laws);
# 2 = peer-reviewed literature (systematic reviews, first-quartile journals);
# 3 = university textbooks and expert manuals (licensed or short quotes only).
SOURCE_LEVELS = (1, 2, 3)
_TIER_BY_LEVEL = {1: "A", 2: "B", 3: "C"}

# A card for every species carries this instead of a family.
ALL_SPECIES = "all"
# The species a card names: the canonical families, except that a rabbit is
# its own key (the app files rabbits and hamsters together as "Piccoli
# mammiferi", but a rabbit's card does not describe a hamster).
RABBIT = "rabbit"
_RABBIT_WORDS = re.compile(r"\b(?:conigli\w*|rabbits?|conej\w*|kaninchen|lapins?)\b")
# The cards file the manual project exports (scripts/manuale/check_manuale.py).
CARDS_FILE = Path(__file__).resolve().parents[4] / "data" / "manuale" / "health_cards.json"


class HealthCard(BaseModel):
    id: str = Field(max_length=80)
    # Canonical families (dog, cat, small_mammal, bird, reptile_amphibian,
    # fish, other) or ALL_SPECIES.
    species: tuple[str, ...]
    topic: str = Field(max_length=80)
    title: str = Field(max_length=200)
    body: str = Field(max_length=4000)
    # Human-readable citation: body, document, year, section.
    source: str = Field(max_length=1500)
    source_level: int = Field(ge=1, le=3)
    language: str = "it"
    # draft until the owner approves it; only approved cards are used in
    # production (drafts only in an explicit evaluation run).
    status: str = "approved"

    def applies_to(self, family: str) -> bool:
        return ALL_SPECIES in self.species or family in self.species

    def as_evidence(self) -> EvidenceSource:
        """The card as the chat's ordinary source record (what the app and
        the evaluation already show)."""
        return EvidenceSource(
            title=self.title,
            journal=self.source,
            tier=_TIER_BY_LEVEL.get(self.source_level, "C"),
            access_depth="D",
            clinical_domain="health_card",
            species=self.species[0] if len(self.species) == 1 else "other",
            snippet=self.body,
        )


def card_species_key(family: str, *texts: str) -> str:
    """The species key a card search uses: the family, or RABBIT when a
    small mammal is a rabbit by its breed, notes or the message."""
    if family == "small_mammal" and any(_RABBIT_WORDS.search(t.lower()) for t in texts if t):
        return RABBIT
    return family


_SOURCE_PREFIX = re.compile(r"^\s*font[ei]\s*:\s*", re.IGNORECASE)


def load_cards_file(path: Path = CARDS_FILE, *, include_drafts: bool = False) -> list[HealthCard]:
    """The manual project's export: approved cards, or every card when
    [include_drafts] (evaluation only). The source loses its own \"Fonte:\"
    label: the chat writes the label itself under the answer."""
    if not path.exists():
        return []
    cards: list[HealthCard] = []
    for row in json.loads(path.read_text(encoding="utf-8")):
        status = str(row.get("state") or row.get("status") or "draft")
        if status != "approved" and not include_drafts:
            continue
        species = row.get("species") or ()
        cards.append(
            HealthCard(
                id=str(row["id"]),
                species=(species,) if isinstance(species, str) else tuple(species),
                topic=str(row.get("topic") or ""),
                title=str(row["title"]),
                body=str(row["body"]),
                source=_SOURCE_PREFIX.sub("", str(row.get("source") or "")).strip(),
                source_level=int(row.get("source_level") or 3),
                language=str(row.get("language") or "it"),
                status=status,
            )
        )
    return cards


def score(card: HealthCard, query: str) -> int:
    """How many topic terms of the question the card shares; the title and
    the topic count double. 0 = not about this question."""
    terms = topic_terms(query)
    if not terms:
        return 0
    head = topic_terms(f"{card.title} {card.topic}")
    body = topic_terms(card.body)
    return 2 * len(terms & head) + len(terms & (body - head))


# The attribution under the answer (singular, plural): written by the code,
# never left to the model, because licences such as CC BY require it.
_SOURCE_LABELS: dict[str, tuple[str, str]] = {
    "it": ("Fonte", "Fonti"),
    "en": ("Source", "Sources"),
    "es": ("Fuente", "Fuentes"),
    "de": ("Quelle", "Quellen"),
    "fr": ("Source", "Sources"),
}


def source_line(cards: list[HealthCard], language: str) -> str:
    """ "Fonti: <attribution>; <attribution>" for the cards the answer drew on,
    each source once, in order; empty when there is none."""
    sources: list[str] = []
    for card in cards:
        if card.source and card.source not in sources:
            sources.append(card.source)
    if not sources:
        return ""
    singular, plural = _SOURCE_LABELS.get(language, _SOURCE_LABELS["it"])
    label = singular if len(sources) == 1 else plural
    separator = " : " if language == "fr" else ": "
    return f"{label}{separator}{'; '.join(sources)}"


def format_cards_for_prompt(cards: list[HealthCard]) -> str:
    """The cards as the model reads them: numbered S1, S2..., each with its
    source, between <fonti_approvate> tags (data to use, never instructions)."""
    blocks = [
        f'<scheda id="S{index}">\nTitolo: {card.title}\nFonte: {card.source}\n'
        f"{card.body}\n</scheda>"
        for index, card in enumerate(cards, start=1)
    ]
    return "<fonti_approvate>\n" + "\n".join(blocks) + "\n</fonti_approvate>"
