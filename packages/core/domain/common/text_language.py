"""Which of the chat's languages a text is written in (collaudo, wave 1: five answers of eleven
for an English account came out in Italian).

Counts function words that belong to one language only. Deterministic, no model, no library;
it says nothing when a text is short or mixed, so a wrong guess never costs an answer.
"""

from __future__ import annotations

import re

_WORDS = re.compile(r"[a-zà-ÿœß]+")

_ONLY_IN: dict[str, frozenset[str]] = {
    "it": frozenset(
        "il gli dei della delle degli che è anche sono questa questo può perché quindi nel nella "
        "nelle sul alla dal dalla adesso più hanno ogni ma loro quello cosa quando".split()
    ),
    "en": frozenset(
        "the and is are to of you with for it that this can should be your her his she he "
        "they which have has will from at not if when what".split()
    ),
    "es": frozenset(
        "el los las muy está para pero también porque cuando más sus están cada hasta sobre "
        "debe puede así si ha han tiene hay donde".split()
    ),
    "de": frozenset(
        "der die das und ist nicht ein eine mit sie auf den dem von zu im wenn kann auch sind "
        "ihre ihr für oder wird bei nach".split()
    ),
    "fr": frozenset(
        "les des est et une pour avec vous dans qui pas cette être aux mais votre peut ou où "
        "sont très plus leur ses comme".split()
    ),
}


def language_of(text: str) -> str | None:
    """The language code, or None when the text is too short or too mixed to say."""
    words = _WORDS.findall(text.lower())
    if len(words) < 12:
        return None
    hits = {code: sum(word in only for word in words) for code, only in _ONLY_IN.items()}
    ranked = sorted(hits.items(), key=lambda item: -item[1])
    best, second = ranked[0], ranked[1]
    if best[1] < max(5, 0.08 * len(words)) or best[1] < 2 * second[1]:
        return None
    return best[0]


def is_in_another_language(text: str, expected: str) -> bool:
    found = language_of(text)
    return found is not None and found != expected
