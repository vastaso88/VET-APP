from packages.core.domain.pet_profile.species import normalize_species

URGENT_RED_FLAG_KEYWORDS = {
    "convuls",
    "seizure",
    "non respira",
    "respira male",
    "dispnea",
    "emorrag",
    "sanguina",
    "trauma",
    "collasso",
    "collapse",
    "anuria",
    "non urina",
    "incidente",
    # Real-world finding: an owner reporting blood in vomit/stool/urine
    # ("vomito con sangue") is a genuine red flag that "emorrag"/"sanguina"
    # don't catch — but the bare word "sangue" is NOT safe to add on its
    # own: it also matches routine, already-reassuring mentions of normal
    # bloodwork ("analisi del sangue", "esami del sangue"), which would
    # wrongly escalate a calm statement into urgent triage. These specific
    # phrasings catch the real symptom without that false-positive.
    "sangue nel vomito",
    "vomito con sangue",
    "vomita sangue",
    "sangue nelle feci",
    "feci con sangue",
    "sangue nelle urine",
    "urina con sangue",
    "perde sangue",
}

# Real-world finding: the same owner-reported symptom can mean something
# very different depending on species physiology, so a single universal
# list either misses genuine species-specific emergencies or, applied
# indiscriminately, risks manufacturing false alarm for a normal species
# baseline. These are deliberately kept to a small number of
# well-established, low-ambiguity facts rather than a broad reinterpretation
# of every symptom per species:
# - small_mammal (rabbit, guinea pig, chinchilla and other hindgut
#   fermenters grouped under "Piccoli mammiferi"): not eating AND not
#   producing stool for as little as a day is a true emergency (GI stasis
#   can be fatal within hours) — unlike dogs/cats, where a day of reduced
#   appetite is ordinarily just something to monitor. Not precise for the
#   ferrets sharing this mobile-app category (obligate carnivores, not
#   hindgut fermenters), but treating a day of anorexia+no stool as
#   worth a vet call is a reasonable prudential default for them too.
# - reptile_amphibian: cloacal/rectal prolapse and egg-binding (dystocia)
#   are unambiguous emergencies with no benign explanation to rule out —
#   same posture as "seizure" in RED_FLAG_CATEGORIES, straight to
#   escalation. Ordinary lethargy is deliberately NOT flagged here: it can
#   be normal (brumation, shedding, an enclosure running cold), and
#   treating it as urgent would manufacture anxiety over normal
#   physiology — exactly what this app must not do.
# - bird: birds instinctively mask illness, so being unable to perch or
#   found on the cage floor is a late, serious sign, not an early one.
#   A milder, more ambiguous sign like fluffed feathers alone is
#   deliberately left out — too easily explained by a cold room.
SPECIES_SPECIFIC_RED_FLAGS: dict[str, tuple[str, ...]] = {
    "small_mammal": (
        "non mangia da un giorno",
        "non mangia da ieri",
        "non mangia da 24 ore",
        "non fa la cacca",
        "non fa cacca",
        "non defeca",
        "non produce feci",
        "non fa feci",
        "niente cacca",
        # Real-world finding: the medication-safety coverage below stopped
        # at cat/dog, so "posso dare l'aspirina al mio coniglio?" raised no
        # flag at all. Rabbits, guinea pigs, chinchillas and hamsters
        # (hindgut fermenters) have their OWN distinct, well-documented
        # medication danger that doesn't exist for cats/dogs: several
        # common oral antibiotics kill the gut bacteria they depend on to
        # digest fiber, causing fatal enterotoxemia/dysbiosis within days
        # — a real risk even at an otherwise-normal dose, not just an
        # overdose. NSAIDs carry the same general risk as for cats/dogs.
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
    ),
    "reptile_amphibian": (
        "prolasso",
        "non riesce a deporre le uova",
        "trattiene le uova",
    ),
    "bird": (
        "non riesce a stare sul trespolo",
        "trovato sul fondo della gabbia",
        "caduto dal trespolo",
        # Permethrin-based spot-ons are dangerous to birds too, not just
        # cats — same products as in the "cat" list below.
        "advantix",
        "vectra",
        "exspot",
        "permetrina",
    ),
    # Real-world finding: "ho messo una goccia di advantix al mio gatto"
    # (a dog-only permethrin spot-on, genuinely lethal to cats even in
    # small amounts) and "vorrei dare la tachipirina al mio gatto" (the
    # Italian brand name for paracetamol/acetaminophen — owners very
    # commonly say the brand, not the generic name) were both treated as
    # routine questions, with no escalation regardless of whether the
    # owner was asking beforehand or reporting it already done. No
    # benign interpretation exists for either combination — same posture
    # as "seizure": always escalate, whether the substance was already
    # given (the generic triage message's "avoid unauthorized food,
    # water or medication" advice already fits a poisoning scenario) or
    # only proposed.
    # Real-world finding (round 2): in Italy, owners overwhelmingly reach
    # for the medicine-cabinet BRAND name, not the active ingredient —
    # "tachipirina"/"advantix" were the first two found, but the same gap
    # exists for every common human NSAID/analgesic brand, which is
    # genuinely dangerous to both cats and dogs (GI ulceration, kidney/
    # liver injury) regardless of which brand it came in. Grouped by
    # substance class for maintainability as this list keeps growing —
    # add new brand names to the class they belong to, not as one-offs.
    "cat": (
        # analgesics/NSAIDs — dangerous for cats, no benign explanation.
        # "Moment" (a very common ibuprofen brand) is deliberately NOT
        # included: as a bare substring it matches "momento"/"al momento"
        # ("al momento sta bene", "non ha altri sintomi al momento") —
        # extremely common phrasing in exactly these messages — which
        # would manufacture a false poisoning alarm. No substring here
        # can safely distinguish the two without word-boundary matching,
        # which SafetyGate doesn't support today; "brufen"/"nurofen"/
        # "ibuprofene" still catch the same substance under its other
        # common names.
        "tachipirina",
        "paracetamolo",
        "acetaminofene",
        "brufen",
        "nurofen",
        "ibuprofene",
        "oki",
        "artrosilene",
        "ketoprofene",
        "aspirina",
        "acido acetilsalicilico",
        "voltaren",
        "dicloreum",
        "diclofenac",
        # permethrin-based spot-ons formulated for dogs — lethal to cats,
        # never dangerous for the dogs they're actually made for
        "advantix",
        "vectra",
        "exspot",
        "permetrina",
        # classic food toxins
        "cipolla",
        "aglio",
    ),
    "dog": (
        "cioccolat",
        "uva",
        "uvetta",
        "xilitolo",
        "cipolla",
        "aglio",
        # analgesics/NSAIDs — dogs are less acutely sensitive than cats to
        # some of these but still genuinely at risk from human OTC dosing.
        # "moment" deliberately excluded here too — see the "cat" list's
        # comment (collides with "momento"/"al momento").
        "tachipirina",
        "paracetamolo",
        "acetaminofene",
        "brufen",
        "nurofen",
        "ibuprofene",
        "oki",
        "artrosilene",
        "ketoprofene",
        "aspirina",
        "acido acetilsalicilico",
        "voltaren",
        "dicloreum",
        "diclofenac",
    ),
}


class SafetyGate:
    """Pre-interview safety check (spec v3 §8-9): must run before any interview
    turn, and be re-run whenever the situation changes, not only once at the end.
    """

    def evaluate(self, message: str, species: str = "other") -> list[str]:
        lowered = message.lower()
        family = normalize_species(species)
        matches = [keyword for keyword in URGENT_RED_FLAG_KEYWORDS if keyword in lowered]
        matches += [
            keyword
            for keyword in SPECIES_SPECIFIC_RED_FLAGS.get(family, ())
            if keyword in lowered
        ]
        return matches
