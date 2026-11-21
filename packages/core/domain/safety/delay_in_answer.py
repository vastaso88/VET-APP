"""Does a reply put off the visit or soften the case? (synthetic users round 4, 21/11/2026)

In 25 of 103 serious cases the new chat wrote "oggi stesso" / "heute noch" / "today"
instead of "now", "fino a sabato", or a reassurance ("è una buona notizia che mangi",
"spesso è un'irritazione"). The prompt rule alone did not hold in long conversations,
so a check reads the reply after it is written (plan 08, v2 only). This module is the
cheap, deterministic trigger for that check, in the five languages of the chat: it says
only that the reply CONTAINS a delay or a reassurance; whether the case is serious, and
the rewrite, are the check's job.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

_DAYS = (
    r"luned\w*|marted\w*|mercoled\w*|gioved\w*|venerd\w*|sabato|domenica|"
    r"monday|tuesday|wednesday|thursday|friday|saturday|sunday|"
    r"lunes|martes|miercoles|jueves|viernes|sabado|domingo|"
    r"montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|"
    r"lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche"
)

_DELAY = re.compile(
    # Italian
    r"\boggi(?: stesso| in giornata)?\b|\bin giornata\b|\bstasera\b|\bdomani\b|"
    r"\bentro (?:domani|stasera|qualche ora|poche ore|\d+ or[ae]|un paio di|\d+ giorn\w*|"
    r"la giornata|fine giornata)|\bnei prossimi giorni\b|\bnelle prossime (?:ore|24|48)\b|"
    r"\bappena (?:possibile|puoi)\b|\bse (?:peggiora|non migliora|non passa|continua)\b|"
    r"\bfino a (?:" + _DAYS + r")\b|"
    # English
    r"\btoday\b|\bthis evening\b|\btonight\b|\btomorrow\b|\bsame day\b|"
    r"\bwithin (?:a day|the day|24|48|a few|the next|\d+ (?:hours?|days?))|"
    r"\bin the next (?:few )?(?:days|hours)\b|\bas soon as (?:possible|you can)\b|"
    r"\bif (?:it|he|she|this) (?:gets worse|doesn'?t improve|does not improve|continues)\b|"
    r"\buntil (?:" + _DAYS + r")\b|"
    # Spanish
    r"\bhoy(?: mismo)?\b|\besta (?:tarde|noche)\b|\bmanana\b|\ben los proximos dias\b|"
    r"\bdentro de (?:unas|\d+|un par)|\bcuanto antes\b|\blo antes posible\b|"
    r"\bsi (?:empeora|no mejora|sigue)\b|\bhasta el (?:" + _DAYS + r")\b|"
    # German
    r"\bheute(?: noch)?\b|\bheute abend\b|\bmorgen\b|\bin den nachsten tagen\b|"
    r"\binnerhalb (?:von|der nachsten)\b|\bso bald wie moglich\b|\bmoglichst bald\b|"
    r"\bwenn es (?:schlimmer wird|sich verschlechtert|nicht besser wird)\b|"
    r"\bbis (?:" + _DAYS + r")\b|"
    # French
    r"\baujourd'?hui\b|\bce soir\b|\bdemain\b|\bdans les (?:prochains jours|prochaines heures)\b|"
    r"\bd'ici (?:demain|ce soir|\d+|deux|quelques)\b|\bdes que possible\b|"
    r"\bsi (?:ca|cela|il|elle) (?:s'aggrave|empire|ne s'ameliore pas|continue)\b|"
    r"\bjusqu'a (?:" + _DAYS + r")\b"
)

_REASSURANCE = re.compile(
    r"\bbuon(?:a)? (?:segno|notizia)\b|\b(?:spesso|di solito|per lo piu) (?:e|si tratta)\b|"
    r"\bnon e grave\b|\bniente di grave\b|\bnon preoccuparti\b|\bstai tranquill\w*\b|"
    r"\bgood (?:sign|news)\b|\b(?:it'?s|it is|this is) (?:often|usually) (?:just|only)?\b|"
    r"\bnothing serious\b|\bdon'?t worry\b|"
    r"\bbuena (?:senal|noticia)\b|\b(?:a menudo|suele ser|normalmente es)\b|\bno es grave\b|"
    r"\bno te preocupes\b|"
    r"\bgutes zeichen\b|\bgute nachricht\b|\b(?:oft|meist|meistens) (?:nur|harmlos)\b|"
    r"\bnicht schlimm\b|\bkeine sorge\b|"
    r"\bbon signe\b|\bbonne nouvelle\b|\b(?:souvent|generalement) (?:c'est|une|un|rien)\b|"
    r"\brien de grave\b|\bne vous inquietez pas\b"
)


def delays_or_reassures(reply: str) -> bool:
    """The reply contains a delay of the visit or a reassurance (any case, serious or not)."""
    text = normalize_for_matching(reply)
    return bool(_DELAY.search(text) or _REASSURANCE.search(text))
