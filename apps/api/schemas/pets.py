from pydantic import BaseModel, Field, field_validator

from packages.core.domain.pet_profile.details import validated_microchip
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails


class CreatePetProfileRequest(BaseModel):
    # Upper bounds keep a single request from storing arbitrarily large
    # rows (and from feeding unbounded text to the chat prompt).
    name: str = Field(max_length=80)
    species: str = Field(max_length=60)
    breed: str | None = Field(default=None, max_length=80)
    age_years: int | None = Field(default=None, ge=0, le=200)
    notes: str | None = Field(default=None, max_length=4000)
    birth_date_label: str | None = Field(default=None, max_length=40)
    sex: str | None = Field(default=None, max_length=40)
    weight_label: str | None = Field(default=None, max_length=40)
    dog_size_category: str | None = Field(default=None, max_length=40)
    is_sterilized: bool | None = None
    microchip_number: str | None = Field(default=None, max_length=40)
    coat_color: str | None = Field(default=None, max_length=80)
    body_condition: str | None = Field(default=None, max_length=40)
    activity_level: str | None = Field(default=None, max_length=40)
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)

    @field_validator("microchip_number")
    @classmethod
    def _valid_microchip(cls, value: str | None) -> str | None:
        return validated_microchip(value)


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
