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

import re

from packages.core.domain.localization import normalize_locale
from packages.core.domain.localization_fr import CLARIFYING_QUESTIONS_FR
from packages.core.domain.safety.emergency_patterns import normalize_for_matching
from packages.core.domain.safety.red_flags_de_fr import (
    GI_STASIS_DE,
    GI_STASIS_FR,
    IMMEDIATE_DE,
    IMMEDIATE_FR,
    REASSURING_DE,
    REASSURING_FR,
    TOXIN_MEDICATION_DE,
    TOXIN_MEDICATION_FR,
    URGENT_DE,
    URGENT_FR,
    WORSENING_DE,
    WORSENING_FR,
)

# A bird breathing with the beak open, tail bobbing at every breath:
# shared with the SafetyGate's species list (stress test 2026-11-06).
BIRD_RESPIRATORY_KEYWORDS: tuple[str, ...] = (
    "becco aperto",
    "a becco aperto",
    "respira con il becco",
    "coda a ogni respiro",
    "muove la coda a ogni respiro",
    "coda che si muove quando respira",
    "coda che pompa",
    "respiro affannoso",
    "open beak",
    "open-beak",
    "beak open",
    "tail bobbing",
    "tail bob",
    "pico abierto",
    "mueve la cola al respirar",
    "offenem schnabel",
    "schnabel offen",
    "schwanzwippen",
    "bec ouvert",
    "queue qui bouge a chaque respiration",
)

# A dog's antiparasitic on a cat (permethrin, stress test 2026-11-06):
# shared with the SafetyGate's cat list; category toxin_medication.
DOG_PRODUCT_ON_CAT_KEYWORDS: tuple[str, ...] = (
    "pipetta del cane",
    "pipetta per cani",
    "pipetta per il cane",
    "pipetta da cane",
    "antipulci del cane",
    "antipulci per cani",
    "antipulci per il cane",
    "antiparassitario del cane",
    "antiparassitario per cani",
    "antiparassitario per il cane",
    "spot-on del cane",
    "spot on del cane",
    "collare antiparassitario del cane",
    "collare antipulci del cane",
    "prodotto per cani",
    "dog's flea treatment",
    "dog flea treatment",
    "flea treatment for dogs",
    "dog's spot-on",
    "dog spot-on",
    "dog's pipette",
    "dog pipette",
    "pipeta del perro",
    "pipeta para perros",
    "antipulgas del perro",
    "antipulgas para perros",
    "spot-on vom hund",
    "spot-on fur hunde",
    "flohmittel vom hund",
    "flohmittel fur hunde",
    "pipette du chien",
    "pipette pour chien",
    "antipuces du chien",
    "antipuces pour chien",
)

# First aid categories (wide eval 2026-11-06), no clarifying question:
# each has its own fixed steps in localization.py.
HEATSTROKE_KEYWORDS: tuple[str, ...] = (
    "colpo di calore",
    "colpo di caldo",
    "caduto dopo la corsa",
    "crollato dopo la corsa",
    "crollato per il caldo",
    "collassato per il caldo",
    "chiuso in macchina al sole",
    "heat stroke",
    "heatstroke",
    "heat exhaustion",
    "collapsed after running",
    "collapsed in the heat",
    "golpe de calor",
    "hitzschlag",
    "coup de chaleur",
)
SNAKEBITE_KEYWORDS: tuple[str, ...] = (
    "vipera",
    "morso di vipera",
    "morso di serpente",
    "morsa da una vipera",
    "morso da una vipera",
    "morso da un serpente",
    "snake bite",
    "snakebite",
    "bitten by a snake",
    "bitten by a viper",
    "bitten by an adder",
    "vibora",
    "víbora",
    "mordedura de serpiente",
    "schlangenbiss",
    "kreuzotter",
    "von einer schlange gebissen",
    "vipere",
    "vipère",
    "morsure de serpent",
    "mordu par une vipere",
    "mordu par une vipère",
)
PROCESSIONARY_KEYWORDS: tuple[str, ...] = (
    "processionaria",
    "processionarie",
    "bruchi in fila",
    "bruchi pelosi",
    "bruco peloso",
    "processionary",
    "pine caterpillar",
    "hairy caterpillars",
    "procesionaria",
    "prozessionsspinner",
    "raupen",
    "processionnaire",
    "chenilles processionnaires",
)
FISH_DISTRESS_KEYWORDS: tuple[str, ...] = (
    "boccheggia",
    "boccheggiano",
    "a boccheggiare",
    "in superficie a boccheggiare",
    "tutti in superficie",
    "sta in superficie",
    "stanno in superficie",
    "pinne chiuse",
    "pancia in su",
    "a pancia in su",
    "galleggia su un fianco",
    "gasping at the surface",
    "gasping",
    "all at the surface",
    "floating on its side",
    "belly up",
    "clamped fins",
    "boquean",
    "boqueando",
    "en la superficie",
    "panza arriba",
    "schnappen nach luft",
    "an der oberflache",
    "an der oberfläche",
    "bauch nach oben",
    "piper a la surface",
    "pipent a la surface",
    "a la surface",
    "ventre en l'air",
)

# Synthetic users 2026-11-07 (P1): the phrasings of three real emergencies
# that the lists did not know, universal (every species).
FOREIGN_BODY_KEYWORDS: tuple[str, ...] = (
    "ha mangiato un calzino",
    "ha mangiato una calza",
    "ha mangiato un pezzo di gomma",
    "ha mangiato della gomma",
    "ha mangiato un pezzo di plastica",
    "ha mangiato un giocattolo",
    "ha mangiato uno spago",
    "ha mangiato un elastico",
    "ha mangiato un sasso",
    "ha mangiato un osso",
    "ha ingoiato un",
    "ha ingoiato una",
    "ha inghiottito un",
    "ha inghiottito una",
    "ha ingerito un corpo estraneo",
    "corpo estraneo",
    "swallowed a sock",
    "ate a sock",
    "swallowed a toy",
    "ate a toy",
    "swallowed a string",
    "ate rubber",
    "swallowed a",
    "foreign body",
    "se trago un calcetin",
    "se trago un juguete",
    "cuerpo extrano",
    "hat eine socke gefressen",
    "hat ein spielzeug verschluckt",
    "hat einen fremdkorper",
    "fremdkorper",
    "a avale une chaussette",
    "a avale un jouet",
    "corps etranger",
)
HARD_BELLY_KEYWORDS: tuple[str, ...] = (
    "pancia dura",
    "pancino duro",
    "addome duro",
    "pancia gonfia e dura",
    "hard belly",
    "swollen hard belly",
    "barriga dura",
    "harter bauch",
    "ventre dur",
)
STRAINING_URINE_KEYWORDS: tuple[str, ...] = (
    "non riesce a fare pipi",
    "non riesce a fare la pipi",
    "non riesce a fare pipì",
    "non riesce a fare la pipì",
    "non fa pipi",
    "non fa la pipi",
    "non fa pipì",
    "non fa la pipì",
    "urina a gocce",
    "pipi a gocce",
    "pipì a gocce",
    "gocce di pipi",
    "fa forza nella lettiera",
    "fa forza in lettiera",
    "sforza nella lettiera",
    "si sforza in lettiera",
    "sta nella lettiera e piange",
    "straining to pee",
    "straining to urinate",
    "dribbling urine",
    "pees in drops",
    "urine in drops",
    "no puede hacer pis",
    "orina a gotas",
    "kann nicht pinkeln",
    "tropfenweise urin",
    "n'arrive pas a uriner",
    "urine goutte a goutte",
)

# Small mammals say "palline": shared with the SafetyGate's species list.
SMALL_MAMMAL_STASIS_KEYWORDS: tuple[str, ...] = (
    "non fa palline",
    "non fa le palline",
    "non fa più palline",
    "non fa più le palline",
    "non fa pallin",
    "niente palline",
    "non mangia e non fa",
    "no droppings",
    "not pooping",
    "no poop",
    "no hace bolitas",
    "no hace caca",
    "keine kottel",
    "keine kotbällchen",
    "pas de crottes",
)

_STASIS_DURATION = re.compile(
    r"\b(?:ieri|stanotte|stamattina|da (?:\d+|molte|tante|diverse|parecchie) ore|da ore|"
    r"tutto il giorno|tutta la notte|yesterday|last night|this morning|for hours|"
    r"\d+ hours|all day|all night|ayer|anoche|esta manana|horas|gestern|heute morgen|"
    r"stunden|die ganze nacht|hier|cette nuit|ce matin|heures|toute la nuit)\b"
)


def small_mammal_stasis_is_immediate(category: str | None, family: str, message: str) -> bool:
    """A rabbit, guinea pig or hamster that has not eaten or passed
    droppings since last night: GI stasis is a matter of hours, so the
    clarifying question about hours is skipped (stress test 2026-11-06)."""
    if category != "gi_stasis" or family != "small_mammal":
        return False
    return bool(_STASIS_DURATION.search(normalize_for_matching(message)))


RED_FLAG_CATEGORIES: dict[str, tuple[str, ...]] = {
    # Wide eval 2026-11-06: first aid with its own fixed steps. First in the
    # dict: "lingua viola" after a run is a heatstroke before it is a
    # circulatory sign, and gets the shade-and-water steps.
    "heatstroke": HEATSTROKE_KEYWORDS,
    "snakebite": SNAKEBITE_KEYWORDS,
    "processionary": PROCESSIONARY_KEYWORDS,
    "fish_distress": FISH_DISTRESS_KEYWORDS,
    # Synthetic users 2026-11-07 (P1): a swallowed object or a hard belly
    # escalates at once; straining to urinate joins the urinary category.
    "foreign_body": FOREIGN_BODY_KEYWORDS,
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
        *STRAINING_URINE_KEYWORDS,
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
        # Rabbits, guinea pigs, hamsters: "palline" (stress test 2026-11-06).
        *SMALL_MAMMAL_STASIS_KEYWORDS,
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
        *DOG_PRODUCT_ON_CAT_KEYWORDS,
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
    "gastric_bloat": ("torsione gastrica", *HARD_BELLY_KEYWORDS),
    # A bird breathing with the beak open, tail bobbing at every breath
    # (stress test 2026-11-06): in birds this is late and serious, never
    # "after a run or at rest?" — straight to a vet who knows birds.
    "bird_respiratory": BIRD_RESPIRATORY_KEYWORDS,
    # Pale, white, grey or blue gums or tongue: shock, bleeding inside,
    # no oxygen. No clarifying question either.
    "circulatory": ("gengive pallide",),
}
# German and French (2026-10-26): the same categories, from red_flags_de_fr.py.
for _catalog in (URGENT_DE, URGENT_FR):
    for _category, _keywords in _catalog.items():
        RED_FLAG_CATEGORIES[_category] = RED_FLAG_CATEGORIES[_category] + _keywords
RED_FLAG_CATEGORIES["gi_stasis"] = RED_FLAG_CATEGORIES["gi_stasis"] + GI_STASIS_DE + GI_STASIS_FR
RED_FLAG_CATEGORIES["toxin_medication"] = (
    RED_FLAG_CATEGORIES["toxin_medication"] + TOXIN_MEDICATION_DE + TOXIN_MEDICATION_FR
)

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
    *IMMEDIATE_DE,
    *IMMEDIATE_FR,
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


_CLARIFYING_QUESTIONS_DE: dict[str, str] = {
    "respiratory": (
        "Zwei kurze Fragen, bevor ich Ihnen Hinweise gebe: Hat die schwere Atmung nach "
        "Rennen, wildem Spiel oder bei Hitze begonnen oder in Ruhe ohne erkennbaren Grund? "
        "Beruhigt sie sich gerade, bleibt sie gleich oder wird sie schlimmer?"
    ),
    "collapse": (
        "Zwei kurze Fragen: Ist Ihr Tier jetzt wach, reagiert es und bewegt es sich normal, "
        "oder liegt es noch am Boden und reagiert kaum? "
        "Hat die Episode Sekunden oder länger gedauert?"
    ),
    "seizure": (
        "Zwei kurze Fragen: Sind die Krampfanfälle vorbei und ist Ihr Tier wieder wach, "
        "oder passieren sie gerade noch? Ist es das erste Mal?"
    ),
    "bleeding_trauma": (
        "Zwei kurze Fragen: Blutet es gerade noch oder hat die Blutung aufgehört "
        "bzw. nachgelassen? "
        "Waren es ein paar Tropfen oder eine Menge, die Sie beunruhigt?"
    ),
    "urinary": (
        "Zwei kurze Fragen: Seit wie vielen Stunden hat Ihr Tier nicht mehr uriniert? "
        "Versucht es vergeblich zu urinieren oder zeigt es Schmerzen?"
    ),
    "gi_stasis": (
        "Zwei kurze Fragen: Seit genau wie vielen Stunden frisst Ihr Tier nicht und setzt "
        "keinen Kot ab? Hat es sich dem Futter genähert oder wenigstens ein paar "
        "kleine Kotstücke abgesetzt?"
    ),
}


# The same questions for a female animal, where the language marks the
# gender (Haiku round 2026-11-07: "da quante ore non lo vedi urinare?" to
# Nina). English, Spanish and German above are already neutral.
CLARIFYING_QUESTIONS_FEMALE: dict[str, dict[str, str]] = {
    "it": {
        "collapse": (
            "Prima di darti indicazioni, un paio di cose veloci: adesso è sveglia, ti "
            "risponde e si muove normalmente, oppure è ancora a terra o poco reattiva? "
            "E l'episodio è durato pochi secondi o più a lungo?"
        ),
        "seizure": (
            "Prima di darti indicazioni, un paio di cose veloci: le convulsioni sono già "
            "finite ed è tornata vigile, oppure stanno ancora succedendo adesso? Ed è la "
            "prima volta che capita?"
        ),
        "urinary": (
            "Prima di darti indicazioni, un paio di cose veloci: da quante ore non la "
            "vedi urinare? E la vedi provarci senza risultato o lamentarsi, oppure "
            "sembra solo che non ne abbia avuto occasione?"
        ),
    },
    "es": {
        "collapse": (
            "Dos preguntas rápidas: ¿ahora está despierta, responde y se mueve con "
            "normalidad, o sigue en el suelo y poco reactiva? ¿El episodio duró segundos o "
            "más tiempo?"
        ),
    },
    "fr": {
        "collapse": (
            "Deux questions rapides : est-elle maintenant éveillée, réactive et se "
            "déplace-t-elle normalement, ou reste-t-elle au sol et peu réactive ? "
            "L'épisode a-t-il duré quelques secondes ou plus longtemps ?"
        ),
        "seizure": (
            "Deux questions rapides : les convulsions sont-elles terminées et est-elle "
            "redevenue attentive, ou continuent-elles en ce moment ? Est-ce la première "
            "fois ?"
        ),
        "bleeding_trauma": (
            "Deux questions rapides : saigne-t-elle encore ou le saignement s'est-il "
            "arrêté ou réduit ? Était-ce quelques gouttes ou une quantité qui vous "
            "inquiète ?"
        ),
        "urinary": (
            "Deux questions rapides : depuis combien d'heures n'a-t-elle pas uriné ? "
            "Essaie-t-elle sans y parvenir ou montre-t-elle de la douleur ?"
        ),
        "gi_stasis": (
            "Deux questions rapides : depuis combien d'heures exactement n'a-t-elle ni "
            "mangé ni fait ses besoins ? S'est-elle approchée de la nourriture ou "
            "a-t-elle produit ne serait-ce que quelques petites selles ?"
        ),
    },
}


# Questions written for one kind of animal (2026-11-10: "how many hours without
# eating or passing droppings" was asked about a dog that vomited): gut stasis
# is a rabbit's and rodent's emergency, so its question goes to them only.
_CATEGORY_FAMILIES: dict[str, frozenset[str]] = {
    "gi_stasis": frozenset({"small_mammal"}),
}


def clarifying_question(
    category: str | None,
    locale: str,
    *,
    female: bool = False,
    family: str | None = None,
) -> str | None:
    """The fixed clarifying question of [category] in [locale]; None when
    there is none, or when it is written for another kind of animal than
    [family] (None = do not check the species)."""
    if category is None:
        return None
    allowed = _CATEGORY_FAMILIES.get(category)
    if allowed is not None and family is not None and family not in allowed:
        return None
    if female:
        variant = CLARIFYING_QUESTIONS_FEMALE.get(normalize_locale(locale), {}).get(category)
        if variant is not None:
            return variant
    catalogs = {
        "it": CLARIFYING_QUESTIONS,
        "en": _CLARIFYING_QUESTIONS_EN,
        "es": _CLARIFYING_QUESTIONS_ES,
        "de": _CLARIFYING_QUESTIONS_DE,
        "fr": CLARIFYING_QUESTIONS_FR,
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
        "après avoir couru",
        "après avoir joué",
        "il fait chaud",
        "il se calme",
        "respire normalement",
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
        "a arrêté de saigner",
        "quelques gouttes",
        "une égratignure",
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
        "vient d'uriner",
        "seulement quelques heures",
    ),
    # Deliberately empty, like "seizure": GI stasis in a small mammal can
    # progress to fatal within hours, and there's no reply that makes it
    # genuinely safe to relax — the clarifying question is still useful to
    # gather duration/detail, but it must not be able to downgrade severity.
    "gi_stasis": (),
}
for _catalog in (REASSURING_DE, REASSURING_FR):
    for _category, _markers in _catalog.items():
        REASSURING_MARKERS[_category] = REASSURING_MARKERS[_category] + _markers

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
    "il empire",
    "ça empire",
    "ne s'améliore pas",
    "toujours à terre",
    "saigne encore",
    "continue de saigner",
    "ne répond pas",
    "ne se réveille pas",
    *WORSENING_DE,
    *WORSENING_FR,
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
