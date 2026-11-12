"""Places that are only a person: never on the map (owner's decision,
2026-11-08).

Open datasets list some practitioners under their own name ("Dott. Mario
Rossi", "Rossi Maria"), often at what may be a home address. The radar
shows facilities only, at the facility's address: an entry whose name is
just a person is dropped on import, from the live cache and from every
answer.

Recognised as a person, unless the name says it is a facility (a word such
as ambulatorio, clinica, studio, centro, pet shop, Tierarztpraxis, clinic,
or a company form such as srl, gmbh, ltd):
- a title followed by a name: "Dott.ssa Anna Bianchi", "Dr. Smith";
- two to four words, one of them a common first name, and nothing else:
  "Bianchi Anna", "Mario Rossi", "Anna Maria Bianchi".

Deliberately not a person: names with "e" / "&" ("Mario e Luca"), saints
and places ("Santa Lucia", "San Marco"), fantasy names without a first
name ("La Cagneria", "Albero Verde"). A person not recognised stays
visible and can be removed on request (scripts/radar/remove_reported_place.py).
The names below are common given names, not data about anyone.
"""

import re
import unicodedata

# Words that make a name a facility in any of the radar's languages. A
# profession alone ("veterinario", "educatore cinofilo", "dog sitter") is
# not one: "Mario Rossi Veterinario" is a person without a facility.
_FACILITY = re.compile(
    r"ambulator|clinic|klinik|clínic|studio|centr|center|ospedal|hospital|hôpital|"
    r"praxis|cabinet|consultori|surgery|practice|"
    r"animal|zoo|grooming|pension|hotel|allevament|kennel|cattery|"
    r"canil|gattil|rifugi|refuge|shelter|associaz|association|verein|\basd\b|club|"
    r"negozi|shop|store|uccelleri|acquari|aquari|mangim|farm|fattori|cascin|tenuta|villa|\bcasa\b|"
    r"oasi|\barca\b|mondo|amici|scuola|school|academy|accademia|servizi|service|group|gruppo|"
    r"cooperativ|onlus|\bodv\b|\baps\b|\bsrls?\b|\bsnc\b|\bsas\b|\bspa\b|\bgmbh\b|\bltd\b|\bllc\b|"
    r"\binc\b|\bsarl\b|\bsl\b|\bsa\b|&|\+|"
    # Shop and trade words seen in pet-business names.
    r"\bdog\b|\bdogs\b|\bcat\b|\bbau\b|miao|style|boutique|barber|saddler|azienda|agricol|"
    r"residen|appartament|contadin|cuccia|reef|ocean|haus|market|outlet|bottega|emporio|"
    r"toelett|toilett|\bpets?\b|puppies|petland|petworld|'s\b|horses|agrari|oculist|"
    r"ingross|selleri|maneggi|equestr|ranch|garden|giardin|\bteam\b|beauty|\bcoon\b|country|"
    r"zamp|mister",
    re.IGNORECASE,
)

_TITLE = re.compile(
    r"^(dott\.?ssa|dr\.?ssa|dott(oressa|ore|or)?|dra|drs|dr|doctor|docteur|doktor|prof|avv"
    r"|med\.? ?vet|mvdr)\b\.?",
    re.IGNORECASE,
)
# A title inside the name ("Rossi Dr. Mario", "Cardillo Dott.ssa Paola").
_INNER_TITLE = re.compile(r"\s(dott\.?ssa|dr\.?ssa|dott|dr|dra|avv)\.?\s", re.IGNORECASE)

_CONJUNCTIONS = frozenset({"e", "ed", "and", "und", "et", "y", "o"})
_PLACE_STARTS = frozenset({"san", "santa", "santo", "sant", "saint", "st", "sankt", "villa"})
_ARTICLES = frozenset(
    {
        "il",
        "lo",
        "la",
        "i",
        "gli",
        "le",
        "l",
        "al",
        "the",
        "der",
        "die",
        "das",
        "les",
        "el",
        "los",
        "las",
    }
)
_PARTICLES = frozenset({"di", "del", "della", "dei", "da", "de", "du", "des", "von", "van"})

# Common given names (Italian first, then English, German, French, Spanish).
FIRST_NAMES = frozenset(
    """
    alessandro alessandra alberto alberta alda aldo alessia alfredo alice alma amedeo amelia
    andrea angela angelo anna annalisa annamaria antonella antonio antonia arianna armando
    arturo aurora barbara beatrice benedetta benito bianca bruno camilla carla carlo carmela
    carmine carolina caterina cecilia cesare chiara claudia claudio clara corrado cristian
    cristiana cristina cristiano daniela daniele dario davide debora denise diana diego
    domenico donatella edoardo elena eleonora elisa elisabetta emanuela emanuele emilia emilio
    enrico enza erica ernesto ettore eugenio fabio fabiola fabrizio federica federico
    filippo fiorella flavia flavio francesca francesco franco gabriele gabriella gaetano
    giacomo gianluca gianni giada gianfranco gilberto gino giorgia giorgio giovanna giovanni
    giulia giuliana giuliano giulio giuseppe giuseppina grazia graziella guido ilaria irene
    isabella ivan ivana laura lea leonardo letizia lidia lisa livia lorena lorenzo loredana
    luana luca lucia luciana luciano lucio luigi luisa manuel manuela marcella marcello
    marco margherita maria mariano marina marino mario marisa marta martina massimo matilde
    matteo mattia maurizio mauro michela michele milena mirko monica nadia nicola nicoletta
    noemi ornella orlando paola paolo pasquale patrizia patrizio pier piera piero pietro
    raffaele raffaella renata renato riccardo rita roberta roberto rocco romina rosa rosanna
    rossana rossella sabrina salvatore samuele sandra sandro sara serena sergio silvana
    silvia silvio simona simone sofia stefania stefano susanna teresa tiziana tiziano tommaso
    ugo umberto valentina valentino valeria valerio vanessa vincenzo viola virginia vittoria
    vittorio walter
    adam amy andrew ann anne benjamin charles charlotte chris christopher daniel david
    edward elizabeth emily emma george grace hannah harry helen jack james jane jennifer jessica
    john jonathan joseph julia karen kate katherine laura linda lucy margaret mark mary matthew
    michael nancy oliver patricia paul peter rachel rebecca richard robert sarah simon sophie
    stephen susan thomas tom william
    andreas anja birgit christian claudia dirk elke frank hans heike jan jens jörg juergen
    jürgen karin katrin klaus kerstin lukas markus martin michaela monika petra ralf sabine
    sebastian stefanie susanne thorsten tobias ulrich ursula uwe wolfgang
    alain anne-marie aurélie camille catherine céline christophe claire delphine éric florence
    françois frédéric isabelle jacques jean jean-pierre julien laurent marie mathieu nathalie
    nicolas olivier philippe pierre sandrine sébastien sophie stéphane sylvie thierry valérie
    alejandro ana carmen carlos dolores elena fernando javier jesús jorge josé juan lucía
    luis manuel marta miguel pablo pilar rafael raquel rosa sergio
    """.split()
)


def _fold(text: str) -> str:
    folded = unicodedata.normalize("NFKD", text.lower())
    return "".join(char for char in folded if not unicodedata.combining(char))


_FOLDED_FIRST_NAMES = frozenset(_fold(name) for name in FIRST_NAMES)


def is_person_only(name: str | None) -> bool:
    """True when [name] is just a person's name, with or without a title."""
    text = re.sub(r"\s+", " ", name or "").strip()
    if not text or _FACILITY.search(text) or any(char.isdigit() for char in text):
        return False
    titled = bool(_TITLE.match(text)) or bool(_INNER_TITLE.search(f" {text} "))
    rest = _INNER_TITLE.sub(" ", f" {_TITLE.sub('', text, count=1)} ").strip(" .,-")
    words = [word for word in re.split(r"[\s,.\-']+", rest) if word]
    if not words or len(words) > 5 or not all(word.isalpha() for word in words):
        return False
    folded = [_fold(word) for word in words]
    # Saints name places ("Veterinario San Pietro"), not people.
    if any(word in _CONJUNCTIONS for word in folded) or any(
        word in _PLACE_STARTS for word in folded
    ):
        return False
    # "La Cuccia di Ettore", "Il Contadino ...": an article opens a sign, not a name.
    if folded[0] in _ARTICLES:
        return False
    # A brand written as one word with inner capitals ("BlueReef") is not a name.
    if any(any(char.isupper() for char in word[1:]) for word in words if not word.isupper()):
        return False
    # "Pelolindo di Laura Colli", "Oceano di Mini Marco": a shop "of" a person.
    # A particle after a first name, or opening the name, is a surname
    # ("Anna della Porta", "Di Rocco Attilio").
    for index, word in enumerate(folded[1:], start=1):
        if word in _PARTICLES and folded[index - 1] not in _FOLDED_FIRST_NAMES:
            return False
    if titled:
        # "Dott. Rossi", "Rossi Dr. Mario": a title and only a name around it.
        return all(word[0].isupper() for word in words if word not in _PARTICLES)
    if len(words) > 4:
        return False
    return len(words) >= 2 and any(word in _FOLDED_FIRST_NAMES for word in folded)
