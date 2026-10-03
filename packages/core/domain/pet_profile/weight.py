"""When a missing body weight is worth mentioning to the owner.

Weight is optional in the pet profile. Most conversations don't need it,
but a few topics genuinely depend on it — there the chat suggests adding
it to the profile, once per conversation, never as a blocker.
"""

from packages.core.domain.knowledge.fuzzy_match import contains_keyword

# Stems match every inflection (word-prefix matching, see contains_keyword);
# multi-word entries match exactly.
WEIGHT_RELEVANT_MARKERS: tuple[str, ...] = (
    # dosing
    "dosaggio",
    "dose",
    "dosi",
    "posologia",
    "quanti mg",
    "quanti ml",
    # feeding / body condition
    "alimentazione",
    "dieta",
    "razione",
    "porzion",
    "quanto cibo",
    "quanti grammi",
    "crocchett",
    "quanto mangia",
    "quanto deve mangiare",
    "quanto dargli",
    "quanto darle",
    "sovrappeso",
    "sottopeso",
    "obes",
    "dimagr",
    "ingrass",
    "peso",
    # anaesthesia
    "anestesi",
    "sedazion",
    # parasite control (products are dosed by weight band)
    "antiparassitar",
    "antipulci",
    "vermifug",
    "sverminazion",
    "pipetta",
    "spot on",
)

# Distinctive phrase of the suggestion itself — also how an earlier
# suggestion is recognised in the conversation history, so it is made
# once and not repeated.
WEIGHT_SUGGESTION_MARKER = "manca il peso"


def is_weight_relevant(message: str) -> bool:
    lowered = message.lower().replace("-", " ")
    return any(contains_keyword(lowered, marker) for marker in WEIGHT_RELEVANT_MARKERS)


def weight_suggestion(pet_name: str) -> str:
    return (
        f"Un'ultima cosa: nel profilo di {pet_name} {WEIGHT_SUGGESTION_MARKER}. "
        "Se lo aggiungi dalla sua scheda potrò tenerne conto nelle prossime risposte."
    )
