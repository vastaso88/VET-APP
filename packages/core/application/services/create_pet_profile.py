from pydantic import BaseModel, Field

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile


class CreatePetProfileInput(BaseModel):
    owner_id: str
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)


class CreatePetProfileOutput(BaseModel):
    pet_profile: PetProfile


class CreatePetProfileService:
    def __init__(self, repository: PetProfileRepository) -> None:
        self._repository = repository

    def execute(self, data: CreatePetProfileInput) -> CreatePetProfileOutput:
        pet_profile = PetProfile(**data.model_dump())
        return CreatePetProfileOutput(pet_profile=self._repository.save(pet_profile))
