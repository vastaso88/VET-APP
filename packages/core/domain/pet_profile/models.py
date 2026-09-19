from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord


class PetProfile(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    medical_record_consent: MedicalRecordConsentRecord | None = None
