"""A brief, category-specific safety clarification step (spec v3 §9).

Owners rarely have veterinary vocabulary, and anxious owners often
describe a normal reaction (a puppy panting hard after running in the
heat) using the same words as a real emergency ("non respira bene"). This
module lets the SafetyGate ask ONE short, targeted question — not a
generic "are you sure?" — before deciding how urgently to respond.

The guiding rule (spec v3 §9): uncertainty must never be converted into
reassurance. Every branch here defaults to the more cautious outcome
unless the reply gives a clear, specific, benign explanation.
"""

RED_FLAG_CATEGORIES: dict[str, tuple[str, ...]] = {
    "respiratory": ("non respira", "respira male", "dispnea"),
    "collapse": ("collasso", "collapse"),
    "seizure": ("convuls", "seizure"),
    "bleeding_trauma": ("emorrag", "sanguina", "trauma", "incidente"),
    "urinary": ("anuria", "non urina"),
}

# If the very first message already describes an unambiguous, ongoing
# severe presentation, asking a clarifying question would only delay real
# emergency care — skip straight to escalation.
IMMEDIATE_ESCALATION_MARKERS: tuple[str, ...] = (
    "incosciente",
    "non si sveglia",
    "non risponde più",
    "non respira per niente",
    "smesso di respirare",
    "labbra blu",
    "gengive bianche",
    "sangue ovunque",
    "emorragia grave",
)

CLARIFYING_QUESTIONS: dict[str, str] = {
    "respiratory": (
        "Prima di darti indicazioni, un paio di cose veloci: il fiato affannoso è "
        "iniziato dopo una corsa, un gioco intenso o con il caldo, oppure a riposo "
        "senza motivo? E adesso, mentre mi scrivi, si sta calmando o resta uguale "
        "o peggiora?"
    ),
    "collapse": (
        "Prima di darti indicazioni, un paio di cose veloci: adesso è sveglio, ti "
        "risponde e si muove normalmente, oppure è ancora a terra o poco reattivo? "
        "E l'episodio è durato pochi secondi o più a lungo?"
    ),
    "seizure": (
        "Prima di darti indicazioni, un paio di cose veloci: le convulsioni sono già "
        "finite ed è tornato vigile, oppure stanno ancora succedendo adesso? Ed è la "
        "prima volta che capita?"
    ),
    "bleeding_trauma": (
        "Prima di darti indicazioni, un paio di cose veloci: il sangue sta ancora "
        "uscendo adesso o si è già fermato o rallentato? E quanto ne hai visto — "
        "poche gocce o una quantità che ti preoccupa?"
    ),
    "urinary": (
        "Prima di darti indicazioni, un paio di cose veloci: da quante ore non lo "
        "vedi urinare? E lo vedi provarci senza risultato o lamentarsi, oppure "
        "sembra solo che non ne abbia avuto occasione?"
    ),
}

# Category-specific phrases that, if present, point to the kind of benign
# explanation vets rule out first for that presentation. Deliberately
# empty for "seizure": there is no benign explanation for a seizure, so
# that category always escalates regardless of the reply.
REASSURING_MARKERS: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "dopo la corsa",
        "ha corso",
        "giocato",
        "il caldo",
        "fa caldo",
        "si è calmato",
        "si sta calmando",
        "respira normale",
        "è tranquillo",
        "sta meglio",
    ),
    "collapse": (
        "sveglio",
        "normale ora",
        "si è ripreso",
        "pochi secondi",
        "reattivo",
        "sta bene ora",
        "cammina normale",
    ),
    "seizure": (),
    "bleeding_trauma": (
        "si è fermato",
        "si è rallentato",
        "poche gocce",
        "quasi niente",
        "un graffio",
    ),
    "urinary": (
        "ha appena urinato",
        "non ne ha avuto occasione",
        "solo un paio d'ore",
        "poche ore",
    ),
}

# Category-independent: any of these in the reply means "still bad or
# getting worse" and must override any reassuring marker.
WORSENING_MARKERS: tuple[str, ...] = (
    "peggiora",
    "sempre uguale",
    "non migliora",
    "ancora a terra",
    "non si riprende",
    "continua a sanguinare",
    "ancora convulsioni",
    "sta peggiorando",
    "non si sveglia",
    "non risponde",
)


def categorize(safety_flags: list[str]) -> str | None:
    """Maps the SafetyGate's matched keywords to one clarification
    category. Returns None if no category is recognized (shouldn't happen
    given RED_FLAG_CATEGORIES covers every SafetyGate keyword, but the
    caller must fail safe — immediate escalation — if it ever does)."""
    matched = set(safety_flags)
    for category, keywords in RED_FLAG_CATEGORIES.items():
        if matched & set(keywords):
            return category
    return None


def requires_immediate_escalation(message: str) -> bool:
    lowered = message.lower()
    return any(marker in lowered for marker in IMMEDIATE_ESCALATION_MARKERS)


def classify_severity(category: str, reply: str) -> str:
    """Returns "moderate" only when the reply gives a clear, specific,
    benign explanation for this category and nothing suggests it's
    worsening. Every other case — including an unclear or off-topic
    reply — returns "high" (fail closed; spec v3 §9)."""
    lowered = reply.lower()
    if any(marker in lowered for marker in WORSENING_MARKERS):
        return "high"
    reassuring = REASSURING_MARKERS.get(category, ())
    if reassuring and any(marker in lowered for marker in reassuring):
        return "moderate"
    return "high"
