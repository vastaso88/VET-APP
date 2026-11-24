"""A rabbit (or another small mammal) that stops eating is never made to wait a day.

Measure of 24/11/2026: to a question on bread and pasta the chat closed with "se smette di
mangiare o fa meno cacchine per più di un giorno, portalo dal veterinario oggi stesso". In
these animals the gut stops within hours. The condition stays, the waiting goes: "se smette di
mangiare o fa meno cacchine, portalo dal veterinario oggi stesso". Deterministic, in the five
languages of the chat; it only ever makes the sentence more careful.
"""

from __future__ import annotations

import re

_NUMBER = r"(?:\d+|uno|due|tre|two|three|dos|tres|zwei|drei|deux|trois)"
_WAITING = re.compile(
    # Italian
    r"\s+(?:per|da|dopo|oltre)\s+(?:(?:più|oltre|almeno)\s+(?:di\s+)?)?"
    rf"(?:tutto\s+il\s+giorno|tutto\s+un\s+giorno|un(?:'|’)?\s*(?:intera\s+)?giorn\w+|un\s+paio\s+di\s+giorn\w+|{_NUMBER}\s+giorn\w+|"
    r"(?:24|36|48|72)\s+ore)"
    # English
    r"|\s+(?:for|after)\s+(?:(?:more than|over|at least|longer than)\s+)?"
    rf"(?:(?:a|one)(?:\s+full|\s+whole)?\s+day|all\s+day|{_NUMBER}\s+days|(?:24|36|48|72)\s+hours)"
    # Spanish
    r"|\s+(?:durante|por|desde hace|después de|tras)\s+(?:(?:más de|al menos)\s+)?"
    rf"(?:un\s+día|{_NUMBER}\s+días|(?:24|36|48|72)\s+horas)"
    # German
    r"|\s+(?:länger als|mehr als|seit|nach|für)\s+(?:(?:mehr als|über|mindestens)\s+)?"
    rf"(?:eine[nm]?\s+(?:ganzen\s+)?tag|{_NUMBER}\s+tagen?|(?:24|36|48|72)\s+stunden)"
    # French
    r"|\s+(?:pendant|depuis|après|plus d[e'’])\s*(?:(?:plus d[e'’]|au moins)\s*)?"
    rf"(?:une?\s+(?:jour(?:née)?)|{_NUMBER}\s+jours|(?:24|36|48|72)\s+heures)",
    re.IGNORECASE,
)
_CONDITION = re.compile(r"\b(?:se|if|when|quando|si|cuando|wenn|falls|s['’]il|s['’]elle)\b", re.I)
_STOPS = re.compile(
    r"\bsmett\w+ di mangiare|\bnon mangi\w*|\bfeci\b|\bcacc(?:h|he|hine|a)\w*|\bpallin\w+|"
    r"\b(?:stops?|stopped|not|isn['’]t|doesn['’]t)\s+eat\w*|\bdroppings\b|\bpoop\w*|"
    r"\bdeja de comer|\bno come\b|\bheces\b|\bcacas?\b|"
    r"\bfrisst\b[^.!?]{0,20}\b(?:nicht|nichts|kaum)\b|"
    r"\b(?:nicht|nichts|kaum)\b(?: mehr)? frisst\b|\bkot\b|\bköttel\w*|"
    r"\b(?:ne mange|arrête de manger|cesse de manger)|\bcrottes?\b",
    re.IGNORECASE,
)
_SENTENCE = re.compile(r"[^.!?\n]+")


def without_a_waiting_day(answer: str, species_family: str) -> str:
    """The answer with no "for more than a day" on a small mammal that stops eating."""
    if species_family != "small_mammal":
        return answer

    def clean(match: re.Match[str]) -> str:
        sentence = match.group(0)
        if not (_STOPS.search(sentence) and _CONDITION.search(sentence)):
            return sentence
        return _WAITING.sub("", sentence)

    return _SENTENCE.sub(clean, answer)
