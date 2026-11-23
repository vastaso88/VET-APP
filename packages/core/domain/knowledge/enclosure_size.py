"""The size of a cage is said only when a source given for the answer states it (collaudo,
wave 0, 23/11/2026: "un recinto di almeno 100 x 60 cm" for two guinea pigs, with no source;
the figure was the model's own). Deterministic, in the five languages of the chat, the same
idea as the prices the owner did not write: the sentence with the figure goes.
"""

from __future__ import annotations

import re

from packages.core.domain.knowledge.answer_validation import without_sentences
from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# Read on the normalized text (lower case, no accents).
_HOUSING = re.compile(
    r"\b(?:gabbi\w*|recint\w*|volier\w*|terrari\w*|conigliera|box|"
    r"cages?|enclosures?|hutch\w*|aviar(?:y|ies)|vivariums?|playpens?|pens?|"
    r"jaulas?|recintos?|pajareras?|conejeras?|corralitos?|"
    r"\w*kafig\w*|\w*gehege\w*|\w*stall|\w*auslauf\w*|"
    r"enclos|clapiers?|parcs?)\b"
)
_NUMBER = r"\d+(?:[.,]\d+)?(?![\d.,]*\d)"
_UNIT = (
    r"(?:cm|centimetr\w*|centimet\w*|zentimeter\w*|mt|metr[io]|metros?|meters?|metres?|"
    r"meter|m|ft|feet|foot|inch(?:es)?)\b"
)
_BY = r"(?:x|×|\*|per|by|por|mal|sur)"
# 100 x 60, 100x60x40 cm, 100 cm per 60 cm
_SIDES = re.compile(
    rf"(?<![\w.,]){_NUMBER}\s*{_UNIT[:-2]}?\s*{_BY}\s*{_NUMBER}"
    rf"(?:\s*{_UNIT[:-2]}?\s*{_BY}\s*{_NUMBER})?(?:\s*{_UNIT})?"
    r"(?!\s*(?:min\w*|or[ae]|volt\w*|times?|veces|mal\b|fois|giorn\w*|days?|dias?|tag\w*|jour\w*|"
    r"g\b|kg\b|ml\b|gramm\w*))"
)
# 0.7 m2, 2 mq, 120 cm
_SURFACE = re.compile(
    rf"(?<![\w.,]){_NUMBER}\s*(?:m2|m²|mq|cm2|cm²|sq\.?\s?(?:m|ft|feet)|metri quadr\w*|"
    r"square (?:metres?|meters?|feet)|metros cuadrados|quadratmeter\w*|metres carres)"
)
_LENGTH = re.compile(rf"(?<![\w.,]){_NUMBER}\s*{_UNIT}")


def _figures(text: str) -> set[str]:
    return set(re.findall(_NUMBER, text.replace(",", ".")))


def _sizes(sentence: str) -> list[str]:
    if not _HOUSING.search(sentence):
        return []
    return [m.group(0) for p in (_SIDES, _SURFACE, _LENGTH) for m in p.finditer(sentence)]


def unsourced_sizes(answer: str, allowed_text: str) -> list[str]:
    """The sizes of a cage or pen in the answer whose figures are not in what was given for
    it (sources, the owner's words, the animal's profile)."""
    known = _figures(normalize_for_matching(allowed_text))
    sentences = re.split(r"(?<=[.!?;])\s+|\n+", normalize_for_matching(answer))
    return [
        size for sentence in sentences for size in _sizes(sentence) if not _figures(size) <= known
    ]


def without_unsourced_sizes(answer: str, allowed_text: str) -> str:
    """The answer without the sentences that carry such a size, layout kept."""
    known = _figures(normalize_for_matching(allowed_text))
    return without_sentences(
        answer,
        lambda s: any(not _figures(x) <= known for x in _sizes(normalize_for_matching(s))),
    )
