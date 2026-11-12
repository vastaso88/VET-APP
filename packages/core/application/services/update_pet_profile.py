from pydantic import BaseModel, Field
from pydantic import ValidationError as PydanticValidationError

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.shared.errors.base import ValidationError


class UpdatePetProfileInput(BaseModel):
    pet_id: str
    # The caller's identity; see GetPetProfileInput.
    owner_id: str
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    birth_date_label: str | None = None
    sex: str | None = None
    weight_label: str | None = None
    dog_size_category: str | None = None
    is_sterilized: bool | None = None
    microchip_number: str | None = None
    coat_color: str | None = None
    body_condition: str | None = None
    activity_level: str | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)


class UpdatePetProfileOutput(BaseModel):
    pet_profile: PetProfile


class UpdatePetProfileService:
    def __init__(self, repository: PetProfileRepository) -> None:
        self._repository = repository

    def execute(self, data: UpdatePetProfileInput) -> UpdatePetProfileOutput:
        pet_profile = self._repository.get(data.pet_id)
        if pet_profile is None or pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile not found")

        # Real-world finding: `data.model_dump()` recursively serializes
        # nested models (habitat, aquarium_stock) into plain dicts/lists of
        # dicts, and `model_copy(update=...)` assigns them as-is without
        # re-validating — PetProfile.habitat silently became a dict, not a
        # HabitatDetails, breaking attribute access on the result. Reading
        # the fields directly off `data` keeps nested model instances intact.
        fields = {
            name: getattr(data, name)
            for name in type(data).model_fields
            if name not in {"pet_id", "owner_id"}
        }
        updated = pet_profile.model_copy(update=fields)
        # model_copy skips validation: run it, so the legacy sex split and the
        # microchip/body-condition checks apply to updates as well.
        try:
            updated = PetProfile.model_validate(updated.model_dump())
        except PydanticValidationError as error:
            raise ValidationError(str(error)) from error
        return UpdatePetProfileOutput(pet_profile=self._repository.save(updated))
