"""First aid that the generic triage text gets wrong (wide eval 2026-11-06).

"Tieni Toby al caldo" to a dog collapsed after a run in the heat, "chiama
il veterinario" for an aquarium, a tourniquet left to the owner's
imagination after a viper bite: the fixed triage steps are chosen by
category and by family here, and the toxin a dog has NOT eaten yet gets
"no, never" instead of an emergency. Five languages, no model.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching

# Heat in the owner's words: the generic steps must not say "al caldo".
_HEAT = re.compile(
    r"\b(?:caldo|calda|afa|afoso|sole|canicola|estate|gradi|in macchina|auto al sole|"
    r"corsa|corso|dopo la corsa|esercizio|jogging|"
    r"run|running|after a run|exercise|carrera|correr|lauf|gelaufen|course|couru|"
    r"heat|hot|sun|heatwave|summer|degrees|in the car|calor|sol|verano|hitze|heiss|sonne|"
    r"sommer|chaleur|chaud|soleil|canicule|ete)\b"
)


def mentions_heat(message: str) -> bool:
    return bool(_HEAT.search(normalize_for_matching(message)))


# "Prima mi hai detto che posso dargli il paracetamolo": the chat never did.
_CLAIMS_I_SAID = re.compile(
    r"\b(?:prima )?(?:mi hai|mi avevi|hai|avevi) (?:detto|scritto|consigliato|suggerito)|"
    r"\b(?:you|u) (?:said|told me|wrote|suggested|recommended)|\bearlier you\b|"
    r"\b(?:me dijiste|me habias dicho|dijiste|me recomendaste)|"
    r"\b(?:du hast|sie haben) (?:gesagt|geschrieben|empfohlen)|"
    r"\b(?:tu m'as|vous m'avez) (?:dit|ecrit|conseille)"
)


def claims_the_chat_said_so(message: str) -> bool:
    return bool(_CLAIMS_I_SAID.search(normalize_for_matching(message)))


FALSE_MEMORY_PREFIX: dict[str, str] = {
    "it": "Non te l'ho detto, e non te lo direi. ",
    "en": "I did not say that, and I would not. ",
    "es": "No te lo he dicho, y no te lo diría. ",
    "de": ("Das habe ich nicht gesagt, und das würde ich auch nicht sagen. "),
    "fr": "Je ne vous l'ai pas dit, et je ne le dirais pas. ",
}

# "No, never" for a toxin the owner is about to give (not yet given):
# {why} is the substance's own sentence (human_drug_toxicity.py) or the
# generic one below.
TOXIN_INTENT_TEXTS: dict[str, str] = {
    "it": (
        "No, mai. {why} Non esiste una quantità piccola che vada bene, nemmeno 'naturale' o "
        "'per una volta'. Se {name} ne ha già preso, anche poco, chiama subito il veterinario "
        "o un pronto soccorso veterinario. Se mi dici cosa volevi ottenere, ti spiego cosa si "
        "usa davvero e cosa decide il veterinario."
    ),
    "en": (
        "No, never. {why} There is no small amount that is fine, not even 'natural' or "
        "'just once'. If {name} has already had some, even a little, call your vet or an "
        "emergency clinic right away. Tell me what you wanted to achieve and I will explain "
        "what is really used and what the vet decides."
    ),
    "es": (
        "No, nunca. {why} No existe una cantidad pequeña que valga, ni 'natural' ni 'por una "
        "vez'. Si {name} ya ha tomado algo, aunque sea poco, llama ahora mismo al veterinario o "
        "a urgencias veterinarias. Dime qué querías conseguir y te explico qué se usa de "
        "verdad y qué decide el veterinario."
    ),
    "de": (
        "Nein, niemals. {why} Es gibt keine kleine Menge, die in Ordnung wäre, auch nicht "
        "'natürlich' oder 'nur einmal'. Falls {name} schon etwas davon bekommen hat, auch nur "
        "wenig, rufen Sie sofort Ihre Tierarztpraxis oder einen Notdienst an. Sagen Sie mir, was "
        "Sie erreichen wollten, und ich erkläre, was wirklich verwendet wird und was die Praxis "
        "entscheidet."
    ),
    "fr": (
        "Non, jamais. {why} Il n'existe pas de petite quantité acceptable, ni 'naturelle' ni "
        "'pour une fois'. Si {name} en a déjà pris, même un peu, appelez tout de suite votre "
        "vétérinaire ou un service d'urgences. Dites-moi ce que vous vouliez obtenir et je vous "
        "expliquerai ce qui s'utilise vraiment et ce que décide le vétérinaire."
    ),
}

GENERIC_TOXIN_WHY: dict[str, str] = {
    "it": "Quella sostanza è pericolosa per {name} anche in piccole quantità.",
    "en": "That substance is dangerous for {name} even in small amounts.",
    "es": "Esa sustancia es peligrosa para {name} incluso en pequeñas cantidades.",
    "de": "Dieser Stoff ist für {name} schon in kleinen Mengen gefährlich.",
    "fr": "Cette substance est dangereuse pour {name} même en petite quantité.",
}

# A dose asked next to another question ("il CBD funziona? quante gocce?"):
# the amount is refused in one fixed sentence, the rest goes to the model.
DOSE_PART_REFUSED: dict[str, str] = {
    "it": "Sulla quantità non ti rispondo: gocce e dosi le decide il veterinario per {name}. ",
    "en": "On the amount I will not answer: drops and doses are the vet's call for {name}. ",
    "es": "Sobre la cantidad no te respondo: gotas y dosis las decide el veterinario para {name}. ",
    "de": (
        "Zur Menge sage ich nichts: Tropfen und Dosen legt die Tierarztpraxis für {name} fest. "
    ),
    "fr": (
        "Sur la quantité je ne réponds pas : gouttes et doses, c'est le vétérinaire qui décide "
        "pour {name}. "
    ),
}

_QUESTION_SPLIT = re.compile(r"(?<=\?)\s+|\s*\?\s*$")
_AMOUNT_CLAUSE = re.compile(
    r"\b(?:quant[oaie]|gocce|dose|dosi|dosaggio|compress\w*|pastigli\w*|mg|ml|gliene|ne do|"
    r"how (?:much|many)|drops?|dose|dosage|tablets?|cuant[oa]s?|gotas|dosis|wie ?viel|tropfen|"
    r"combien|gouttes?)\b"
)


def has_a_question_besides_the_dose(message: str) -> bool:
    """True when the message asks something else besides the amount: that
    part deserves an answer, the amount gets the fixed sentence."""
    text = normalize_for_matching(message)
    questions = [q.strip() for q in re.findall(r"([^?]+)\?", text) if q.strip()]
    if len(questions) < 2:
        return False
    others = [q for q in questions if not _AMOUNT_CLAUSE.search(q) and len(q.split()) >= 3]
    return bool(others)


# A country named by the owner that is not Italy: the Italian duty notes
# stay out, the answer sends to the local authority.
_FOREIGN_COUNTRY = re.compile(
    r"\b(?:uk|u\.k\.|regno unito|gran bretagna|inghilterra|england|britain|british|scotland|"
    r"scozia|wales|galles|irlanda|ireland|irish|germania|germany|deutschland|austria|svizzera|"
    r"switzerland|schweiz|suisse|francia|france|french|spagna|spain|espana|portogallo|portugal|"
    r"belgio|belgium|belgique|olanda|paesi bassi|netherlands|nederland|holland|danimarca|"
    r"denmark|svezia|sweden|norvegia|norway|finlandia|finland|polonia|poland|grecia|greece|"
    r"usa|u\.s\.|stati uniti|united states|america|american|canada|australia|australian|"
    r"nuova zelanda|new zealand|brasile|brazil|brasil|messico|mexico|argentina|cile|chile|"
    r"colombia|peru|giappone|japan|cina|china|india|sudafrica|south africa)\b"
)
_ITALY = re.compile(r"\b(?:italia|italy|italien|italie|italian[oa]?|italienisch\w*)\b")


def named_foreign_country(message: str) -> bool:
    """The owner names a country other than Italy ("do I need to microchip
    my dog by law in the UK?"): no Italian rules in the answer."""
    text = normalize_for_matching(message)
    return bool(_FOREIGN_COUNTRY.search(text)) and not _ITALY.search(text)


# A new behaviour in an old animal, or house soiling: a medical cause is
# ruled out first.
HOUSE_SOILING = re.compile(
    r"pipi (?:sul|nel|in|fuori|dappertutto|per casa)|fa (?:la )?pipi (?:sul|nel|in casa|fuori)|"
    r"fuori dalla lettiera|urina (?:in casa|sul|nel|fuori)|sporca in casa|marca in casa|"
    r"la cacca fuori|pees? on the|peeing on|outside the litter|urinat\w* (?:in the house|on the)|"
    r"orina (?:en la cama|fuera|en casa)|fuera del arenero|pinkelt (?:ins|auf|in die wohnung)|"
    r"neben das katzenklo|pipi (?:sur|dans la maison|hors)|a cote de la litiere"
)
_NEW_BEHAVIOUR = re.compile(
    r"(?:iniziato|cominciato) da poco|da (?:poco|qualche (?:giorno|settimana))|"
    r"non (?:l'ha|lo ha|l'aveva) mai fatto|all'improvviso|improvvisamente|ultimamente|da un po'|"
    r"started (?:recently|lately|suddenly)|never did (?:this|that) before|suddenly|out of the blue|"
    r"empezo hace poco|de repente|nunca lo habia hecho|seit kurzem|plotzlich|noch nie gemacht|"
    r"depuis peu|soudain|tout d'un coup|n'avait jamais fait"
)
_OLD = re.compile(
    r"\b(?:anzian[oa]|vecchi[oa]|vecchiett[oa]|(?:1[0-9]|[89]) anni|senior|old|elderly|"
    r"(?:1[0-9]|[89]) years|viej[oa]|(?:1[0-9]|[89]) anos|alt|(?:1[0-9]|[89]) jahre|age|vieux|"
    r"vieille|(?:1[0-9]|[89]) ans)\b"
)


def medical_cause_first(message: str, age_years: int | None) -> bool:
    text = normalize_for_matching(message)
    if HOUSE_SOILING.search(text):
        return True
    old = (age_years is not None and age_years >= 8) or bool(_OLD.search(text))
    return old and bool(_NEW_BEHAVIOUR.search(text))


# A dog travelling to southern Italy or the islands: leishmaniosis.
_SOUTH = re.compile(
    r"\b(?:sardegna|sicilia|puglia|calabria|campania|basilicata|salento|gargano|cilento|"
    r"isol[ae]|elba|ischia|capri|sud italia|al sud|nel sud|meridione|liguria|toscana|lazio|"
    r"maremma|sardinia|sicily|southern italy|south of italy|apulia|tuscany|mediterranean|"
    r"cerdena|sicilia|sur de italia|sardinien|sizilien|suditalien|sardaigne|sicile|"
    r"sud de l'italie)\b"
)
_TRAVEL = re.compile(
    r"\b(?:porto|portiamo|portare|andiamo|vado|vacanz\w*|ferie|viaggi\w*|agosto|luglio|giugno|"
    r"settembre|estate|al mare|campeggio|taking|take|travel\w*|holiday\w*|trip|going to|summer|"
    r"llevo|vacaciones|viaj\w*|verano|urlaub|reise\w*|mitnehmen|sommer|vacances|voyage\w*|emmener|"
    r"ete)\b"
)


def travel_to_sand_fly_area(message: str, family: str) -> bool:
    text = normalize_for_matching(message)
    return family == "dog" and bool(_SOUTH.search(text) and _TRAVEL.search(text))
