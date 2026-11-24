"""A symptom the owner never wrote is not said of their animal (collaudo, wave 2: "seit zwei
Tagen erbricht" for a turtle with diarrhoea, and the next reply built on it). Deterministic
detection, in the five languages of the chat; the rewrite is a light call (the reply's own
meaning stays). The check reads the owner's words in this conversation, the profile and the
records: what is in none of them was not told.

It looks only at assertions about the animal (a duration, or the animal as subject): a general
list of signs ("may include vomiting", "se vomita, chiama") is not one.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# One entry per sign; each pattern reads normalized text in the five languages.
_SIGNS: dict[str, re.Pattern[str]] = {
    "vomiting": re.compile(
        r"\b(?:vomit\w*|rigurgit\w*|erbrech\w*|erbricht|ubergib\w*|vomiss\w*|vomi(?:t|s|e)?\w*|"
        r"throw\w* up|threw up)\b"
    ),
    "diarrhoea": re.compile(
        r"\b(?:diarre\w*|diarrhe\w*|diarrhoea|durchfall\w*|feci molli|feci liquide|cacca molle|"
        r"loose stool\w*|heces blandas)\b"
    ),
    "fever": re.compile(r"\b(?:febbre|febbric\w*|fever\w*|fieber\w*|fievre|fiebre)\b"),
    # "tossico" (toxic) is no cough: one flagged the sentence that sent the owner to the vet
    "cough": re.compile(
        r"\b(?:tosse|tossi(?:sce|sco|scono|va|re|to|endo)|coughs?|coughing|husten|hustet|"
        r"tousse\w*|toux|tos)\b"
    ),
    "seizure": re.compile(r"\b(?:convulsion\w*|seizure\w*|krampf\w*|anfall\w*|crise convulsive)\b"),
    "blood": re.compile(
        r"\b(?:sangue|sanguin\w*|blood\w*|bleed\w*|blut\w*|sang|sangre|sangra\w*)\b"
    ),
    # not "limpia" (clean) nor "boite" (box)
    "limping": re.compile(
        r"\b(?:zoppic\w*|limp(?:s|ed|ing)?|lahm\w*|hinkt|(?:il|elle) boite|boiterie|coje\w*)\b"
    ),
    "breathing trouble": re.compile(
        r"\b(?:affann\w*|respir\w* (?:male|a fatica|con fatica)|difficolta respirator\w*|"
        r"wheez\w*|breathless|short of breath|atemnot|keucht|respire mal|"
        r"dificultad respirator\w*)\b"
    ),
    "itching": re.compile(
        r"\b(?:prurit\w*|si gratta|itch\w*|juck\w*|demang\w*|picor\w*|se rasca)\b"
    ),
    "lethargy": re.compile(
        r"\b(?:abbattut\w*|letargic\w*|letargia|lethargic|lethargy|lustlos|apathisch|apathie|"
        r"abattu\w*|letargic\w*|apatic\w*|decaid\w*)\b"
    ),
    "weight loss": re.compile(
        r"\b(?:perso peso|dimagrit\w*|lost weight|losing weight|abgenommen|perdu du poids|"
        r"perdido peso|adelgaz\w*)\b"
    ),
}
# A sign said of the animal as a fact: a duration, or the animal (its name, "he", "she").
# Articles and formal pronouns ("il", "el", "Sie") are no subject: they were in nearly every
# sentence of the other languages.
_DURATION = re.compile(
    r"\b(?:da|seit|for|since|desde|depuis|hace)\s+(?:\w+\s+){0,3}?"
    r"(?:ieri|oggi|tag\w*|giorn\w*|days?|dias?|jours?|woche\w*|settiman\w*|weeks?|semana\w*|"
    r"ore|ora|hours?|horas?|heures?|stunde\w*|mesi|months?|monat\w*|mois|meses)\b"
    r"|\b(?:already|bereits) \w*"
)
_CONDITION = re.compile(
    r"\b(?:se|quando|if|when|whether|wenn|falls|ob|si|quand|lorsque|cuando|puo|possono|"
    r"potrebbe\w*|may|might|can|could|kann|konnen|konnte\w*|peut|peuvent|puede\w*|pueden|"
    r"ad esempio|per esempio|segni|signs?|symptome?\w*|sintomi|sintomas|signes?|anche|"
    r"o\b|or\b|oder|ou\b)\b"
)
_ANIMAL = re.compile(
    r"\b(?:he|she|his|her|suo|sua|er hat|er zeigt|sie hat|il a|elle a|elle est|ha|presenta|mostra|"
    r"tiene|sufre)\b"
)
# The sign is denied ("wurgen ohne erbrechen", "non ha febbre", "kein durchfall").
_DENIED = re.compile(
    r"\b(?:ohne|kein\w*|senza|non|no|not|never|without|sans|sin|ni|ne|pas|nicht|nessun\w*)\s+"
    r"(?:\w+\s+){0,2}$"
)


def _sign_in(text: str) -> set[str]:
    return {name for name, pattern in _SIGNS.items() if pattern.search(text)}


def _said(sentence: str) -> set[str]:
    """The signs of the sentence that are not denied."""
    return {
        name
        for name, pattern in _SIGNS.items()
        if any(not _DENIED.search(sentence[: m.start()]) for m in pattern.finditer(sentence))
    }


def invented_symptoms(answer: str, known_text: str, pet_name: str = "") -> list[str]:
    """The sentences of the answer that state, as a fact about the animal, a sign nobody told
    (normalized text)."""
    known = _sign_in(normalize_for_matching(known_text))
    name = normalize_for_matching(pet_name)
    out: list[str] = []
    for sentence in re.split(r"(?<=[.!?;])\s+|\n+", normalize_for_matching(answer)):
        invented = _said(sentence) - known
        if not invented or _CONDITION.search(sentence):
            continue
        if _DURATION.search(sentence) or _ANIMAL.search(sentence) or (name and name in sentence):
            out.append(sentence)
    return out
