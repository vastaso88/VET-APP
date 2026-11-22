"""What the admin pet directory and overview show that no column stores (QK-07d).

`pet_profiles` has three columns the admin panel used to read (`is_active`, `is_exotic`,
`species_group`): they exist in production but neither the app nor the backend ever
writes them, so they say nothing. The panel now shows values derived from what IS stored:

- group: the project's species family, `normalize_species` (dog, cat, small_mammal, bird,
  reptile_amphibian, fish, other); a pet with no species at all is "unknown";
- exotic: any family the radar calls an exotic group (`EXOTIC_GROUPS`): everything that is
  not a dog or a cat;
- active: not in Ricordi (`is_memorial` false).

The same rules live in SQL for the paged directory (`admin_species_bucket` and
`admin_pets_scope` in supabase/migrations/20261122100000_admin_directories.sql); a test
keeps the two in step."""

from collections import Counter
from collections.abc import Iterable, Mapping
from typing import Any

from packages.core.domain.pet_profile.species import normalize_species
from packages.core.domain.radar_places.competences import EXOTIC_GROUPS

UNKNOWN_GROUP = "unknown"


def species_group(species: str | None) -> str:
    label = (species or "").strip()
    return normalize_species(label) if label else UNKNOWN_GROUP


def is_exotic(species: str | None) -> bool:
    return species_group(species) in EXOTIC_GROUPS


def is_active(is_memorial: bool | None) -> bool:
    return not is_memorial


def with_directory_fields(row: Mapping[str, Any]) -> dict[str, Any]:
    """[row] (a pet_profiles row with at least `species` and `is_memorial`) plus the three
    derived fields, under the names the admin panel already reads."""
    return {
        **row,
        "species_group": species_group(row.get("species")),
        "is_exotic": is_exotic(row.get("species")),
        "is_active": is_active(row.get("is_memorial")),
    }


def pet_overview(rows: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    """The overview's `pet_details`: totals and the count per species group."""
    pets = [with_directory_fields(row) for row in rows]
    groups = Counter(pet["species_group"] for pet in pets)
    return {
        "total": len(pets),
        "active": sum(1 for pet in pets if pet["is_active"]),
        "exotic": sum(1 for pet in pets if pet["is_exotic"]),
        "memorial": sum(1 for pet in pets if pet.get("is_memorial") is True),
        "species": dict(groups.most_common()),
    }
