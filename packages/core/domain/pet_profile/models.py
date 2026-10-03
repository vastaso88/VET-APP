from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord


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
    medical_record_consent: MedicalRecordConsentRecord | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)
