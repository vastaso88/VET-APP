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

    dimensions: str = ""
    volume_liters: int | None = None
    temperature_label: str = ""
    substrate: str = ""
    notes: str = ""

    def is_empty(self) -> bool:
        return not (
            self.dimensions
            or self.volume_liters
            or self.temperature_label
            or self.substrate
            or self.notes
        )


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
    medical_record_consent: MedicalRecordConsentRecord | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)
