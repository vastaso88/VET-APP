"""A quantity of food or water is said only when a source, the owner or the animal's profile
gives it (collaudo, wave 2: "2-3 % of body weight, 600-900 g a day" for a Labrador; "about
10 gallons per inch, so 30 cm = 120 litres" for a turtle). Deterministic, in the five
languages of the chat: the sentence with the figure goes. Any model, the reserve included.

A dose of a medicine is the business of dose_in_answer.py; the size of a cage of
enclosure_size.py.
"""

from __future__ import annotations

import re

from packages.core.domain.knowledge.answer_validation import without_sentences
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_NUMBER = r"\d+(?:[.,]\d+)?(?![\d.,]*\d)"
_RANGE = rf"{_NUMBER}(?:\s*(?:-|–|—|/|a|bis|to|e|y|et|und)\s*{_NUMBER})?"
# A sentence about food or water (normalized text).
_FOOD_OR_WATER = re.compile(
    r"\b(?:cib[oi]|crocchett\w*|croccant\w*|mangim\w*|fieno|verdur\w*|insalat\w*|pellet\w*|"
    r"past[oi]|razion\w*|porzion\w*|pappa|carne|snack|premiett\w*|insett\w*|grilli|"
    r"acqua|vasc[ah]e?|acquari\w*|terrari\w*|serbatoi\w*|"
    r"food|kibbles?|hay|vegetables?|greens|rations?|portions?|meals?|treats?|feed\w*|insects?|"
    r"crickets?|water|tanks?|aquariums?|"
    r"futter\w*|trockenfutter|heu|gemuse|rationen?|portion\w*|mahlzeit\w*|wasser|becken|aquari\w*|"
    r"nourriture|croquettes?|foin|legumes?|rations?|repas|eau|bacs?|"
    r"comidas?|piensos?|heno|verduras?|racion\w*|porcion\w*|agua|acuarios?|peceras?|"
    r"beber|bere|drink\w*|trinkt?|boire)\b"
)
_UNITS = (
    r"(?:g|gr|grammi|grammo|grams?|gramm|grammes?|gramos?|kg|chili|kilos?|ml|cl|l|lt|litri|"
    r"litro|litros?|liters?|litres?|litern?|gallons?|galloni|gallonen|galones?|oz|ounces?|"
    r"once|lbs?|pounds?|libbre|kcal|kilocal\w*|kalorien|calorie|calories|calorias)\b"
)
_AMOUNT = re.compile(rf"(?<![\w.,]){_RANGE}\s*{_UNITS}")
# "2-3 % of body weight"
_PERCENT = re.compile(
    rf"(?<![\w.,]){_RANGE}\s*(?:%|per ?cento|percent|prozent|por ciento|pour ?cent)"
)
_OF_WEIGHT = re.compile(r"\b(?:peso|weight|gewicht\w*|korpergewicht\w*|poids)\b")
# "a full cup", "half a tablespoon": a size with no figure
_SPOONS_AND_CUPS = re.compile(
    r"\b(?:un[ao']?|mezz[ao]|due|tre|quattro|half|a|one|two|three|four|ein\w*|zwei|drei|"
    r"une?|deux|trois|media|dos|tres|una)\s+(?:\w+\s+){0,2}(?:tazz\w*|tazzin\w*|cucchiai\w*|"
    r"cups?|tablespoons?|teaspoons?|spoons?|tassen?|essloffel|teeloffel|loffel|"
    r"cuiller\w*|tasses?|tazas?|cucharad\w*|cuchar\w*)\b"
)
_CUPS_IN_TEXT = re.compile(
    r"\b(?:tazz\w*|cucchiai\w*|cups?|spoons?|tassen?|loffel|cuiller\w*|taza\w*|cuchar\w*)\b"
)


# A cup named to advise against it ("con una bilancia invece di usare una tazza").
_INSTEAD_OF = re.compile(
    r"\b(?:invece di|piuttosto che|instead of|rather than|anstatt|statt|au lieu de|plutot que|"
    r"en lugar de|en vez de)\b"
)


# What the owner gave in grams (or ml, kcal), divided into 2 to 6 meals: not a figure of the
# model's. Never a weight in kilos or a length ("30 kg" over three is no ration).
_RATION = re.compile(rf"(?<![\w.,]){_NUMBER}\s*(?:g|gr|gramm\w*|grams?|ml|kcal)\b")


def _meal_shares(known_text: str) -> set[str]:
    figures = {f for m in _RATION.finditer(known_text) for f in _figures(m.group(0))}
    return {f"{float(f) / meals:g}" for f in figures for meals in range(2, 7)}


def _figures(text: str) -> set[str]:
    return set(re.findall(_NUMBER, text.replace(",", ".")))


def _unsourced(sentence: str, known_text: str, known: set[str]) -> bool:
    if not _FOOD_OR_WATER.search(sentence):
        return False
    amounts = [m.group(0) for m in _AMOUNT.finditer(sentence)]
    if _OF_WEIGHT.search(sentence):
        amounts += [m.group(0) for m in _PERCENT.finditer(sentence)]
    if any(not _figures(a.replace(",", ".")) <= known for a in amounts):
        return True
    if _INSTEAD_OF.search(sentence):
        return False
    return bool(_SPOONS_AND_CUPS.search(sentence)) and not _CUPS_IN_TEXT.search(known_text)


def unsourced_quantities(answer: str, known_text: str) -> list[str]:
    known_normalized = normalize_for_matching(known_text)
    known = _figures(known_normalized) | _meal_shares(known_normalized)
    return [
        s
        for s in re.split(r"(?<=[.!?;])\s+|\n+", normalize_for_matching(answer))
        if _unsourced(s, known_normalized, known)
    ]


def without_unsourced_quantities(answer: str, known_text: str) -> str:
    """The answer without the sentences that carry such a quantity, layout kept."""
    known_normalized = normalize_for_matching(known_text)
    known = _figures(known_normalized) | _meal_shares(known_normalized)
    return without_sentences(
        answer, lambda s: _unsourced(normalize_for_matching(s), known_normalized, known)
    )
