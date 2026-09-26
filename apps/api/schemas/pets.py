from pydantic import BaseModel, Field

from packages.core.domain.pet_profile.models import FishStock, HabitatDetails


class CreatePetProfileRequest(BaseModel):
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
