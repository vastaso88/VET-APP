"""Which "curiosità" category (if any) a feed entry belongs to.

The feeds we read are general: veterinary bodies, animal-protection
associations and pet magazines also write about wildlife, hunting and
laboratory research, and several species words are also food or idioms
("coniglio alla cacciatora", "fare da cavia", "rana pescatrice"). So an entry
is kept only when its title or summary names a companion animal, and is
dropped when it reads like a recipe, a hunting piece or a game. This is the
same bar the app applied to Google News results before, moved server-side.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

# Titles/summaries containing any of these are dropped: food and recipe
# content (animals as ingredients), hunting, and known off-topic sources
# (a virtual-pet game, not real animals), laboratory experiments.
BLOCKED_KEYWORDS: tuple[str, ...] = (
    "ricetta",
    "ricette",
    "cucina",
    "cucinare",
    "cotto",
    "cottura",
    "arrosto",
    "spezzatino",
    "stufato",
    "brasato",
    "padella",
    "in forno",
    "al forno",
    "fritto",
    "fritti",
    "frittura",
    "bollit",
    "filetti",
    "selvaggina",
    "uccellagione",
    "chef",
    "piatto",
    "ricettar",
    "ingredienti",
    "gustoso",
    "sagra",
    "porchetta",
    "grigliata",
    "grigliato",
    "caccia",
    "cacciatore",
    "cacciatori",
    "cacciatora",
    "oroscopo",
    "tamagotchi",
    "tamaverse",
    "pescatrice",
    "cosce di rana",
    "rane fritte",
    "esperimento",
    "esperimenti",
    "sperimentazione",
    "vivisezione",
    "macellazione",
    "mattatoio",
)

# Words that say "this is about animals kept at home / their care". Needed
# next to the species words that have another everyday meaning.
_PET_CONTEXT = re.compile(
    r"\b(?:domestic\w*|da compagnia|pet|veterinari\w*|terrario|gabbia|acquario|"
    r"appartamento|adozion\w*|benessere animale|microchip)\b"
)


@dataclass(frozen=True)
class CategoryRule:
    category: str
    anchors: re.Pattern[str]
    # When set, the entry must also contain a pet-context word: the anchors
    # alone are ambiguous.
    needs_context: bool = False


def _words(*alternatives: str) -> re.Pattern[str]:
    return re.compile(r"\b(?:" + "|".join(alternatives) + r")\b")


RULES: tuple[CategoryRule, ...] = (
    CategoryRule(
        "Cane",
        _words(
            "cane",
            "cani",
            r"cagnolin[oaei]",
            "cagnone",
            "canile",
            "canili",
            r"canin[oaei]",
            "bulldog",
            "labrador",
            "retriever",
            "chihuahua",
            "cinofil\\w*",
            "randagismo",
        ),
    ),
    CategoryRule(
        "Gatto",
        _words("gatto", "gatti", r"gattin[oaei]", "micio", "mici", "gattile", r"felin[oaei]"),
    ),
    CategoryRule(
        "Piccoli mammiferi",
        _words(
            "coniglio",
            "conigli",
            "cavia",
            "cavie",
            "criceto",
            "criceti",
            "furetto",
            "furetti",
            r"cincill\w+",
            r"gerbill\w+",
            "degu",
        ),
        needs_context=True,
    ),
    CategoryRule(
        "Uccello",
        _words(
            "pappagallo",
            "pappagalli",
            "canarino",
            "canarini",
            "cocorita",
            "cocorite",
            "calopsite",
            "ornitolog\\w*",
            "uccello",
            "uccelli",
        ),
        needs_context=True,
    ),
    CategoryRule(
        "Rettili e anfibi",
        _words(
            "rettile",
            "rettili",
            "anfibio",
            "anfibi",
            "geco",
            "iguana",
            "camaleonte",
            "serpente",
            "serpenti",
            "tartaruga",
            "tartarughe",
            "testuggine",
            "testuggini",
            "rana",
            "rane",
            "salamandra",
        ),
        needs_context=True,
    ),
    CategoryRule(
        "Pesce",
        _words(
            "acquario",
            "acquari",
            "acquariofilia",
            r"pesci d'acquario",
            "pesce rosso",
            "pesci rossi",
        ),
    ),
    CategoryRule(
        "Altro",
        _words(
            "cavallo",
            "cavalli",
            "pony",
            "asino",
            "asini",
            "capra",
            "capre",
            "pecora",
            "pecore",
            "api",
            "ape",
        ),
        needs_context=True,
    ),
)

# Nothing species-specific, but clearly about companion animals as a whole.
_GENERAL = _words(
    r"animali domestici",
    r"animale domestico",
    r"animali da compagnia",
    r"animale da compagnia",
    r"pet",
    r"veterinari\w*",
    r"benessere animale",
    r"anagrafe canina",
    r"microchip",
    "zoonosi",
    "randagi\\w*",
)


def is_blocked(text: str) -> bool:
    lowered = text.casefold()
    return any(keyword in lowered for keyword in BLOCKED_KEYWORDS)


def categories_for(title: str, summary: str = "") -> list[str]:
    """The categories this entry belongs to, empty when it is off topic.

    An entry that names a species goes to that species' section(s); one that
    is only about companion animals in general goes to "Generale"."""
    text = f"{title} {summary}".casefold()
    if is_blocked(text):
        return []

    has_context = _PET_CONTEXT.search(text) is not None
    matched = [
        rule.category
        for rule in RULES
        if rule.anchors.search(text) and (has_context or not rule.needs_context)
    ]
    if matched:
        return matched
    if _GENERAL.search(text):
        return ["Generale"]
    return []
