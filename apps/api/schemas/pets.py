from pydantic import BaseModel, Field, field_validator

from packages.core.domain.pet_profile.details import validated_microchip
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails


class CreatePetProfileRequest(BaseModel):
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

    @field_validator("microchip_number")
    @classmethod
    def _valid_microchip(cls, value: str | None) -> str | None:
        return validated_microchip(value)


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
