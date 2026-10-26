"""A body condition exists only for dogs, cats and rabbits (2026-10-26).

The backend drops one sent for any other animal (an older app may still send
it) instead of refusing the save, and recognises a rabbit typed in any app
language with the same word list as the app.
"""

import re
from pathlib import Path

import pytest

from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.domain.pet_profile import species_rules
from packages.core.domain.pet_profile.species_rules import PetKind, pet_kind
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository

PET_DETAILS_DART = (
    Path(__file__).resolve().parents[2]
    / "apps/mobile_app/lib/features/pets/domain/pet_details.dart"
)


@pytest.mark.parametrize(
    "breed",
    [
        "Coniglio nano",
        "Coniglietto",
        "Rabbit",
        "Dwarf rabbit",
        "Kaninchen",
        "Zwergkaninchen",
        "Lapin bélier",
        "Conejo",
        "Coneja enana",
    ],
)
def test_a_rabbit_typed_in_any_app_language_is_a_rabbit(breed: str) -> None:
    assert pet_kind("Piccoli mammiferi", breed) is PetKind.RABBIT


@pytest.mark.parametrize("breed", ["Criceto siriano", "Cavia", "Furetto", None])
def test_other_small_mammals_are_not_rabbits(breed: str | None) -> None:
    assert pet_kind("Piccoli mammiferi", breed) is PetKind.SMALL_MAMMAL


def test_the_app_names_a_rabbit_with_the_same_words() -> None:
    source = PET_DETAILS_DART.read_text(encoding="utf-8")
    stems = re.search(r"const _rabbitStems = \[([^\]]*)\];", source)
    compound = re.search(r"const _rabbitCompound = '([^']*)';", source)
    assert stems is not None and compound is not None
    assert tuple(re.findall(r"'([^']*)'", stems.group(1))) == species_rules._RABBIT_STEMS
    assert compound.group(1) == species_rules._RABBIT_COMPOUND


def test_creating_a_bird_with_a_body_condition_saves_none() -> None:
    service = CreatePetProfileService(InMemoryPetProfileRepository())

    bird = service.execute(
        CreatePetProfileInput(
            owner_id="user-1", name="Kiwi", species="Uccello", body_condition="normal"
        )
    ).pet_profile
    rabbit = service.execute(
        CreatePetProfileInput(
            owner_id="user-1",
            name="Fiocco",
            species="Piccoli mammiferi",
            breed="Zwergkaninchen",
            body_condition="thin",
        )
    ).pet_profile

    assert bird.body_condition is None
    assert rabbit.body_condition == "thin"


def test_updating_a_hamster_with_a_body_condition_saves_none() -> None:
    repository = InMemoryPetProfileRepository()
    created = (
        CreatePetProfileService(repository)
        .execute(
            CreatePetProfileInput(owner_id="user-1", name="Briciola", species="Piccoli mammiferi")
        )
        .pet_profile
    )

    updated = (
        UpdatePetProfileService(repository)
        .execute(
            UpdatePetProfileInput(
                pet_id=created.id,
                owner_id="user-1",
                name="Briciola",
                species="Piccoli mammiferi",
                breed="Criceto siriano",
                body_condition="overweight",
            )
        )
        .pet_profile
    )

    assert updated.body_condition is None
    stored = repository.get(created.id)
    assert stored is not None and stored.body_condition is None
