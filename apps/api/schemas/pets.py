from pydantic import BaseModel


class CreatePetProfileRequest(BaseModel):
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None


class SetMedicalRecordConsentRequest(BaseModel):
    granted: bool
