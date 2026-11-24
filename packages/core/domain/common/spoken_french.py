"""Spoken French drops the "ne": "elle mange plus depuis 10 jours" means "no longer eats".

Reproduced on 24/11/2026 (two generations of two): "ma grenouille cornue mange plus depuis 10
jours" was read as "eats more" and the owner was told a bigger appetite is nothing unusual.
Deterministic, French only. "plus de", "plus que", "plus souvent" are a comparison and are left
alone; so is a sentence with its "ne".
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_VERB = (
    r"mange|mangent|boit|boivent|bouge|bougent|dort|dorment|joue|jouent|sort|sortent|pond|pondent|"
    r"chante|chantent|miaule|aboie|fait|font|veut|veulent|marche|marchent|saute|respire|grimpe|"
    r"nage|nagent|touche|avale|court|courent|ronronne|repond|reagit|tient|se leve|se nourrit|"
    r"urine|urinent|pisse|pissent"
)
_COMPARISON = (
    r"(?:de|d|que|qu|souvent|vite|fort|longtemps|tard|tot|gros|grand|petit|loin|lentement|"
    r"facilement|regulierement|rarement|doucement)\b"
)
_NO_LONGER = re.compile(rf"\b(?:{_VERB})\s+(?:plus|pu)\b(?!['\s]+{_COMPARISON})")
_NEGATION_BEFORE = re.compile(r"\b(?:ne|n)['\s]+(?:\w+\s+){0,2}$")


def says_no_longer_in_spoken_french(message: str) -> bool:
    """The message says "no longer" the spoken way (a verb, "plus", no "ne")."""
    text = normalize_for_matching(message)
    return any(
        not _NEGATION_BEFORE.search(text[: match.start()]) for match in _NO_LONGER.finditer(text)
    )


# "boit plus", "urine plus" can mean either (both are signs): the urgent one is said when the
# reply did not (measure of 24/11/2026: one generation in three).
_DRINKS_OR_URINATES = re.compile(r"\b(?:boit|boivent|urine|urinent|pisse|pissent)\s+(?:plus|pu)\b")
_SAID_NO_LONGER = re.compile(
    r"\b(?:ne boit|ne boivent|n'urine|n'urinent|n urine|ne urine|ne pisse)\b[^.!?]{0,20}\bplus\b|"
    r"\bn'(?:a|ont) plus (?:bu|urine)|\bplus du tout\b|\bne boit (?:presque )?rien\b"
)
IF_IT_NO_LONGER_DRINKS_OR_URINATES = (
    "Si vous voulez dire que votre animal ne boit plus ou n'urine plus, appelez le vétérinaire "
    "maintenant. "
)


def urgent_reading_missing(message: str, reply: str) -> bool:
    """The owner may mean "no longer drinks or urinates" and the reply speaks of neither sense."""
    text = normalize_for_matching(message)
    if not says_no_longer_in_spoken_french(message) or not _DRINKS_OR_URINATES.search(text):
        return False
    return not _SAID_NO_LONGER.search(normalize_for_matching(reply))
