from pydantic import BaseModel

from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.local_activity.models import LocalActivity, LocalActivityKind


class ListNearbyActivitiesInput(BaseModel):
    center: Coordinates
    max_distance_km: float
    kind: LocalActivityKind | None = None


class ListNearbyActivitiesOutput(BaseModel):
    activities: list[LocalActivity]


class ListNearbyActivitiesService:
    def __init__(self, repository: LocalActivityRepository) -> None:
        self._repository = repository

    def execute(self, data: ListNearbyActivitiesInput) -> ListNearbyActivitiesOutput:
        candidates = self._repository.list_active()
        if data.kind is not None:
            candidates = [item for item in candidates if item.kind == data.kind]

        nearby = [
            item
            for item in candidates
            if haversine_distance_km(data.center, item.location) <= data.max_distance_km
        ]
        nearby.sort(key=lambda item: haversine_distance_km(data.center, item.location))
        return ListNearbyActivitiesOutput(activities=nearby)
