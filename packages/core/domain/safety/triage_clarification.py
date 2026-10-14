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

from packages.core.domain.localization import normalize_locale

RED_FLAG_CATEGORIES: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "cannot breathe",
        "can't breathe",
        "not breathing",
        "difficulty breathing",
        "struggling to breathe",
        "open mouth breathing",
        "no puede respirar",
        "no respira",
        "dificultad para respirar",
        "respira con la boca abierta",
        "non respira",
        "respira male",
        "dispnea",
        "fatica a respirare",
        "respira a fatica",
        "respira con fatica",
        "respira a bocca aperta",
        "respira con la bocca aperta",
        "non riesce a respirare",
    ),
    "collapse": ("collasso", "collapse", "colapso"),
    "seizure": ("convuls", "seizure"),
    "bleeding_trauma": (
        "emorrag",
        "sanguina",
        "trauma",
        "incidente",
        "bleeding",
        "hemorrhage",
        "blood in vomit",
        "vomiting blood",
        "blood in stool",
        "blood in urine",
        "sangra",
        "sangre en",
        "vomita sangre",
        "accident",
        "accidente",
    ),
    "urinary": (
        "anuria",
        "non urina",
        "cannot urinate",
        "can't urinate",
        "not urinating",
        "no orina",
        "no puede orinar",
    ),
    # Small-mammal-specific (spec: species safety calibration) — unlike
    # the categories above, duration genuinely changes the picture here
    # (a couple of hours vs. a full day), so it's worth one clarifying
    # question rather than treating every mention as equally urgent.
    "gi_stasis": (
        "not eaten for a day",
        "not eating since yesterday",
        "not passing stool",
        "stopped eating",
        "no come desde ayer",
        "no defeca",
        "ha dejado de comer",
        "non mangia da un giorno",
        "non mangia da ieri",
        "non mangia da 24 ore",
        "non fa la cacca",
        "non fa cacca",
        "non defeca",
        "non produce feci",
        "non fa feci",
        "non fa le feci",
        "non fa più le feci",
        "non fa più la cacca",
        "non fa più cacca",
        "ha smesso di mangiare",
        "non mangia più",
        "non mangia da stamattina",
        "niente cacca",
    ),
    # Real-world finding (2026-09-25, reported via gestore git): a
    # medication/toxin mention (e.g. "che dosaggio di ibuprofene posso
    # darle?") had no category here, so it fell through to the generic
    # "no mapped category" fail-safe — which still escalates correctly,
    # but with wording written for a NARRATED SYMPTOM ("quello che mi
    # racconti di Moka è un segnale...") that reads as nonsense when the
    # actual trigger was a question about a substance/dose, not something
    # observed. Deliberately has NO entry in CLARIFYING_QUESTIONS below
    # (see there): the original real-world finding for these substances
    # was "always escalate, whether given or only proposed" — zero delay,
    # unlike seizure/gi_stasis where one quick question is worth asking
    # first. ChatOrchestrator._urgent_triage_result uses this category
    # only to pick substance-appropriate phrasing, not to gate on a reply.
    "toxin_medication": (
        "ibuprofen",
        "paracetamol",
        "acetaminophen",
        "aspirin",
        "aspirina",
        "permethrin",
        "permetrina",
        "chocolate",
        "grapes",
        "raisins",
        "xylitol",
        "onion",
        "garlic",
        "uvas",
        "pasas",
        "xilitol",
        "cebolla",
        "ajo",
        "amoxicillina",
        "penicillina",
        "clindamicina",
        "lincomicina",
        "eritromicina",
        "ibuprofene",
        "brufen",
        "nurofen",
        "oki",
        "artrosilene",
        "ketoprofene",
        "aspirina",
        "acido acetilsalicilico",
        "voltaren",
        "dicloreum",
        "diclofenac",
        "tachipirina",
        "paracetamolo",
        "acetaminofene",
        "advantix",
        "vectra",
        "exspot",
        "permetrina",
        "cioccolat",
        "uva",
        "uvetta",
        "xilitolo",
        "cipolla",
        "aglio",
        # emergency_patterns.py (2026-10-14)
        "rodenticida",
        "antigelo",
        "giglio",
    ),
    # Gastric dilatation-volvulus: torsion, unproductive retching, a belly
    # swelling hard — kills within hours. No clarifying question, like
    # toxin_medication: asking first would only cost time.
    "gastric_bloat": ("torsione gastrica",),
    # Pale, white, grey or blue gums or tongue: shock, bleeding inside,
    # no oxygen. No clarifying question either.
    "circulatory": ("gengive pallide",),
}

# If the very first message already describes an unambiguous, ongoing
# severe presentation, asking a clarifying question would only delay real
# emergency care — skip straight to escalation.
IMMEDIATE_ESCALATION_MARKERS: tuple[str, ...] = (
    "cannot breathe",
    "can't breathe",
    "not breathing",
    "unconscious",
    "blue gums",
    "white gums",
    "severe bleeding",
    "no puede respirar",
    "no respira",
    "inconsciente",
    "encías azules",
    "encías blancas",
    "hemorragia grave",
    "incosciente",
    "non si sveglia",
    "non risponde più",
    "non respira per niente",
    "smesso di respirare",
    # 2026-10-05 evaluation: "fa molta fatica a respirare" was met with the
    # "after a run, or at rest?" question. Said this strongly, it is not
    # the ambiguous panting that question exists for.
    "molta fatica a respirare",
    "non riesce a respirare",
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
    "gi_stasis": (
        "Prima di darti indicazioni, un paio di cose veloci: da quante ore esattamente "
        "non mangia e non fa la cacca? E in queste ore ha comunque provato ad "
        "avvicinarsi al cibo o prodotto anche solo poche piccole feci, oppure "
        "niente del tutto?"
    ),
    # No entry for "toxin_medication" — see its comment in
    # RED_FLAG_CATEGORIES: unlike seizure/gi_stasis, product decision here
    # is to escalate immediately with zero delay (spec v3 §9 predates this
    # category, but the original SPECIES_SPECIFIC_RED_FLAGS finding was
    # explicit: "always escalate, whether the substance was already given
    # or only proposed" — asking a question first would work against
    # that). See test_triage_clarification.py's completeness test for the
    # documented exception.
}

_CLARIFYING_QUESTIONS_EN: dict[str, str] = {
    "respiratory": (
        "Two quick questions before I guide you: did the heavy breathing start after "
        "running, intense play or heat, or while resting without an obvious reason? "
        "Right now, is it settling, staying the same or getting worse?"
    ),
    "collapse": (
        "Two quick questions: is your pet awake, responsive and moving normally now, "
        "or still down and poorly responsive? Did the episode last seconds or longer?"
    ),
    "seizure": (
        "Two quick questions: have the seizures stopped and is your pet alert again, "
        "or are they still happening now? Is this the first episode?"
    ),
    "bleeding_trauma": (
        "Two quick questions: is the bleeding continuing now, or has it stopped or slowed? "
        "Was it a few drops or an amount that worries you?"
    ),
    "urinary": (
        "Two quick questions: how many hours has it been since your pet urinated? "
        "Are they trying without success or showing pain?"
    ),
    "gi_stasis": (
        "Two quick questions: exactly how many hours has your pet gone without eating or "
        "passing stool? Have they approached food or passed even a few small stools?"
    ),
}

_CLARIFYING_QUESTIONS_ES: dict[str, str] = {
    "respiratory": (
        "Dos preguntas rápidas antes de orientarte: ¿la respiración agitada empezó después "
        "de correr, jugar o pasar calor, o estando en reposo? ¿Ahora se está calmando, "
        "sigue igual o empeora?"
    ),
    "collapse": (
        "Dos preguntas rápidas: ¿ahora está despierto, responde y se mueve con normalidad, "
        "o sigue en el suelo y poco reactivo? ¿El episodio duró segundos o más tiempo?"
    ),
    "seizure": (
        "Dos preguntas rápidas: ¿las convulsiones han terminado y vuelve a estar alerta, "
        "o siguen ocurriendo ahora? ¿Es la primera vez?"
    ),
    "bleeding_trauma": (
        "Dos preguntas rápidas: ¿sigue sangrando ahora o se ha detenido o reducido? "
        "¿Fueron unas gotas o una cantidad que te preocupa?"
    ),
    "urinary": (
        "Dos preguntas rápidas: ¿cuántas horas lleva sin orinar? "
        "¿Intenta hacerlo sin conseguirlo o muestra dolor?"
    ),
    "gi_stasis": (
        "Dos preguntas rápidas: ¿cuántas horas exactas lleva sin comer ni defecar? "
        "¿Se ha acercado a la comida o ha producido aunque sea unas pocas heces?"
    ),
}


def clarifying_question(category: str | None, locale: str) -> str | None:
    if category is None:
        return None
    catalogs = {
        "it": CLARIFYING_QUESTIONS,
        "en": _CLARIFYING_QUESTIONS_EN,
        "es": _CLARIFYING_QUESTIONS_ES,
    }
    return catalogs[normalize_locale(locale)].get(category)


# Category-specific phrases that, if present, point to the kind of benign
# explanation vets rule out first for that presentation. Deliberately
# empty for "seizure": there is no benign explanation for a seizure, so
# that category always escalates regardless of the reply.
REASSURING_MARKERS: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "after running",
        "after playing",
        "hot weather",
        "settling down",
        "breathing normally",
        "después de correr",
        "después de jugar",
        "hace calor",
        "se está calmando",
        "respira normal",
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
        "awake now",
        "recovered",
        "few seconds",
        "walking normally",
        "despierto ahora",
        "se ha recuperado",
        "pocos segundos",
        "camina normal",
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
        "bleeding stopped",
        "few drops",
        "a scratch",
        "dejó de sangrar",
        "pocas gotas",
        "un arañazo",
        "si è fermato",
        "si è rallentato",
        "poche gocce",
        "quasi niente",
        "un graffio",
    ),
    "urinary": (
        "just urinated",
        "only a couple of hours",
        "acaba de orinar",
        "solo un par de horas",
        "ha appena urinato",
        "non ne ha avuto occasione",
        "solo un paio d'ore",
        "poche ore",
    ),
    # Deliberately empty, like "seizure": GI stasis in a small mammal can
    # progress to fatal within hours, and there's no reply that makes it
    # genuinely safe to relax — the clarifying question is still useful to
    # gather duration/detail, but it must not be able to downgrade severity.
    "gi_stasis": (),
}

# Category-independent: any of these in the reply means "still bad or
# getting worse" and must override any reassuring marker.
WORSENING_MARKERS: tuple[str, ...] = (
    "getting worse",
    "not improving",
    "still down",
    "still bleeding",
    "empeora",
    "no mejora",
    "sigue en el suelo",
    "sigue sangrando",
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
