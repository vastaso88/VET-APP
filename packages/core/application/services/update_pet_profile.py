from pydantic import BaseModel, Field

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.shared.errors.base import ValidationError


class UpdatePetProfileInput(BaseModel):
    pet_id: str
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)


class UpdatePetProfileOutput(BaseModel):
    pet_profile: PetProfile


class UpdatePetProfileService:
    def __init__(self, repository: PetProfileRepository) -> None:
        self._repository = repository

    def execute(self, data: UpdatePetProfileInput) -> UpdatePetProfileOutput:
        pet_profile = self._repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")

        # Real-world finding: `data.model_dump()` recursively serializes
        # nested models (habitat, aquarium_stock) into plain dicts/lists of
        # dicts, and `model_copy(update=...)` assigns them as-is without
        # re-validating — PetProfile.habitat silently became a dict, not a
        # HabitatDetails, breaking attribute access on the result. Reading
        # the fields directly off `data` keeps nested model instances intact.
        fields = {name: getattr(data, name) for name in type(data).model_fields if name != "pet_id"}
        updated = pet_profile.model_copy(update=fields)
        return UpdatePetProfileOutput(pet_profile=self._repository.save(updated))
