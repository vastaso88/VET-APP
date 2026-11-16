from pydantic import BaseModel
from pydantic import ValidationError as PydanticValidationError

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.pet_profile.memorial import ensure_not_in_memories
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.core.domain.pet_profile.validation import validate_pet_fields
from packages.shared.errors.base import ValidationError


class UpdatePetProfileInput(BaseModel):
    """A partial update: only the fields that are SET change (an explicit `None`
    clears an optional one); every field left out keeps its value."""

    pet_id: str
    # The caller's identity; see GetPetProfileInput.
    owner_id: str
    name: str | None = None
    species: str | None = None
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
    aquarium_stock: list[FishStock] | None = None


class UpdatePetProfileOutput(BaseModel):
    pet_profile: PetProfile


_IDENTITY = {"pet_id", "owner_id"}


class UpdatePetProfileService:
    def __init__(self, repository: PetProfileRepository) -> None:
        self._repository = repository

    def execute(self, data: UpdatePetProfileInput) -> UpdatePetProfileOutput:
        pet_profile = self._repository.get(data.pet_id)
        if pet_profile is None or pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile not found")
        ensure_not_in_memories(pet_profile)

        # Real-world finding: `data.model_dump()` recursively serializes
        # nested models (habitat, aquarium_stock) into plain dicts/lists of
        # dicts, and `model_copy(update=...)` assigns them as-is without
        # re-validating — PetProfile.habitat silently became a dict, not a
        # HabitatDetails, breaking attribute access on the result. Reading
        # the fields directly off `data` keeps nested model instances intact.
        touched = data.model_fields_set - _IDENTITY
        fields = {name: getattr(data, name) for name in touched}
        # A name or species can be changed but not blanked; a list is never null.
        if fields.get("aquarium_stock", []) is None:
            fields["aquarium_stock"] = []
        if isinstance(fields.get("name"), str):
            fields["name"] = fields["name"].strip()
        updated = pet_profile.model_copy(update=fields)
        # Only what this request touches is judged: a row saved long ago with an
        # odd value is not refused for something nobody changed.
        validate_pet_fields(updated.model_dump(), touched)
        # model_copy skips validation: run it, so the legacy sex split and the
        # microchip/body-condition checks apply to updates as well.
        try:
            updated = PetProfile.model_validate(updated.model_dump())
        except PydanticValidationError as error:
            raise ValidationError(str(error)) from error
        return UpdatePetProfileOutput(pet_profile=self._repository.save(updated))
