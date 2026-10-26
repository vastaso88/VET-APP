"""The fixed emergency word lists in German and French (2026-10-26).

Since the MULTILANG merge the chat speaks it/en/es/de/fr, but the fixed
lists that decide an emergency before any model call existed for Italian,
English and Spanish only: a German or French owner was covered by the
model-based classifier alone, which depends on the Groq budget. These are
the equivalents of the Italian lists, same groups and same thresholds,
wired into SafetyGate (what is flagged) and triage_clarification (which
category, which clarifying question, which replies downgrade it).

Matching is the lists' own: a single word matches as the START of a word
("krampf" → Krampfanfall, krampft; "saigne" → saigner, saignement), a
phrase as a substring. The message is lower-cased but accents and umlauts
are kept, so both spellings are listed where owners type both ("ohnmächtig"
and "ohnmaechtig", "hémorragie" and "hemorragie"). The poisons and the
gastric/gum emergencies live in emergency_patterns.py, which normalises
the text itself.
"""

from __future__ import annotations

# --- German ------------------------------------------------------------------------

URGENT_DE: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "atemnot",
        "kann nicht atmen",
        "kann nicht mehr atmen",
        "bekommt keine luft",
        "kriegt keine luft",
        "keine luft mehr",
        "atmet nicht",
        "atmet schwer",
        "atmet sehr schwer",
        "atmet ganz schwer",
        "schwer zu atmen",
        "atmet mit offenem maul",
        "mit offenem maul",
        "mit offener schnauze",
        "ringt nach luft",
        "japst nach luft",
        "schnappt nach luft",
        "atemprobleme",
        "atembeschwerden",
        "röchelt",
        "roechelt",
        "erstickt",
    ),
    "collapse": (
        "kollaps",
        "kollabiert",
        "zusammengebrochen",
        "bricht zusammen",
        "umgekippt",
        "ohnmächtig",
        "ohnmaechtig",
        "ohnmacht",
        "bewusstlos",
        "bewußtlos",
    ),
    "seizure": (
        "krampf",
        "krämpf",
        "kraempf",
        "epilep",
        "anfall",
        "anfäll",
        "anfaell",
        "zuckt am ganzen",
    ),
    "bleeding_trauma": (
        "blutet",
        "blutung",
        "blut im erbrochenen",
        "erbricht blut",
        "blut im kot",
        "blut im stuhl",
        "blut im urin",
        "blutiger durchfall",
        "blutiges erbrechen",
        "verblutet",
        "unfall",
        "angefahren",
        "überfahren",
        "ueberfahren",
        "vom auto erwischt",
        "von einem auto",
        "schwer verletzt",
    ),
    "urinary": (
        "kann nicht pinkeln",
        "kann nicht urinieren",
        "kann nicht mehr pinkeln",
        "pinkelt nicht",
        "pinkelt nicht mehr",
        "uriniert nicht",
        "kein urin",
        "kommt kein urin",
        "harnverhalt",
        "setzt keinen urin ab",
        "kann kein wasser lassen",
        "kein wasser lassen",
    ),
}

# Small mammals (hindgut fermenters): a day without food or droppings.
GI_STASIS_DE: tuple[str, ...] = (
    "frisst nicht mehr",
    "frisst nichts mehr",
    "frisst seit gestern nicht",
    "frisst seit gestern nichts",
    "frisst seit einem tag nicht",
    "frisst seit 24 stunden nicht",
    "hat aufgehört zu fressen",
    "hat aufgehoert zu fressen",
    "kein kot",
    "keinen kot",
    "keine köttel",
    "keine kottel",
    "keine koettel",
    "kotet nicht",
    "setzt keinen kot ab",
    "macht keine köttel",
    "macht keine kottel",
    "keine bollen",
)
# Oral antibiotics that kill a rabbit's gut flora, and human painkillers.
TOXINS_SMALL_MAMMAL_DE: tuple[str, ...] = (
    "amoxicillin",
    "penicillin",
    "clindamycin",
    "lincomycin",
    "erythromycin",
    "ibuprofen",
    "paracetamol",
    "aspirin",
    "dolormin",
    "thomapyrin",
    "ben-u-ron",
    "benuron",
)
# Human painkillers, dog-only spot-ons, classic food toxins.
TOXINS_CAT_DE: tuple[str, ...] = (
    "paracetamol",
    "ibuprofen",
    "aspirin",
    "dolormin",
    "thomapyrin",
    "ben-u-ron",
    "benuron",
    "schokolade",
    "weintrauben",
    "rosinen",
    "xylit",
    "zwiebel",
    "knoblauch",
    "permethrin",
)
TOXINS_DOG_DE: tuple[str, ...] = (
    "paracetamol",
    "ibuprofen",
    "aspirin",
    "dolormin",
    "thomapyrin",
    "ben-u-ron",
    "benuron",
    "schokolade",
    "weintrauben",
    "rosinen",
    "xylit",
    "zwiebel",
    "knoblauch",
)
REPTILE_DE: tuple[str, ...] = (
    "prolaps",
    "kloakenvorfall",
    "darmvorfall",
    "legenot",
    "kann die eier nicht legen",
    "eier nicht ablegen",
)
BIRD_DE: tuple[str, ...] = (
    "kann nicht sitzen",
    "sitzt nicht mehr auf der stange",
    "liegt am käfigboden",
    "liegt am kaefigboden",
    "am käfigboden",
    "am kaefigboden",
    "von der stange gefallen",
    "permethrin",
)

SPECIES_DE: dict[str, tuple[str, ...]] = {
    "small_mammal": GI_STASIS_DE + TOXINS_SMALL_MAMMAL_DE,
    "reptile_amphibian": REPTILE_DE,
    "bird": BIRD_DE,
    "cat": TOXINS_CAT_DE,
    "dog": TOXINS_DOG_DE,
}
TOXIN_MEDICATION_DE: tuple[str, ...] = tuple(
    dict.fromkeys(TOXINS_SMALL_MAMMAL_DE + TOXINS_CAT_DE + TOXINS_DOG_DE)
)

IMMEDIATE_DE: tuple[str, ...] = (
    "bewusstlos",
    "bewußtlos",
    "wacht nicht auf",
    "wacht nicht mehr auf",
    "reagiert nicht mehr",
    "reagiert gar nicht",
    "atmet nicht mehr",
    "atmet gar nicht",
    "atmet überhaupt nicht",
    "atmet ueberhaupt nicht",
    "hat aufgehört zu atmen",
    "hat aufgehoert zu atmen",
    "blaue lippen",
    "blaue zunge",
    "blaues zahnfleisch",
    "weisses zahnfleisch",
    "weißes zahnfleisch",
    "blutet stark",
    "starke blutung",
    "überall blut",
    "ueberall blut",
)

REASSURING_DE: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "nach dem rennen",
        "nach dem laufen",
        "nach dem spielen",
        "nach dem toben",
        "bei der hitze",
        "wegen der hitze",
        "es ist heiss",
        "es ist heiß",
        "beruhigt sich",
        "hat sich beruhigt",
        "atmet wieder normal",
        "atmet normal",
        "atmet ruhig",
    ),
    "collapse": (
        "ist wieder wach",
        "wieder wach",
        "hat sich erholt",
        "nur ein paar sekunden",
        "paar sekunden",
        "läuft normal",
        "lauft normal",
        "laeuft normal",
        "läuft wieder",
        "geht es wieder gut",
    ),
    "bleeding_trauma": (
        "hat aufgehört zu bluten",
        "hat aufgehoert zu bluten",
        "blutet nicht mehr",
        "ein paar tropfen",
        "paar tropfen",
        "nur ein kratzer",
        "ein kratzer",
    ),
    "urinary": (
        "hat gerade gepinkelt",
        "hat gerade uriniert",
        "gerade gepinkelt",
        "erst ein paar stunden",
        "nur ein paar stunden",
        "paar stunden",
    ),
}

WORSENING_DE: tuple[str, ...] = (
    "wird schlimmer",
    "immer schlimmer",
    "wird nicht besser",
    "bessert sich nicht",
    "keine besserung",
    "liegt noch",
    "liegt immer noch",
    "blutet noch",
    "blutet immer noch",
    "blutet weiter",
    "reagiert nicht",
    "wacht nicht auf",
    "immer noch krämpfe",
    "immer noch kraempfe",
    "krampft noch",
    "krampft immer noch",
    "verschlechtert sich",
)

# --- French ----------------------------------------------------------------------

URGENT_FR: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "n'arrive pas à respirer",
        "n'arrive pas a respirer",
        "n'arrive plus à respirer",
        "n'arrive plus a respirer",
        "ne respire pas",
        "ne respire plus",
        "respire mal",
        "respire très mal",
        "respire tres mal",
        "respire difficilement",
        "difficulté à respirer",
        "difficulte a respirer",
        "difficultés respiratoires",
        "difficultes respiratoires",
        "a du mal à respirer",
        "a du mal a respirer",
        "respire la gueule ouverte",
        "respire la bouche ouverte",
        "gueule ouverte",
        "détresse respiratoire",
        "detresse respiratoire",
        "s'étouffe",
        "s'etouffe",
        "suffoque",
        "dyspnée",
        "dyspnee",
    ),
    "collapse": (
        "collapsus",
        "s'est effondré",
        "s'est effondre",
        "s'effondre",
        "effondr",
        "s'est évanoui",
        "s'est evanoui",
        "évanou",
        "evanou",
        "inconscient",
        "a fait un malaise",
        "tombe dans les pommes",
        "tombé dans les pommes",
    ),
    "seizure": (
        "crise d'épilepsie",
        "crise d'epilepsie",
        "crise épileptique",
        "crise epileptique",
        "épilep",
        "epilep",
        "fait une crise",
        "fait des crises",
        "tremble de tout son corps",
    ),
    "bleeding_trauma": (
        "saigne",
        "saignement",
        "hémorragie",
        "hemorragie",
        "sang dans le vomi",
        "sang dans les vomissements",
        "vomit du sang",
        "sang dans les selles",
        "selles avec du sang",
        "sang dans les urines",
        "urine du sang",
        "perd du sang",
        "perd beaucoup de sang",
        "renvers",
        "s'est fait renverser",
        "s'est fait écraser",
        "s'est fait ecraser",
        "écrasé par",
        "ecrase par",
        "traumatisme",
        "gravement blessé",
        "gravement blesse",
    ),
    "urinary": (
        "n'arrive pas à uriner",
        "n'arrive pas a uriner",
        "n'arrive plus à uriner",
        "n'arrive plus a uriner",
        "n'urine pas",
        "n'urine plus",
        "ne fait plus pipi",
        "ne fait pas pipi",
        "n'arrive pas à faire pipi",
        "n'arrive pas a faire pipi",
        "pas d'urine",
        "blocage urinaire",
        "obstruction urinaire",
        "est bouché",
        "est bouche",
        "anurie",
    ),
}

GI_STASIS_FR: tuple[str, ...] = (
    "ne mange plus",
    "ne mange pas depuis hier",
    "ne mange plus depuis hier",
    "ne mange pas depuis un jour",
    "ne mange pas depuis 24 heures",
    "a arrêté de manger",
    "a arrete de manger",
    "ne fait plus de crottes",
    "pas de crottes",
    "ne fait pas de crottes",
    "plus de crottes",
    "ne fait plus caca",
    "ne défèque plus",
    "ne defeque plus",
    "aucune crotte",
)
TOXINS_SMALL_MAMMAL_FR: tuple[str, ...] = (
    "amoxicilline",
    "pénicilline",
    "penicilline",
    "clindamycine",
    "lincomycine",
    "érythromycine",
    "erythromycine",
    "ibuprofène",
    "ibuprofene",
    "advil",
    "doliprane",
    "dafalgan",
    "efferalgan",
    "aspirine",
)
TOXINS_CAT_FR: tuple[str, ...] = (
    "paracétamol",
    "doliprane",
    "dafalgan",
    "efferalgan",
    "ibuprofène",
    "ibuprofene",
    "advil",
    "aspirine",
    "perméthrine",
    "permethrine",
    "antipuces pour chien",
    "chocolat",
    "raisin",
    "raisins secs",
    "oignon",
    "gousse d'ail",
    "de l'ail",
    "d'ail",
)
TOXINS_DOG_FR: tuple[str, ...] = (
    "paracétamol",
    "doliprane",
    "dafalgan",
    "efferalgan",
    "ibuprofène",
    "ibuprofene",
    "advil",
    "aspirine",
    "chocolat",
    "raisin",
    "raisins secs",
    "oignon",
    "gousse d'ail",
    "de l'ail",
    "d'ail",
)
REPTILE_FR: tuple[str, ...] = (
    "prolapsus",
    "rétention d'œufs",
    "retention d'oeufs",
    "rétention d'oeufs",
    "n'arrive pas à pondre",
    "n'arrive pas a pondre",
    "dystocie",
)
BIRD_FR: tuple[str, ...] = (
    "ne tient plus sur son perchoir",
    "n'arrive plus à se percher",
    "n'arrive plus a se percher",
    "au fond de la cage",
    "tombé du perchoir",
    "tombe du perchoir",
    "perméthrine",
    "permethrine",
)

SPECIES_FR: dict[str, tuple[str, ...]] = {
    "small_mammal": GI_STASIS_FR + TOXINS_SMALL_MAMMAL_FR,
    "reptile_amphibian": REPTILE_FR,
    "bird": BIRD_FR,
    "cat": TOXINS_CAT_FR,
    "dog": TOXINS_DOG_FR,
}
TOXIN_MEDICATION_FR: tuple[str, ...] = tuple(
    dict.fromkeys(TOXINS_SMALL_MAMMAL_FR + TOXINS_CAT_FR + TOXINS_DOG_FR)
)

IMMEDIATE_FR: tuple[str, ...] = (
    "inconscient",
    "ne se réveille pas",
    "ne se reveille pas",
    "ne répond plus",
    "ne repond plus",
    "ne réagit plus",
    "ne reagit plus",
    "ne respire plus",
    "ne respire pas du tout",
    "a arrêté de respirer",
    "a arrete de respirer",
    "lèvres bleues",
    "levres bleues",
    "langue bleue",
    "gencives bleues",
    "gencives blanches",
    "du sang partout",
    "hémorragie grave",
    "hemorragie grave",
    "saigne beaucoup",
    "saigne abondamment",
)

REASSURING_FR: dict[str, tuple[str, ...]] = {
    "respiratory": (
        "après la course",
        "apres la course",
        "apres avoir couru",
        "apres avoir joue",
        "ça se calme",
        "ca se calme",
        "s'est calmé",
        "s'est calme",
    ),
    "collapse": (
        "il est réveillé",
        "il est reveille",
        "elle est réveillée",
        "réveillé maintenant",
        "reveille maintenant",
        "s'est remis",
        "s'est remise",
        "quelques secondes",
        "marche normalement",
        "va bien maintenant",
    ),
    "bleeding_trauma": (
        "a arrete de saigner",
        "ne saigne plus",
        "une egratignure",
        "juste une égratignure",
    ),
    "urinary": (
        "vient de faire pipi",
        "juste deux heures",
        "deux heures seulement",
    ),
}

WORSENING_FR: tuple[str, ...] = (
    "ne s'ameliore pas",
    "toujours a terre",
    "saigne toujours",
    "ne repond pas",
    "ne se reveille pas",
    "toujours des convulsions",
    "convulse encore",
    "de pire en pire",
    "se dégrade",
    "se degrade",
)


def all_urgent_keywords() -> frozenset[str]:
    """Every universal (species-independent) keyword of both languages."""
    return frozenset(
        keyword
        for catalog in (URGENT_DE, URGENT_FR)
        for keywords in catalog.values()
        for keyword in keywords
    )
