from pydantic import BaseModel

from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.domain.geo.models import UserLocation


class GetUserLocationInput(BaseModel):
    owner_id: str


class GetUserLocationOutput(BaseModel):
    user_location: UserLocation


class GetUserLocationService:
    def __init__(self, repository: UserLocationRepository) -> None:
        self._repository = repository

    def execute(self, data: GetUserLocationInput) -> GetUserLocationOutput:
        user_location = self._repository.get(data.owner_id) or UserLocation(owner_id=data.owner_id)
        return GetUserLocationOutput(user_location=user_location)
