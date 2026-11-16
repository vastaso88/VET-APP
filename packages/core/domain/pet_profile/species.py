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
    return _LABEL_TO_CANONICAL.get(raw.strip().lower(), "other")


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
    return label in _LABEL_TO_CANONICAL or label in _LEGACY_LABELS
