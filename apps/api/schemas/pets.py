from pydantic import BaseModel, Field

from packages.core.domain.pet_profile.models import FishStock, HabitatDetails


class CreatePetProfileRequest(BaseModel):
    # Upper bounds keep a single request from storing arbitrarily large
    # rows (and from feeding unbounded text to the chat prompt).
    name: str = Field(max_length=80)
    species: str = Field(max_length=60)
    breed: str | None = Field(default=None, max_length=80)
    # Value limits (age, weight, species, levels) are judged by the service, which
    # answers in the owner's language; here only the sizes of the texts.
    age_years: int | None = None
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


class UpdatePetProfileRequest(BaseModel):
    """A partial update: send only what changes. A field left out keeps its value;
    an explicit `null` clears an optional one."""

    name: str | None = Field(default=None, max_length=80)
    species: str | None = Field(default=None, max_length=60)
    breed: str | None = Field(default=None, max_length=80)
    age_years: int | None = None
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
    aquarium_stock: list[FishStock] | None = None


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
