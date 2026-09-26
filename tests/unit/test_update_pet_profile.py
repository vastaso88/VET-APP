import pytest

from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository
from packages.shared.errors.base import ValidationError


def test_update_pet_profile_sets_habitat_and_aquarium_stock() -> None:
    repository = InMemoryPetProfileRepository()
    repository.save(
        PetProfile(id="pet-1", owner_id="user-1", name="Acquario del salotto", species="Pesce")
    )
    service = UpdatePetProfileService(repository)

    result = service.execute(
        UpdatePetProfileInput(
            pet_id="pet-1",
            name="Acquario del salotto",
            species="Pesce",
            habitat=HabitatDetails(dimensions="60x30x36 cm", volume_liters=54),
            aquarium_stock=[FishStock(species="Guppy", male_count=2, female_count=4)],
        )
    )

    assert result.pet_profile.habitat is not None
    assert result.pet_profile.habitat.volume_liters == 54
    assert result.pet_profile.aquarium_stock[0].species == "Guppy"


def test_update_pet_profile_rejects_an_unknown_pet() -> None:
    service = UpdatePetProfileService(InMemoryPetProfileRepository())

    with pytest.raises(ValidationError):
        service.execute(UpdatePetProfileInput(pet_id="missing", name="Milo", species="dog"))
