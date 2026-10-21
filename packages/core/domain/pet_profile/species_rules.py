"""Which profile details make sense for which animal (2026-10-21).

Mirror of `petKindOf` and the `speciesHas*` rules in
`apps/mobile_app/lib/features/pets/domain/pet_details.dart`: the app already
hides the questions that make no sense for an animal (no body condition for a
bird, no neutering for a fish...), and the chat must not talk about values
that an older version of the app may still have stored for it.

The stored category (`species`: "Cane", "Uccello"...) tells most; "Piccoli
mammiferi", "Rettili e anfibi" and "Altro" mix animals that need different
questions, so the chosen species (`breed`: "Coniglio nano", "Axolotl",
"Cavallo") tells them apart. A free-text species we cannot place is UNKNOWN.
"""

from __future__ import annotations

import unicodedata
from enum import StrEnum

from packages.core.domain.pet_profile.species import normalize_species


class PetKind(StrEnum):
    DOG = "dog"
    CAT = "cat"
    RABBIT = "rabbit"
    SMALL_MAMMAL = "small_mammal"
    LARGE_MAMMAL = "large_mammal"
    BIRD = "bird"
    REPTILE = "reptile"
    AMPHIBIAN = "amphibian"
    FISH = "fish"
    INVERTEBRATE = "invertebrate"
    UNKNOWN = "unknown"

    @property
    def is_mammal(self) -> bool:
        return self in _MAMMALS


_MAMMALS = frozenset(
    {PetKind.DOG, PetKind.CAT, PetKind.RABBIT, PetKind.SMALL_MAMMAL, PetKind.LARGE_MAMMAL}
)

_AMPHIBIANS = ("axolotl", "rana", "salamandra", "tritone", "altro anfibio")
_POULTRY = ("anatra", "gallina", "oca")
_LARGE_MAMMALS = ("alpaca", "asino", "capra", "cavallo", "lama", "maiale", "pecora", "pony")
_INVERTEBRATES = ("granchio", "insetto", "lumaca", "mantide", "scorpione", "tarantola")


def _fold(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).strip()


def _starts_with_any(name: str, prefixes: tuple[str, ...]) -> bool:
    return any(name == prefix or name.startswith(prefix + " ") for prefix in prefixes)


def pet_kind(species: str | None, breed: str | None = None) -> PetKind:
    category = normalize_species(species or "")
    name = _fold(breed or "")
    if category == "dog":
        return PetKind.DOG
    if category == "cat":
        return PetKind.CAT
    if category == "fish":
        return PetKind.FISH
    if category == "bird":
        return PetKind.BIRD
    if category == "small_mammal":
        return PetKind.RABBIT if name.startswith(("coniglio", "rabbit")) else PetKind.SMALL_MAMMAL
    if category == "reptile_amphibian":
        return PetKind.AMPHIBIAN if _starts_with_any(name, _AMPHIBIANS) else PetKind.REPTILE
    if _starts_with_any(name, _POULTRY):
        return PetKind.BIRD
    if _starts_with_any(name, _LARGE_MAMMALS):
        return PetKind.LARGE_MAMMAL
    if _starts_with_any(name, _INVERTEBRATES):
        return PetKind.INVERTEBRATE
    return PetKind.UNKNOWN


def uses_breed_word(species: str | None) -> bool:
    """Dogs and cats have breeds; every other animal has a species."""
    return normalize_species(species or "") in ("dog", "cat")


def has_weight(species: str | None, breed: str | None = None) -> bool:
    return pet_kind(species, breed) is not PetKind.FISH


def has_sex(species: str | None, breed: str | None = None) -> bool:
    return pet_kind(species, breed) is not PetKind.FISH


def has_neutering(species: str | None, breed: str | None = None) -> bool:
    return pet_kind(species, breed).is_mammal


def has_body_condition(species: str | None, breed: str | None = None) -> bool:
    return pet_kind(species, breed) in (PetKind.DOG, PetKind.CAT, PetKind.RABBIT)


def has_activity(species: str | None, breed: str | None = None) -> bool:
    return pet_kind(species, breed) in (PetKind.DOG, PetKind.CAT)
