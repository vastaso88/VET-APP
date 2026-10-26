"""Words the radar needs per country language: the name given to a place
that has none, and the kind-of-business hints used to correct a wrong
category. Plain data with plain lookups, so every country is one more
entry and none of them depends on Italian."""

import re
import unicodedata

# A place tagged with its category but no name is still a real place (22
# of 108 veterinarians and 347 of 364 dog parks within 10 km of Milan have
# no name in OpenStreetMap): a generic label in the country's language
# beats dropping it.
DEFAULT_PLACE_NAMES: dict[str, dict[str, str]] = {
    "it": {
        "veterinary": "Veterinario",
        "grooming": "Toelettatura",
        "shop": "Negozio per animali",
        "school": "Addestramento",
        "pet_sitting": "Pet sitter",
        "breeder": "Allevamento",
        "hotel": "Pensione per animali",
        "dog_park": "Area cani",
        "shelter": "Rifugio per animali",
    },
    "en": {
        "veterinary": "Veterinarian",
        "grooming": "Pet groomer",
        "shop": "Pet shop",
        "school": "Dog training",
        "pet_sitting": "Pet sitter",
        "breeder": "Breeder",
        "hotel": "Pet boarding",
        "dog_park": "Dog park",
        "shelter": "Animal shelter",
    },
    "de": {
        "veterinary": "Tierarzt",
        "grooming": "Tierfriseur",
        "shop": "Tierhandlung",
        "school": "Hundeschule",
        "pet_sitting": "Tiersitter",
        "breeder": "Züchter",
        "hotel": "Tierpension",
        "dog_park": "Hundeauslaufplatz",
        "shelter": "Tierheim",
    },
    "fr": {
        "veterinary": "Vétérinaire",
        "grooming": "Toilettage",
        "shop": "Animalerie",
        "school": "Éducation canine",
        "pet_sitting": "Garde d'animaux",
        "breeder": "Élevage",
        "hotel": "Pension pour animaux",
        "dog_park": "Parc à chiens",
        "shelter": "Refuge pour animaux",
    },
    "es": {
        "veterinary": "Veterinario",
        "grooming": "Peluquería canina",
        "shop": "Tienda de mascotas",
        "school": "Adiestramiento canino",
        "pet_sitting": "Cuidador de mascotas",
        "breeder": "Criadero",
        "hotel": "Residencia para mascotas",
        "dog_park": "Parque canino",
        "shelter": "Refugio de animales",
    },
}

FALLBACK_LANGUAGE = "en"


def default_place_name(place_type: str, language: str | None) -> str | None:
    names = DEFAULT_PLACE_NAMES.get(language or "") or DEFAULT_PLACE_NAMES[FALLBACK_LANGUAGE]
    return names.get(place_type)


def fold(text: str) -> str:
    """Lower case without accents: the form the hint patterns are written in."""
    decomposed = unicodedata.normalize("NFKD", text.lower().replace("ß", "ss"))
    return "".join(char for char in decomposed if not unicodedata.combining(char))


# Overture's primary category is sometimes wrong in a way the name makes
# obvious: a groomer or a breeder filed as a veterinarian (about 100 rows of
# the Italian extract of 2026-09-23.1). Matched on the accent-folded name.
VETERINARY_NAME_HINTS = re.compile(
    r"veterinar|vetinar|clinic|ambulator|ospedale|"  # it, es, fr (clinique)
    r"tierarzt|tierarzte|tierklinik|tieraerzt|praxis|"  # de
    r"\bvets?\b|animal hospital|animal clinic|pet hospital|animal medical|veterinary|"  # en
    r"hospital|clinique|cabinet"  # es, fr
)

# kind -> words that plainly name it. Only used to correct a "veterinary"
# category (a wrong entry there costs someone time in an emergency); the
# other way round a name is weaker evidence ("Farmacia veterinaria" is not
# a clinic).
OTHER_KIND_NAME_HINTS: dict[str, re.Pattern[str]] = {
    "grooming": re.compile(
        r"toelett|toilett|tolett|grooming|groomer|tierfriseur|hundesalon|"
        r"peluquer|estetica canina|toilettage"
    ),
    "breeder": re.compile(
        r"allevament|breeder|breeding|kennel|zuchter|zucht|elevage|criadero|criador"
    ),
    "school": re.compile(
        r"addestr|cinofil|educator|dog training|obedience|hundeschule|hundetrain|"
        r"education canine|dressage|adiestr|escuela canina"
    ),
    "shop": re.compile(
        r"pet ?shop|pet ?store|pets? supplies|negozio|mangimi|uccelleria|acquari|"
        r"tierhandlung|zoohandlung|fressnapf|animalerie|jardinerie|tienda de mascotas|"
        r"tienda de animales"
    ),
    "hotel": re.compile(
        r"pensione|boarding|kennels? hotel|tierpension|hundepension|pension pour|"
        r"residencia canina|hotel canino|guarderia canina"
    ),
    "shelter": re.compile(
        r"canile|gattile|rifugio|oasi felina|animal shelter|rescue|humane society|spca|"
        r"tierheim|refuge|protectora|perrera"
    ),
}
