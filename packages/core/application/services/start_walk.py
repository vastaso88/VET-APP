from pydantic import BaseModel

from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.dog_walk.models import WalkSession
from packages.shared.errors.base import ValidationError


class StartWalkInput(BaseModel):
    owner_id: str
    pet_id: str


class StartWalkOutput(BaseModel):
    walk: WalkSession


class StartWalkService:
    def __init__(
        self,
        repository: DogWalkRepository,
        pet_profile_repository: PetProfileRepository,
    ) -> None:
        self._repository = repository
        self._pet_profile_repository = pet_profile_repository

    def execute(self, data: StartWalkInput) -> StartWalkOutput:
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")
        if pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile does not belong to owner")
        walk = WalkSession(owner_id=data.owner_id, pet_id=data.pet_id)
        return StartWalkOutput(walk=self._repository.save(walk))
