from pydantic import BaseModel

from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.domain.dog_walk.models import RoutePoint, WalkSession, accumulate_distance
from packages.core.domain.geo.models import Coordinates
from packages.shared.errors.base import ValidationError


class RecordRoutePointInput(BaseModel):
    walk_id: str
    owner_id: str
    coordinates: Coordinates
    accuracy_meters: float | None = None


class RecordRoutePointOutput(BaseModel):
    walk: WalkSession


class RecordRoutePointService:
    """Appends one GPS fix to an in-progress walk and rolls the running
    distance forward by just the new leg, so this stays cheap to call on
    every tick of a live location stream instead of re-summing the route."""

    def __init__(self, repository: DogWalkRepository) -> None:
        self._repository = repository

    def execute(self, data: RecordRoutePointInput) -> RecordRoutePointOutput:
        walk = self._repository.get(data.walk_id)
        if walk is None:
            raise ValidationError("walk not found")
        if walk.owner_id != data.owner_id:
            raise ValidationError("walk does not belong to owner")
        if walk.status != "in_progress":
            raise ValidationError("cannot record a point on a walk that isn't in progress")

        point = RoutePoint(coordinates=data.coordinates, accuracy_meters=data.accuracy_meters)
        added_distance_meters = accumulate_distance(walk.route, point)
        updated = walk.model_copy(
            update={
                "route": [*walk.route, point],
                "distance_meters": walk.distance_meters + added_distance_meters,
            }
        )
        return RecordRoutePointOutput(walk=self._repository.save(updated))
