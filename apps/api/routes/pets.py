from fastapi import APIRouter, Depends

from apps.api.dependencies.container import get_container
from apps.api.dependencies.subscription import allowlist_email, require_active_subscription
from apps.api.schemas.pets import (
    CreatePetProfileRequest,
    SetMedicalRecordConsentRequest,
    UpdatePetProfileRequest,
)
from packages.core.application.services.create_pet_profile import CreatePetProfileInput
from packages.core.application.services.get_pet_profile import GetPetProfileInput
from packages.core.application.services.list_pet_profiles import ListPetProfilesInput
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentInput,
)
from packages.core.application.services.update_pet_profile import UpdatePetProfileInput
from packages.core.domain.medical_record.consent_text import (
    CURRENT_VERSION,
    effective_decision,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.shared.errors.base import ValidationError

router = APIRouter(prefix="/pets", tags=["pets"])


def _with_memorial_flag(dumped: dict[str, object], pet: PetProfile) -> dict[str, object]:
    """The pet as the API hands it, plus `is_memorial` (read-only): a pet in Ricordi says so
    (collaudo F41). The model never writes the field (`exclude`), so it is added here to the
    answer only; a save can't bring a pet back through it."""
    return {**dumped, "is_memorial": pet.is_memorial}


@router.get("")
def list_pets() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_pet_profiles_service().execute(ListPetProfilesInput(owner_id=user.id))
    dumped = result.model_dump()
    pets = dumped["pet_profiles"]
    return {
        **dumped,
        "pet_profiles": [
            _with_memorial_flag(shown, pet)
            for shown, pet in zip(pets, result.pet_profiles, strict=True)
        ],
    }


@router.get("/{pet_id}")
def get_pet(pet_id: str) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.get_pet_profile_service().execute(
        GetPetProfileInput(pet_id=pet_id, owner_id=user.id)
    )
    return {
        **result.model_dump(),
        "pet_profile": _with_memorial_flag(result.model_dump()["pet_profile"], result.pet_profile),
    }


@router.post("", dependencies=[Depends(require_active_subscription)])
def create_pet(request: CreatePetProfileRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.create_pet_profile_service().execute(
        CreatePetProfileInput(
            owner_id=user.id, owner_email=allowlist_email(user), **request.model_dump()
        )
    )
    return result.model_dump()


@router.put("/{pet_id}", dependencies=[Depends(require_active_subscription)])
def update_pet(pet_id: str, request: UpdatePetProfileRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.update_pet_profile_service().execute(
        # Only what the request sets: a field left out is not touched.
        UpdatePetProfileInput(
            pet_id=pet_id, owner_id=user.id, **request.model_dump(exclude_unset=True)
        )
    )
    return result.model_dump()


@router.get("/{pet_id}/medical-record-consent")
def get_medical_record_consent(pet_id: str) -> dict[str, object]:
    """The owner's decision as it counts today: `granted` is None when
    there is none yet or when it was taken under an earlier consent text,
    so the app shows the current wording and asks again."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    pet_profile = container.pet_profile_repository.get(pet_id)
    if pet_profile is None or pet_profile.owner_id != user.id:
        raise ValidationError("pet_profile not found")
    record = pet_profile.medical_record_consent
    return {
        "granted": effective_decision(record),
        "needs_decision": effective_decision(record) is None,
        "recorded_version": record.version if record else None,
        "current_version": CURRENT_VERSION,
        "decided_at": record.decided_at.isoformat() if record else None,
    }


@router.put("/{pet_id}/medical-record-consent")
def set_medical_record_consent(
    pet_id: str, request: SetMedicalRecordConsentRequest
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.set_medical_record_consent_service().execute(
        SetMedicalRecordConsentInput(owner_id=user.id, pet_id=pet_id, granted=request.granted)
    )
    return result.model_dump()
