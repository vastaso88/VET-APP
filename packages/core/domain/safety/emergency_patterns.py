"""Emergencies the keyword lists missed (stress test, 2026-10-14).

On the main line no phrasing at all of these reached the emergency path:
rat poison, antifreeze, lilies for a cat, gastric torsion / swollen belly,
pale or blue gums — 0 of 56 realistic messages. They are matched here as
WHOLE WORDS (a word may continue with its ending, "topicid" → "topicida",
but is never found inside another word) on text normalised the way owners
type it: capitals, missing accents and umlauts, typographic apostrophes,
"ß" as "ss", "œ" as "oe".

Each pattern reports a stable flag; the flag belongs to a category in
triage_clarification.RED_FLAG_CATEGORIES, which decides the response:
- poisons → "toxin_medication" (immediate, "può essere pericoloso");
- torsion, retching, swollen belly, pale/blue gums → categories with no
  clarifying question (immediate): asking first would only cost time.

2026-10-26: the same five groups in German and French (the chat speaks
it/en/es/de/fr since the MULTILANG merge; until then de/fr owners were
covered only by the model-based classifier). Each language has its own
patterns, written the way owners of that language type ("hat Rattengift
gefressen", "a mangé de la mort-aux-rats"); the exposure words of every
language are pooled, since a poison is dangerous however it was reached.
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

_PLAIN_FORMS = (
    ("’", "'"),
    ("‘", "'"),
    ("´", "'"),
    ("`", "'"),
    ("“", '"'),
    ("”", '"'),
    ("ß", "ss"),
    ("œ", "oe"),
    ("æ", "ae"),
)


def normalize_for_matching(text: str) -> str:
    """Lower case, accents and umlauts removed, typographic quotes and
    apostrophes made plain, "ß"/"œ" spelled out, whitespace collapsed:
    "L’ANTIGELO è lì" → "l'antigelo e li", "Mäusegift" → "mausegift"."""
    text = text.lower()
    for fancy, plain in _PLAIN_FORMS:
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


# The animal ate, licked, chewed or drank it (or some is missing) — in
# Italian, German and French; "ue"/"ae"/"oe" spellings of umlauts included.
_EXPOSURE_IT = (
    r"mangiat\w*|mangiava|masticat\w*|mastica|leccat\w*|lecca|leccava|morso|morsicat\w*|"
    r"mordicchiat\w*|rosicchiat\w*|ingoiat\w*|ingerit\w*|inghiottit\w*|bevut\w*|"
    r"beveva|assaggiat\w*|avvelenat\w*|polline|ne manca\w*|ne mancano"
)
_EXPOSURE_DE = (
    r"gefressen|gegessen|frisst|fressen|fras|geleckt|abgeleckt|leckt|gekaut|zerkaut|"
    r"angekaut|gebissen|angeknabbert|geknabbert|angenagt|verschluckt|geschluckt|"
    r"heruntergeschluckt|runtergeschluckt|getrunken|trinkt|aufgenommen|erwischt|"
    r"vergiftet|probiert|genascht|fehlt|fehlen|pollen|blutenstaub|bluetenstaub"
)
_EXPOSURE_FR = (
    r"mange|manger|mangeait|mangee|avale|avaler|avalait|avalee|leche|lecher|lechait|"
    r"mache|macher|machait|machouille|machouiller|mordu|mord|mordille|mordiller|croque|"
    r"croquer|grignote|grignoter|ronge|ronger|ingere|ingerer|bu|boit|boire|buvait|"
    r"goute|gouter|empoisonne\w*|intoxique\w*|il manque|il en manque|pollen"
)
_EXPOSURE = _words(f"{_EXPOSURE_IT}|{_EXPOSURE_DE}|{_EXPOSURE_FR}")

_RODENT = r"topi|topo|ratti|ratto|roditori|sorci"
_RODENT_DE = r"ratten|maus|mause|maeuse|nager|nagetiere"
_RODENT_FR = r"rats|rat|souris|rongeurs|mulots"
_GDV_SPECIES = frozenset({"dog", "small_mammal"})
_CAT = frozenset({"cat"})

_ITALIAN_PATTERNS: tuple[EmergencyPattern, ...] = (
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
        families=_CAT,
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

_GERMAN_PATTERNS: tuple[EmergencyPattern, ...] = (
    # --- Rattengift, Mäusegift, Giftköder (umlauts arrive as a/o/u or ae/oe/ue)
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(
            r"rattengift|mausegift|maeusegift|nagergift|rodentizid\w*|giftkoder|giftkoeder|"
            r"rattenkoder|rattenkoeder|mausekoder|mausekoeder|giftweizen|giftgetreide"
        ),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(
            rf"(?:koder|koeder|gift|kodermasse|koedermasse) (?:fur|fuer|gegen) (?:die )?"
            rf"(?:{_RODENT_DE})"
        ),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(
            rf"(?:vergiftete|tote vergiftete|vergifteten) (?:{_RODENT_DE})|"
            rf"(?:{_RODENT_DE}) vergiftet"
        ),
    ),
    # --- Frostschutzmittel, Kühlflüssigkeit, Glykol
    EmergencyPattern(
        ANTIFREEZE_FLAG,
        _words(
            r"frostschutz\w*|kuhlflussigkeit|kuehlfluessigkeit|kuhlerflussigkeit|"
            r"kuehlerfluessigkeit|kuhlwasser|kuehlwasser|kuhlmittel|kuehlmittel|glykol|"
            r"ethylenglykol|scheibenfrostschutz\w*"
        ),
        requires=_EXPOSURE,
    ),
    # --- Lilien (cat)
    EmergencyPattern(
        LILY_FLAG,
        # Compounds too: Lilienblatt, Lilienpollen, Lilienvase.
        _words(r"lilie\w*|taglilie\w*|lilium|hemerocallis"),
        families=_CAT,
        requires=_EXPOSURE,
    ),
    # --- Magendrehung
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"magendrehung|magenumdrehung|magentorsion|magendilatation|magenaufblahung|"
            r"magenaufblaehung"
        ),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"wurgt|wuergt|wurgen|wuergen|versucht zu erbrechen|versucht sich zu ubergeben|"
            r"versucht sich zu uebergeben|kann nicht erbrechen|erbricht nichts|"
            r"brechreiz ohne|leeres wurgen|leeres wuergen|wurgt ohne|wuergt ohne"
        ),
        families=frozenset({"dog"}),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"(?:bauch|magen|unterleib)(?: \w+){0,2} "
            r"(?:aufgeblaht\w*|aufgeblaeht\w*|aufgetrieben\w*|aufgeblasen\w*|gebl\w*|hart\w*|"
            r"prall\w*|gespannt\w*|dick wie eine trommel|wie eine trommel|wie ein ballon)|"
            r"(?:aufgeblaht\w*|aufgeblaeht\w*|aufgetrieben\w*|harter|praller) (?:bauch|magen)"
        ),
        families=_GDV_SPECIES,
    ),
    # --- blasses, weißes, blaues Zahnfleisch / Zunge
    EmergencyPattern(
        PALE_GUMS_FLAG,
        _words(
            r"(?:zahnfleisch|schleimhaut|schleimhaute|schleimhaeute|maulschleimhaut|zunge|"
            r"lippen|lefzen)(?: \w+){0,4} "
            r"(?:blass\w*|bleich\w*|weiss\w*|weis\w*|grau\w*|blau\w*|blaulich\w*|"
            r"blaeulich\w*|lila|violett\w*|zyanotisch\w*)"
        ),
    ),
    EmergencyPattern(
        PALE_GUMS_FLAG,
        _words(
            r"(?:blasses|bleiches|weisses|weises|graues|blaues|blauliches|blaeuliches|"
            r"lila|violettes) (?:zahnfleisch|schleimhaute|schleimhaeute)|"
            r"(?:blasse|bleiche|weisse|graue|blaue|blauliche|blaeuliche|violette|lila) "
            r"(?:zunge|schleimhaute|schleimhaeute|lippen|lefzen)|zyanose|zyanotisch\w*"
        ),
    ),
)

_FRENCH_PATTERNS: tuple[EmergencyPattern, ...] = (
    # --- mort-aux-rats, raticide, appât pour rats
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(
            r"mort(?:-| )aux(?:-| )rats|raticide\w*|rodenticide\w*|souricide\w*|anti-rats|antirats"
        ),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(
            rf"(?:appat|appats|poison|produit|grains|granules|bloc|blocs|pate|pates) "
            rf"(?:\w+ )?(?:pour|contre|a|anti) (?:les |des )?(?:{_RODENT_FR})"
        ),
        requires=_EXPOSURE,
    ),
    EmergencyPattern(
        RODENTICIDE_FLAG,
        _words(rf"(?:{_RODENT_FR}) (?:empoisonne\w*|mort\w* empoisonne\w*)"),
    ),
    # --- antigel, liquide de refroidissement, glycol
    EmergencyPattern(
        ANTIFREEZE_FLAG,
        _words(
            r"antigel|anti-gel|liquide de refroidissement|liquide du radiateur|"
            r"liquide radiateur|glycol|ethylene glycol|ethyleneglycol|lave-glace antigel|"
            r"lave glace antigel"
        ),
        requires=_EXPOSURE,
    ),
    # --- lys / lis (cat)
    EmergencyPattern(
        LILY_FLAG,
        _words(r"lys|lis|lilium|hemerocalle\w*|hemerocallis|fleur de lys|fleurs de lys"),
        families=_CAT,
        requires=_EXPOSURE,
    ),
    # --- torsion de l'estomac
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"(?:torsion|dilatation|retournement)(?: \w+){0,2} (?:de l'estomac|d'estomac|"
            r"gastrique|de l'estomac)|estomac (?:retourne|tordu)|syndrome dilatation"
        ),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"haut-le-coeur|hauts-le-coeur|haut le coeur|hauts le coeur|essaie de vomir|"
            r"essaye de vomir|tente de vomir|n'arrive pas a vomir|vomit a vide|"
            r"vomissements? a vide|vomissements? improductifs?|efforts de vomissement\w*|"
            r"sans rien vomir|sans reussir a vomir|sans arriver a vomir"
        ),
        families=frozenset({"dog"}),
    ),
    EmergencyPattern(
        BLOAT_FLAG,
        _words(
            r"(?:ventre|abdomen|estomac|bide|bidon)(?: \w+){0,2} "
            r"(?:gonfle\w*|ballonne\w*|dur\w*|tendu\w*|distendu\w*|enfle\w*|"
            r"comme un tambour|comme un ballon)"
        ),
        families=_GDV_SPECIES,
    ),
    # --- gencives pâles, blanches, bleues / langue bleue
    EmergencyPattern(
        PALE_GUMS_FLAG,
        _words(
            r"(?:gencive|gencives|muqueuse|muqueuses|langue|levres|levre|babines)(?: \w+){0,4} "
            r"(?:pale\w*|blanch\w*|blanc\w*|bleu\w*|bleuatre\w*|gris\w*|violet\w*|violac\w*|"
            r"cyanos\w*|cyanotique\w*|decolore\w*)"
        ),
    ),
    EmergencyPattern(PALE_GUMS_FLAG, _words(r"cyanose|cyanotique\w*")),
)

EMERGENCY_PATTERNS: tuple[EmergencyPattern, ...] = (
    *_ITALIAN_PATTERNS,
    *_GERMAN_PATTERNS,
    *_FRENCH_PATTERNS,
)

# How many patterns each language contributes (reported, and kept in step
# by the tests: an equivalent of every Italian group exists in de and fr).
PATTERNS_BY_LANGUAGE: dict[str, tuple[EmergencyPattern, ...]] = {
    "it": _ITALIAN_PATTERNS,
    "de": _GERMAN_PATTERNS,
    "fr": _FRENCH_PATTERNS,
}


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
