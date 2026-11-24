"""Maps a pet's raw `species` string to one of a small set of canonical
species families used by evidence retrieval and (soon) safety calibration.

`PetProfile.species` is a free string (spec decision, not an enum — new
species get added on the mobile side without a backend migration), and the
real app stores the Italian UI label directly ("Cane", "Piccoli mammiferi")
rather than an internal code. Without this mapping, species-specific
search terms silently never matched anything for real conversations,
because every species-aware lookup elsewhere in the backend was keyed on
English singular species names ("dog", "cat", "rabbit", "bird").
"""

import unicodedata

CANONICAL_SPECIES = (
    "dog",
    "cat",
    "small_mammal",
    "bird",
    "reptile_amphibian",
    "fish",
    "other",
)

_LABEL_TO_CANONICAL: dict[str, str] = {
    # Current mobile UI labels (apps/mobile_app/.../pet_demo_store.dart).
    "cane": "dog",
    "gatto": "cat",
    "piccoli mammiferi": "small_mammal",
    "uccello": "bird",
    "rettili e anfibi": "reptile_amphibian",
    "pesce": "fish",
    "pesci": "fish",
    "altro": "other",
    # Legacy/direct English values, still used by existing callers and
    # tests that pass a species code straight through (e.g. "dog", "cat").
    # "rabbit" is folded into "small_mammal" — the mobile taxonomy no
    # longer treats it as its own category.
    "dog": "dog",
    "cat": "cat",
    "rabbit": "small_mammal",
    "bird": "bird",
    "reptile": "reptile_amphibian",
    "fish": "fish",
    "other": "other",
    # Canonical codes must map to themselves — normalize_species is called
    # on values that may already be canonical (e.g. a caller re-normalizing
    # a value another layer already normalized), and without this an
    # already-correct "small_mammal"/"reptile_amphibian" would silently
    # fall back to "other" since neither is a mobile UI label or legacy
    # alias above.
    "small_mammal": "small_mammal",
    "reptile_amphibian": "reptile_amphibian",
}


def normalize_species(raw: str) -> str:
    """Returns the canonical species family for `raw`, or "other" for
    anything unrecognized — never raises, matching the fail-safe posture
    of every other species-keyed lookup in this codebase."""
    known = _LABEL_TO_CANONICAL.get(raw.strip().lower())
    if known is not None:
        return known
    label = _ALIASES.get(_fold(raw))
    return _LABEL_TO_CANONICAL[label.lower()] if label is not None else "other"


# The species as the app writes them (the list the owner chooses from). Collaudo F40: «cane »
# with a trailing space was stored as typed, «Pesci» was accepted while the error listed
# «Pesce». The server now matches what arrives to this list: spaces, capitals, accents,
# singular or plural, in the app's five languages.
APP_SPECIES_LABELS = (
    "Cane",
    "Gatto",
    "Piccoli mammiferi",
    "Uccello",
    "Rettili e anfibi",
    "Pesce",
    "Altro",
)

# Internal codes some callers send straight through (see above): they are left as they are.
_INTERNAL_CODES = frozenset(
    {
        "dog",
        "cat",
        "rabbit",
        "bird",
        "reptile",
        "fish",
        "other",
        "small_mammal",
        "reptile_amphibian",
    }
)

# Folded (lower case, no accents, single spaces) → the app's label. A word that is also an
# internal code in English (dog, cat, bird, fish, other) is deliberately not here.
_ALIASES: dict[str, str] = {
    **dict.fromkeys(
        ("cane", "cani", "dogs", "perro", "perros", "hund", "hunde", "chien", "chiens"), "Cane"
    ),
    **dict.fromkeys(
        ("gatto", "gatti", "cats", "gato", "gatos", "katze", "katzen", "chat", "chats"), "Gatto"
    ),
    **dict.fromkeys(
        (
            "piccoli mammiferi",
            "piccolo mammifero",
            "small mammals",
            "small mammal",
            "pequenos mamiferos",
            "pequeno mamifero",
            "kleinsauger",
            "kleinsaugetier",
            "petits mammiferes",
            "petit mammifere",
        ),
        "Piccoli mammiferi",
    ),
    **dict.fromkeys(
        (
            "uccello",
            "uccelli",
            "birds",
            "ave",
            "aves",
            "pajaro",
            "pajaros",
            "vogel",
            "oiseau",
            "oiseaux",
        ),
        "Uccello",
    ),
    **dict.fromkeys(
        (
            "rettili e anfibi",
            "rettile e anfibio",
            "rettile",
            "rettili",
            "anfibio",
            "anfibi",
            "reptiles and amphibians",
            "reptile and amphibian",
            "reptiles",
            "amphibian",
            "amphibians",
            "reptiles y anfibios",
            "reptil",
            "anfibios",
            "reptilien und amphibien",
            "reptilien",
            "amphibien",
            "reptiles et amphibiens",
            "reptile et amphibien",
        ),
        "Rettili e anfibi",
    ),
    **dict.fromkeys(
        ("pesce", "pesci", "fishes", "pez", "peces", "fisch", "fische", "poisson", "poissons"),
        "Pesce",
    ),
    **dict.fromkeys(
        ("altro", "altri", "others", "otro", "otros", "sonstiges", "andere", "autre", "autres"),
        "Altro",
    ),
}


def _fold(raw: str) -> str:
    """Lower case, accents removed, every run of spaces a single space."""
    decomposed = unicodedata.normalize("NFKD", raw)
    plain = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(plain.lower().split())


def tidy_species(raw: str) -> str:
    """The app's label for [raw] when it is one of the app's species written another way
    («cane », «PESCI», «Hunde»), else [raw] with its edges trimmed (an internal code such as
    "dog", or something unknown, is left alone: refusing it is the validation's job)."""
    folded = _fold(raw)
    if folded in _INTERNAL_CODES:
        return raw.strip()
    return _ALIASES.get(folded, raw.strip())


# Labels older app builds stored (and singular/plural forms of today's): a pet
# saved by one of them must still be accepted. They only count for validation;
# reading still folds them as before (normalize_species is unchanged).
_LEGACY_LABELS = frozenset(
    {
        "coniglio",
        "rettile",
        "rettili",
        "anfibio",
        "anfibi",
        "piccolo mammifero",
        "uccelli",
        "pesci",
    }
)


def is_known_species(raw: str) -> bool:
    """Whether [raw] is one of the species the app offers (or a legacy/English
    alias): an invented one ("Drago") is not."""
    label = raw.strip().lower()
    return label in _LABEL_TO_CANONICAL or label in _LEGACY_LABELS or _fold(raw) in _ALIASES
