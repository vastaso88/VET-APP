from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.geo.models import Coordinates, haversine_distance_km

WalkStatus = Literal["in_progress", "completed", "discarded"]


class RoutePoint(BaseModel):
    coordinates: Coordinates
    recorded_at: datetime = Field(default_factory=utc_now)
    accuracy_meters: float | None = None


class WalkSession(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    pet_id: str
    status: WalkStatus = "in_progress"
    started_at: datetime = Field(default_factory=utc_now)
    ended_at: datetime | None = None
    distance_meters: float = 0.0
    duration_seconds: int | None = None
    step_count_estimate: int | None = None
    route: list[RoutePoint] = Field(default_factory=list)


def estimate_steps(distance_meters: float, stride_meters: float = 0.75) -> int:
    """A rough estimate derived from the GPS distance, not a hardware step
    count - the app is web-first and the `pedometer` package has no web
    support, so this is the MVP stand-in (see docs/maps/)."""
    if distance_meters <= 0:
        return 0
    return round(distance_meters / stride_meters)


def accumulate_distance(route: list[RoutePoint], new_point: RoutePoint) -> float:
    """Distance of `route + [new_point]`, given the distance already
    covered by `route` alone. Used by RecordRoutePointService so it can
    add one leg to the running total instead of re-summing the whole
    route on every GPS tick."""
    if not route:
        return 0.0
    return haversine_distance_km(route[-1].coordinates, new_point.coordinates) * 1000


# TODO(human): implement evaluate_badges.
def evaluate_badges(sessions: list[WalkSession]) -> list[str]:
    pass
