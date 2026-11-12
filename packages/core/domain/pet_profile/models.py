from typing import Any

from pydantic import BaseModel, Field, field_validator, model_validator

from packages.core.domain.common.entity import new_id
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.body_condition import (
    BODY_CONDITIONS,
    species_has_body_condition,
)
from packages.core.domain.pet_profile.details import ACTIVITY_LEVELS, validated_microchip
from packages.core.domain.pet_profile.sex import split_legacy_sex


class HabitatDetails(BaseModel):
    """Enclosure characteristics for a species that lives in a defined
    habitat (aquarium/terrarium/aviary) rather than roaming a home freely.

    Field-for-field match with the mobile app's local `HabitatDetails`
    model (shared directly by the "UI/UX e funzionalità base" session,
    2026-09-20) so the two stay compatible once the pets feature is wired
    to this backend; today the mobile pets feature is still local-only, so
    this is forward-looking, not yet actually populated by real traffic.
    """

    # Legacy free-text form, kept so older rows/callers still validate. The
    # mobile app actually stores the three numeric fields below (see
    # pet_demo_store.dart's _habitatToJson) — real-world finding
    # 2026-10-03: without them here, any backend save of a pet (e.g. the
    # medical-record consent toggle) rewrote `habitat` in this model's
    # shape and silently dropped the tank's length/width/height.
    dimensions: str = ""
    length_cm: int | None = None
    width_cm: int | None = None
    height_cm: int | None = None
    volume_liters: int | None = None
    temperature_label: str = ""
    substrate: str = ""
    notes: str = ""

    def is_empty(self) -> bool:
        return not (
            self.dimensions
            or self.length_cm
            or self.width_cm
            or self.height_cm
            or self.volume_liters
            or self.temperature_label
            or self.substrate
            or self.notes
        )

    def dimensions_label(self) -> str:
        """Human-readable size for the LLM prompt — the numeric fields when
        the app filled them in, else the legacy free-text value."""
        sides = [side for side in (self.length_cm, self.width_cm, self.height_cm) if side]
        if sides:
            return "x".join(str(side) for side in sides) + " cm"
        return self.dimensions


class FishStock(BaseModel):
    """One species within a multi-species aquarium profile — a non-empty
    `PetProfile.aquarium_stock` means the profile represents a whole
    aquarium rather than a single fish. Mirrors the mobile app's
    `FishStock`.
    """

    species: str
    male_count: int = 0
    female_count: int = 0


class PetProfile(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    # Written by the mobile app straight to Supabase (pet_demo_store.dart)
    # as display labels, e.g. "Feb 2022", "Femmina", "17,8 kg", "Media".
    # All optional: weight in particular is no longer mandatory in the
    # profile form (2026-10-03), so nothing may assume it is set.
    birth_date_label: str | None = None
    sex: str | None = None
    weight_label: str | None = None
    dog_size_category: str | None = None
    # Optional details (2026-10-14). `is_sterilized` is separate from `sex`;
    # body condition / activity level are codes (see details.py).
    is_sterilized: bool | None = None
    microchip_number: str | None = None
    coat_color: str | None = None
    body_condition: str | None = None
    activity_level: str | None = None
    medical_record_consent: MedicalRecordConsentRecord | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)

    @model_validator(mode="before")
    @classmethod
    def _split_legacy_sex(cls, data: Any) -> Any:
        """Rows written before 2026-10-14 hold "Femmina sterilizzata" etc. in
        `sex`: read them as sex + neutering flag."""
        if not isinstance(data, dict):
            return data
        sex, neutered = split_legacy_sex(data.get("sex"))
        if neutered is None:
            return data
        updated = dict(data)
        updated["sex"] = sex
        if updated.get("is_sterilized") is None:
            updated["is_sterilized"] = neutered
        return updated

    @field_validator("microchip_number")
    @classmethod
    def _valid_microchip(cls, value: str | None) -> str | None:
        return validated_microchip(value)

    @field_validator("body_condition")
    @classmethod
    def _known_body_condition(cls, value: str | None) -> str | None:
        if value is not None and value not in BODY_CONDITIONS:
            raise ValueError(f"body_condition must be one of {BODY_CONDITIONS}")
        return value

    @model_validator(mode="after")
    def _body_condition_only_where_it_exists(self) -> "PetProfile":
        """A species without a body condition never keeps one: an older app
        may still send it, so it is dropped (stored as null), not refused."""
        if self.body_condition is not None and not species_has_body_condition(
            self.species, self.breed
        ):
            self.body_condition = None
        return self

    @field_validator("activity_level")
    @classmethod
    def _known_activity_level(cls, value: str | None) -> str | None:
        if value is not None and value not in ACTIVITY_LEVELS:
            raise ValueError(f"activity_level must be one of {ACTIVITY_LEVELS}")
        return value
