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
