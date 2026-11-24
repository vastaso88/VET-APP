from typing import Any

from pydantic import BaseModel, Field, model_validator
from pydantic_core import PydanticCustomError

from packages.core.domain.pet_profile.models import FishStock, HabitatDetails

# The enclosure and the stock are stored as they come and the habitat notes reach the chat
# prompt: bounded here, in the request only (the domain models also read old rows as written).
# Numbers: the largest tank is far below these, and they are far below any integer column.
MAX_ENCLOSURE_CM = 100_000
MAX_ENCLOSURE_LITERS = 10_000_000
MAX_FISH_PER_SEX = 100_000
MAX_STOCK_SPECIES = 100


class HabitatRequest(HabitatDetails):
    dimensions: str = Field(default="", max_length=80)
    length_cm: int | None = Field(default=None, ge=0, le=MAX_ENCLOSURE_CM)
    width_cm: int | None = Field(default=None, ge=0, le=MAX_ENCLOSURE_CM)
    height_cm: int | None = Field(default=None, ge=0, le=MAX_ENCLOSURE_CM)
    volume_liters: int | None = Field(default=None, ge=0, le=MAX_ENCLOSURE_LITERS)
    temperature_label: str = Field(default="", max_length=80)
    substrate: str = Field(default="", max_length=80)
    notes: str = Field(default="", max_length=1000)


class FishStockRequest(FishStock):
    species: str = Field(max_length=80)
    male_count: int = Field(default=0, ge=0, le=MAX_FISH_PER_SEX)
    female_count: int = Field(default=0, ge=0, le=MAX_FISH_PER_SEX)


def _refuse_ricordi_fields(data: Any) -> Any:
    """Moving a pet to Ricordi (or touching the date of the loss) is written by the app
    straight to the database, never through this route: a body that carries those fields
    used to answer 200 and change nothing (collaudo F41), which looks like a save. Now it
    is a 422 (`memorial_not_via_api`), so nobody believes the pet was moved."""
    if isinstance(data, dict):
        for key in data:
            if key == "is_memorial" or str(key).startswith("memorial_"):
                raise PydanticCustomError(
                    "memorial_not_via_api", "Ricordi is changed in the app, not through this route"
                )
    return data


class CreatePetProfileRequest(BaseModel):
    @model_validator(mode="before")
    @classmethod
    def _no_ricordi_fields(cls, data: Any) -> Any:
        return _refuse_ricordi_fields(data)

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
    habitat: HabitatRequest | None = None
    aquarium_stock: list[FishStockRequest] = Field(
        default_factory=list, max_length=MAX_STOCK_SPECIES
    )


class UpdatePetProfileRequest(BaseModel):
    """A partial update: send only what changes. A field left out keeps its value;
    an explicit `null` clears an optional one."""

    @model_validator(mode="before")
    @classmethod
    def _no_ricordi_fields(cls, data: Any) -> Any:
        return _refuse_ricordi_fields(data)

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
    habitat: HabitatRequest | None = None
    aquarium_stock: list[FishStockRequest] | None = Field(
        default=None, max_length=MAX_STOCK_SPECIES
    )


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
