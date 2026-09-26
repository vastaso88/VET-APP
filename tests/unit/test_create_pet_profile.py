from packages.core.application.services.create_pet_profile import (
    CreatePetProfileInput,
    CreatePetProfileService,
)
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository


def test_create_pet_profile() -> None:
    service = CreatePetProfileService(InMemoryPetProfileRepository())

    result = service.execute(
        CreatePetProfileInput(owner_id="user-1", name="Milo", species="dog", breed="Beagle")
    )

    assert result.pet_profile.owner_id == "user-1"
    assert result.pet_profile.name == "Milo"
    assert result.pet_profile.habitat is None
    assert result.pet_profile.aquarium_stock == []


def test_create_pet_profile_with_habitat_and_aquarium_stock() -> None:
    service = CreatePetProfileService(InMemoryPetProfileRepository())

    result = service.execute(
        CreatePetProfileInput(
            owner_id="user-1",
            name="Acquario del salotto",
            species="Pesce",
            habitat=HabitatDetails(dimensions="60x30x36 cm", volume_liters=54),
            aquarium_stock=[FishStock(species="Guppy", male_count=2, female_count=4)],
        )
    )

    assert result.pet_profile.habitat is not None
    assert result.pet_profile.habitat.volume_liters == 54
    assert result.pet_profile.aquarium_stock[0].species == "Guppy"
