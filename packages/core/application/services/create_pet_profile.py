from pydantic import BaseModel, Field

from packages.core.application.ports.owner_limits import OwnerLimitsLookup
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.shared.errors.base import PlanLimitError


class CreatePetProfileInput(BaseModel):
    owner_id: str
    # The account's e-mail, only to look up the plan limits (developer
    # accounts have none); never stored on the profile.
    owner_email: str | None = None
    name: str
    species: str
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    birth_date_label: str | None = None
    sex: str | None = None
    weight_label: str | None = None
    dog_size_category: str | None = None
    is_sterilized: bool | None = None
    microchip_number: str | None = None
    coat_color: str | None = None
    body_condition: str | None = None
    activity_level: str | None = None
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)


class CreatePetProfileOutput(BaseModel):
    pet_profile: PetProfile


class CreatePetProfileService:
    def __init__(
        self, repository: PetProfileRepository, owner_limits: OwnerLimitsLookup | None = None
    ) -> None:
        self._repository = repository
        # None: this deployment has no plans, so no limit on the number of pets.
        self._owner_limits = owner_limits

    def execute(self, data: CreatePetProfileInput) -> CreatePetProfileOutput:
        self._require_room_for_another_pet(data)
        pet_profile = PetProfile(**data.model_dump(exclude={"owner_email"}))
        return CreatePetProfileOutput(pet_profile=self._repository.save(pet_profile))

    def _require_room_for_another_pet(self, data: CreatePetProfileInput) -> None:
        if self._owner_limits is None:
            return
        limits = self._owner_limits(data.owner_id, data.owner_email)
        if limits is None:
            return
        if len(self._repository.list_by_owner(data.owner_id)) >= limits.max_pets:
            raise PlanLimitError(
                "pets",
                limit=limits.max_pets,
                message=f"il tuo piano consente fino a {limits.max_pets} animali.",
            )
