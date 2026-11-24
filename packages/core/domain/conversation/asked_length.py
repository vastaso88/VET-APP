"""How long an answer the owner asked for ("riassumi in 3 righe", "in five words", "kurz und
bündig"; collaudo F36: 110 words for three lines). Deterministic, in the five languages; None
when the message names no length."""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_NUMBERS = {
    "un": 1, "una": 1, "uno": 1, "one": 1, "ein": 1, "eine": 1, "einem": 1, "une": 1,
    "due": 2, "two": 2, "zwei": 2, "deux": 2, "dos": 2,
    "tre": 3, "three": 3, "drei": 3, "trois": 3, "tres": 3,
    "quattro": 4, "four": 4, "vier": 4, "quatre": 4, "cuatro": 4,
    "cinque": 5, "five": 5, "funf": 5, "cinq": 5, "cinco": 5,
    "sei": 6, "six": 6, "sechs": 6, "seis": 6,
    "dieci": 10, "ten": 10, "zehn": 10, "dix": 10, "diez": 10,
}  # fmt: skip
_WORDS_IN_A_LINE = 14  # a line on a phone is about 8-9; the owner means a few, not a count
_FLOOR = 25  # below this nothing can carry a "call the vet now" with its reason
_NUMBER = r"(\d{1,3}|" + "|".join(sorted(_NUMBERS, key=len, reverse=True)) + r")"
# a length ("in 3 righe"), not a count said of the animal ("ha tre righe nere")
_BEFORE = (
    r"(?:in|con|al massimo|massimo|max|at most|only|solo|soltanto|just|nur|hochstens|en|"
    r"au plus|maximo)"
)
_LINES = re.compile(
    rf"\b{_BEFORE}\s+{_NUMBER}\s+(?:righe|riga|lines?|zeilen?|lignes?|lineas?|renglones|renglon)\b"
)
_WORDS = re.compile(
    rf"\b{_BEFORE}\s+{_NUMBER}\s+(?:parole|parola|words?|worte?n?|worter|mots?|palabras?)\b"
)
_ONE_SENTENCE = re.compile(
    r"\b(?:in una frase|con una frase|in one sentence|in einem satz|en une phrase|en una frase)\b"
)
_BRIEF = re.compile(
    r"\b(?:in breve|brevemente|in poche parole|rispost[ae] (?:breve|corta)|piu cort[ao]|"
    r"in short|briefly|short answer|in a few words|kurz und bundig|kurz gesagt|in kurzen worten|"
    r"kurze antwort|en bref|brievement|en pocas palabras|brevemente|respuesta corta)\b"
)


def _value(text: str) -> int:
    return int(text) if text.isdigit() else _NUMBERS[text]


def asked_words(message: str) -> int | None:
    """About how many words the owner wants, or None."""
    text = normalize_for_matching(message)
    if match := _LINES.search(text):
        return max(_FLOOR, _value(match.group(1)) * _WORDS_IN_A_LINE)
    if match := _WORDS.search(text):
        return max(_FLOOR, _value(match.group(1)))
    if _ONE_SENTENCE.search(text):
        return _FLOOR + 5
    if _BRIEF.search(text):
        return 70
    return None
