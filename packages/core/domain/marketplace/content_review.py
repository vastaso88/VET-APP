"""Words that need a confirmation on the Mercatino, and the check by the team (owner
decisions of 2026-11-23; rules: docs/compliance/24).

An ad whose text names food, feed, snacks or supplements, or an ambiguous word such as
"antipulci" or "shampoo" (a comb and a normal shampoo are allowed), is not refused. The
seller reads a notice (one for food and supplements, one for active substances), ticks its
box, and the ad is published at once. The team checks it afterwards and may take it down;
if nobody acts, it stays.

Medicines and the unequivocal products with an active substance are refused outright
(content_policy.py). The words live here only: the app shows what the backend answers,
so there is no second list to keep aligned."""

from __future__ import annotations

import re
from collections.abc import Iterable
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.marketplace.animal_policy import normalize_text

# What the API answers (400) when the text needs the confirmation.
CONTENT_CONFIRMATION_REQUIRED = "content_confirmation_required"
# The wording of the boxes the seller ticks (app keys marketplaceReviewConfirm*):
# change it together with the text.
CONTENT_CONFIRMATION_VERSION = "2026-11-23"

# "treatment": an ambiguous word that may or may not name a product with an active
# substance.
SensitiveKind = Literal["food", "supplement", "treatment"]
# Each notice has its own text and its own box.
ContentNotice = Literal["food", "active_substance"]
_NOTICE_OF_KIND: dict[SensitiveKind, ContentNotice] = {
    "food": "food",
    "supplement": "food",
    "treatment": "active_substance",
}
# open: to be checked; checked: the team looked and left it; removed: the team took the
# ad down; superseded: the text changed before anyone decided.
ListingReviewStatus = Literal["open", "checked", "removed", "superseded"]
# Why the team took it down: a code, so the seller reads it in their language; the
# team's own words go in the note, never shown to them.
RemovalReason = Literal["food", "supplement", "medicine", "other"]
DecisionOutcome = Literal["checked", "removed", "restored"]

# Normalised (lowercase, no accents) whole words, it/en/es/de/fr. A word here costs the
# seller one confirmation, never a refusal, so the list may be generous; words that
# mostly mean something else stay out ("umido", "semi" alone, "latte" alone).
_FOOD_WORDS = frozenset(
    (
        # it
        "cibo cibi crocchetta crocchette croccantino croccantini mangime mangimi alimento "
        "alimenti scatoletta scatolette snack snacks premietto premietti biscotto biscotti "
        "bocconcini fieno granaglie pellet masticativo masticativi masticabile masticabili "
        # en
        "food foods kibble kibbles treat treats feed hay birdseed seeds biscuit biscuits "
        "pellets chews "
        # es
        "comida comidas pienso piensos croqueta croquetas chuche chuches golosina golosinas "
        "heno semillas galleta galletas latitas "
        # de
        "futter futtermittel leckerli leckerlis leckerchen leckereien heu nahrung kekse "
        # fr
        "nourriture croquette croquettes patee patees friandise friandises aliment aliments "
        "foin graines"
    ).split()
)
# German compounds end with the word: "Trockenfutter", "Hundefutter", "Kausnacks". One
# that starts with it is an accessory ("Futternapf", "Futterspender") and does not match.
_FOOD_PATTERN = re.compile(r"[a-z]+(?:futter|futtermittel|leckerlis?|snacks?|nahrung)")
_FOOD_PHRASES = (
    ("semi", "per"),
    ("misto", "semi"),
    ("miscela", "di", "semi"),
    ("umido", "per"),
    ("premi", "per"),
    ("premi", "da"),
    ("latte", "in", "polvere"),
    ("osso", "da", "masticare"),
    ("ossa", "da", "masticare"),
    ("osso", "di", "pelle"),
    ("ossa", "di", "pelle"),
    ("osso", "di", "bufalo"),
    ("ossa", "di", "bufalo"),
    ("rawhide", "bone"),
    ("rawhide", "bones"),
    ("milk", "replacer"),
    ("leche", "en", "polvo"),
    ("lait", "en", "poudre"),
)
_SUPPLEMENT_WORDS = frozenset(
    (
        "integratore integratori vitamina vitamine probiotico probiotici condroprotettore "
        "condroprotettori "
        "supplement supplements vitamin vitamins probiotic probiotics "
        "suplemento suplementos vitaminas "
        "nahrungserganzung nahrungserganzungsmittel erganzungsfutter erganzungsfuttermittel "
        "lachsol probiotikum probiotika "
        "probiotique probiotiques"
    ).split()
)
_SUPPLEMENT_PHRASES = (
    ("omega", "3"),
    ("pasta", "al", "malto"),
    ("malt", "paste"),
    ("olio", "di", "salmone"),
    ("olio", "di", "pesce"),
    ("salmon", "oil"),
    ("fish", "oil"),
    ("aceite", "de", "salmon"),
    ("huile", "de", "saumon"),
    ("complement", "alimentaire"),
    ("complements", "alimentaires"),
)
# Ambiguous on their own (owner answer 1A of 2026-11-23): "pettine antipulci", "shampoo
# delicato", "flea comb". The unequivocal products are refused before this is reached.
_TREATMENT_WORDS = frozenset(
    (
        "antipulci antizecche pulci zecche antiparassitario antiparassitari antiparassitaria "
        "antiparassitarie shampoo shampoos shampo pipetta pipette pipettes "
        "flea fleas tick ticks antiparasitic antiparasitics "
        "antipulgas antigarrapatas pulgas garrapatas antiparasitario antiparasitarios champu "
        "champus pipeta pipetas "
        "flohe zecken flohschutz zeckenschutz flohkamm zeckenzange zeckenkarte antiparasitikum "
        "antiparasitika "
        "antipuces antitiques puces tiques antiparasitaire antiparasitaires shampooing "
        "shampooings shampoing shampoings"
    ).split()
)
_TREATMENT_PHRASES = (
    ("anti", "parassitario"),
    ("anti", "parassitari"),
    ("anti", "floh"),
    ("anti", "zecken"),
    ("spot", "on"),
)
# "pienso que..." is "I think that..." in Spanish, not feed; the rest are flea markets.
_NOT_SENSITIVE_PHRASES = (
    ("pienso", "que"),
    ("mercatino", "delle", "pulci"),
    ("mercato", "delle", "pulci"),
    ("flea", "market"),
    ("mercado", "de", "pulgas"),
    ("mercadillo", "de", "pulgas"),
    ("marche", "aux", "puces"),
)
_PHRASES: tuple[tuple[SensitiveKind, tuple[tuple[str, ...], ...]], ...] = (
    ("food", _FOOD_PHRASES),
    ("supplement", _SUPPLEMENT_PHRASES),
    ("treatment", _TREATMENT_PHRASES),
)

# Categories of older builds that are food or health products by name.
_SENSITIVE_CATEGORIES: dict[str, SensitiveKind] = {
    "food": "food",
    "health_wellness": "supplement",
}

_WORD = re.compile(r"[^\W_]+")


class SensitiveTerm(BaseModel):
    """One word or phrase of the ad, as the seller wrote it."""

    kind: SensitiveKind
    text: str

    @property
    def notice(self) -> ContentNotice:
        return _NOTICE_OF_KIND[self.kind]


class _Hit(BaseModel):
    kind: SensitiveKind
    start: int
    end: int


def _kind_of(word: str) -> SensitiveKind | None:
    if word in _SUPPLEMENT_WORDS:
        return "supplement"
    if word in _FOOD_WORDS or _FOOD_PATTERN.fullmatch(word):
        return "food"
    if word in _TREATMENT_WORDS:
        return "treatment"
    return None


def _hits(text: str) -> list[_Hit]:
    tokens = [
        (normalize_text(match.group()), match.start(), match.end())
        for match in _WORD.finditer(text)
    ]
    words = [word for word, _, _ in tokens]

    def starts(phrase: tuple[str, ...], index: int) -> bool:
        return tuple(words[index : index + len(phrase)]) == phrase

    found: list[_Hit] = []
    index = 0
    while index < len(tokens):
        skipped = next((p for p in _NOT_SENSITIVE_PHRASES if starts(p, index)), None)
        if skipped is not None:
            index += len(skipped)
            continue
        kind, step = _kind_of(words[index]), 1
        for phrase_kind, phrases in _PHRASES:
            for phrase in phrases:
                if len(phrase) > step and starts(phrase, index):
                    kind, step = phrase_kind, len(phrase)
        if kind is not None:
            found.append(_Hit(kind=kind, start=tokens[index][1], end=tokens[index + step - 1][2]))
        index += step
    return found


def sensitive_terms(*texts: str | None, category: str | None = None) -> list[SensitiveTerm]:
    """What in the ad calls for the confirmation, each word once. A legacy food or
    health category counts even when the text names nothing."""
    found: dict[str, SensitiveTerm] = {}
    for text in texts:
        if not text:
            continue
        for hit in _hits(text):
            written = text[hit.start : hit.end]
            found.setdefault(normalize_text(written), SensitiveTerm(kind=hit.kind, text=written))
    category_kind = _SENSITIVE_CATEGORIES.get(category or "")
    if category_kind is not None and not found:
        found[category or ""] = SensitiveTerm(kind=category_kind, text=category or "")
    return list(found.values())


def notices_for(terms: list[SensitiveTerm]) -> list[ContentNotice]:
    """Which notices these words call for, food first."""
    wanted = {term.notice for term in terms}
    order: tuple[ContentNotice, ...] = ("food", "active_substance")
    return [notice for notice in order if notice in wanted]


def highlighted(text: str | None) -> list[dict[str, object]]:
    """[text] in pieces, the sensitive ones marked: what the portal shows without having
    to know the words."""
    if not text:
        return []
    pieces: list[dict[str, object]] = []
    position = 0
    for hit in _hits(text):
        if hit.start > position:
            pieces.append({"text": text[position : hit.start], "hit": False})
        pieces.append({"text": text[hit.start : hit.end], "hit": True})
        position = hit.end
    if position < len(text):
        pieces.append({"text": text[position:], "hit": False})
    return pieces


class ListingReview(BaseModel):
    """The seller's confirmation of one text of an ad, and what the team did with it. It
    keeps what was confirmed, so a decision is never applied to something else."""

    id: str = Field(default_factory=new_id)
    listing_id: str
    owner_id: str
    status: ListingReviewStatus = "open"
    title: str
    description: str | None = None
    category: str
    photo_urls: list[str] = Field(default_factory=list)
    terms: list[str] = Field(default_factory=list)
    # Which boxes the seller ticked.
    notices: list[ContentNotice] = Field(default_factory=list)
    confirmed_at: datetime = Field(default_factory=utc_now)
    confirmation_version: str = CONTENT_CONFIRMATION_VERSION
    decided_at: datetime | None = None
    decided_by_admin_id: str | None = None
    removal_reason: RemovalReason | None = None
    note: str | None = Field(default=None, max_length=1000)

    def covers(
        self, title: str, description: str | None, category: str, photo_urls: list[str]
    ) -> bool:
        """True when this confirmation is about exactly this text and these photos (a new
        price alone does not need another one)."""
        return (self.title, self.description or "", self.category, self.photo_urls) == (
            title,
            description or "",
            category,
            photo_urls,
        )


class ListingDecision(BaseModel):
    """The team's register of decisions: 24 months, without the text and without the id
    of the seller (docs/compliance/24), so it outlives the ad and the account."""

    id: str = Field(default_factory=new_id)
    listing_id: str
    outcome: DecisionOutcome
    reason: RemovalReason | None = None
    admin_id: str
    decided_at: datetime = Field(default_factory=utc_now)


def latest_by_listing(reviews: Iterable[ListingReview]) -> dict[str, ListingReview]:
    latest: dict[str, ListingReview] = {}
    for review in reviews:
        current = latest.get(review.listing_id)
        if current is None or review.confirmed_at > current.confirmed_at:
            latest[review.listing_id] = review
    return latest
