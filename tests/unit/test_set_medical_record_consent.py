import pytest

from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentInput,
    SetMedicalRecordConsentService,
)
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository
from packages.shared.errors.base import ValidationError


def _service_with_pet(
    owner_id: str = "user-1", pet_id: str = "pet-1"
) -> SetMedicalRecordConsentService:
    repository = InMemoryPetProfileRepository()
    repository.save(PetProfile(id=pet_id, owner_id=owner_id, name="Milo", species="dog"))
    return SetMedicalRecordConsentService(repository)


def test_granting_consent_stamps_current_version_and_timestamp() -> None:
    service = _service_with_pet()

    result = service.execute(
        SetMedicalRecordConsentInput(owner_id="user-1", pet_id="pet-1", granted=True)
    )

    consent = result.pet_profile.medical_record_consent
    assert consent is not None
    assert consent.granted is True
    assert consent.version == CURRENT_VERSION
    assert consent.decided_at is not None


def test_revoking_consent_after_granting_updates_the_record() -> None:
    service = _service_with_pet()
    service.execute(SetMedicalRecordConsentInput(owner_id="user-1", pet_id="pet-1", granted=True))

    result = service.execute(
        SetMedicalRecordConsentInput(owner_id="user-1", pet_id="pet-1", granted=False)
    )

    assert result.pet_profile.medical_record_consent is not None
    assert result.pet_profile.medical_record_consent.granted is False


def test_rejects_a_pet_owned_by_someone_else() -> None:
    service = _service_with_pet(owner_id="user-1")

    with pytest.raises(ValidationError):
        service.execute(
            SetMedicalRecordConsentInput(owner_id="user-2", pet_id="pet-1", granted=True)
        )


def test_rejects_unknown_pet() -> None:
    service = SetMedicalRecordConsentService(InMemoryPetProfileRepository())

    with pytest.raises(ValidationError):
        service.execute(
            SetMedicalRecordConsentInput(owner_id="user-1", pet_id="missing", granted=True)
        )
