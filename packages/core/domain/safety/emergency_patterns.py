"""Emergencies the keyword lists missed (stress test, 2026-10-14).

On the main line no phrasing at all of these reached the emergency path:
rat poison, antifreeze, lilies for a cat, gastric torsion / swollen belly,
pale or blue gums — 0 of 56 realistic messages. They are matched here as
WHOLE WORDS (a word may continue with its ending, "topicid" → "topicida",
but is never found inside another word) on text normalised the way owners
type it: capitals, missing accents, typographic apostrophes.

Each pattern reports a stable flag; the flag belongs to a category in
triage_clarification.RED_FLAG_CATEGORIES, which decides the response:
- poisons → "toxin_medication" (immediate, "può essere pericoloso");
- torsion, retching, swollen belly, pale/blue gums → categories with no
  clarifying question (immediate): asking first would only cost time.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

# Flags (reported in safety_flags; mapped to categories in
# triage_clarification.RED_FLAG_CATEGORIES).
RODENTICIDE_FLAG = "rodenticida"
ANTIFREEZE_FLAG = "antigelo"
LILY_FLAG = "giglio"
BLOAT_FLAG = "torsione gastrica"
PALE_GUMS_FLAG = "gengive pallide"


def normalize_for_matching(text: str) -> str:
    """Lower case, accents removed, typographic quotes and apostrophes made
    plain, whitespace collapsed: "L’ANTIGELO è lì" → "l'antigelo e li"."""
    text = text.lower()
    for fancy, plain in (("’", "'"), ("‘", "'"), ("´", "'"), ("`", "'"), ("“", '"'), ("”", '"')):
        text = text.replace(fancy, plain)
    text = "".join(
        ch for ch in unicodedata.normalize("NFKD", text) if not unicodedata.combining(ch)
    )
    return re.sub(r"\s+", " ", text).strip()


def _words(pattern: str) -> re.Pattern[str]:
    # \b on both sides: whole words only; patterns spell endings with \w*.
    return re.compile(rf"\b(?:{pattern})\b")


@dataclass(frozen=True)
class EmergencyPattern:
    flag: str
    pattern: re.Pattern[str]
    # Species families it applies to (None: every species).
    families: frozenset[str] | None = None
    # A second pattern that must also be present: for a poison, that the
    # animal was exposed to it. "Dove tengo l'antigelo lontano dal cane?" is
    # a prevention question, and a cat may well be called "Giglio".
    requires: re.Pattern[str] | None = None


# The animal ate, licked, chewed or drank it (or some is missing).
_EXPOSURE = _words(
    r"mangiat\w*|mangiava|masticat\w*|mastica|leccat\w*|lecca|leccava|morso|morsicat\w*|"
    r"mordicchiat\w*|rosicchiat\w*|ingoiat\w*|ingerit\w*|inghiottit\w*|bevut\w*|"
    r"beveva|assaggiat\w*|avvelenat\w*|polline|ne manca\w*|ne mancano"
)

_RODENT = r"topi|topo|ratti|ratto|roditori|sorci"
_GDV_SPECIES = frozenset({"dog", "small_mammal"})

EMERGENCY_PATTERNS: tuple[EmergencyPattern, ...] = (
    # --- rat poison (anticoagulants: bleeding days later, even if fine now)
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(r"topicid\w*|ratticid\w*|rodenticid\w*|antitopo"),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(rf"velen\w* (?:per|x|contro|dei|anti) (?:i |gli )?(?:{_RODENT})"),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(rf"(?:esca|esche) (?:per|x|contro|dei|anti) (?:i |gli )?(?:{_RODENT})"),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(RODENTICIDE_FLAG, _words(r"(?:topo|ratto) avvelenat\w*")),
    # --- antifreeze (ethylene glycol: kidney failure within hours)
    EmergencyPattern(
        ANTIFREEZE_FLAG, _words(r"antigelo|anticongelant\w*|glicole"), requires=_EXPOSURE
    ),
    EmergencyPattern(
        ANTIFREEZE_FLAG,
        _words(r"liquido (?:refrigerante|di raffreddamento|del radiatore|radiatore)"),
        requires=_EXPOSURE,
    ),
    # --- lilies: any part, pollen or vase water, for cats
    EmergencyPattern(
        LILY_FLAG,
        _words(r"giglio|gigli|lilium|emerocallid\w*|hemerocallis"),
        families=frozenset({"cat"}),
        requires=_EXPOSURE,
    ),
    # --- gastric dilatation-volvulus: torsion, unproductive retching
    EmergencyPattern(
        BLOAT_FLAG,
        _words(r"(?:torsion|dilatazion)\w* (?:gastric\w*|dello stomaco|di stomaco)"),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"conati|(?:cerca|prova|tenta) di vomitare|non riesce a vomitare|"
            r"vomit\w* a vuoto|senza (?:riuscire a )?vomitare"
        ),
        # Dogs: a cat retching is usually a hairball.
        families=frozenset({"dog"}),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"(?:pancia|addome|ventre|stomaco)(?: \w+){0,2} "
            r"(?:gonfi\w*|dur[ao]|tes[ao]|distes[ao]|come un tamburo)"
        ),
        families=_GDV_SPECIES,
    ),
    # --- pale, white, grey or blue gums / tongue (shock, anaemia, no oxygen)
    EmergencyPattern(
        PALE_GUMS_FLAG,
        _words(
            r"(?:gengiv\w*|mucos\w*|lingua|labbra)(?: \w+){0,4} "
            r"(?:pal+i+d\w*|bianc\w*|bluastr\w*|blu|azzurr\w*|viola|violac\w*|grig\w*|"
            r"cianotic\w*)"
        ),
    ),
    EmergencyPattern(PALE_GUMS_FLAG, _words(r"cianosi|cianotic\w*")),
)


def emergency_flags(message: str, family: str) -> list[str]:
    """The flags of every emergency pattern found in [message] for an
    animal of species [family]; each flag once."""
    text = normalize_for_matching(message)
    found: list[str] = []
    for rule in EMERGENCY_PATTERNS:
        if rule.flag in found:
            continue
        if rule.families is not None and family not in rule.families:
            continue
        if not rule.pattern.search(text):
            continue
        if rule.requires is not None and not rule.requires.search(text):
            continue
        found.append(rule.flag)
    return found
