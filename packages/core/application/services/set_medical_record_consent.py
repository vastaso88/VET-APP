from pydantic import BaseModel

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import PetProfile
from packages.shared.errors.base import ValidationError


class SetMedicalRecordConsentInput(BaseModel):
    owner_id: str
    pet_id: str
    granted: bool


class SetMedicalRecordConsentOutput(BaseModel):
    pet_profile: PetProfile


class SetMedicalRecordConsentService:
    """Grants or revokes medical-record access consent for a pet (spec v3
    §18) — the settings-page entry point for the decision that chat also
    asks about inline on first use. Always stamps the current consent text
    version, so granting again after a wording change re-records under the
    text the owner actually saw this time."""

    def __init__(self, repository: PetProfileRepository) -> None:
        self._repository = repository

    def execute(self, data: SetMedicalRecordConsentInput) -> SetMedicalRecordConsentOutput:
        pet_profile = self._repository.get(data.pet_id)
        if pet_profile is None or pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile not found")

        updated = pet_profile.model_copy(
            update={
                "medical_record_consent": MedicalRecordConsentRecord(
                    granted=data.granted, version=CURRENT_VERSION
                )
            }
        )
        return SetMedicalRecordConsentOutput(pet_profile=self._repository.save(updated))
