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


FIRST_WALK_BADGE_PREFIX = "first_walk_pet_"
DISTANCE_BADGE_THRESHOLDS_KM = (10, 50, 100)
WALK_COUNT_BADGE_THRESHOLDS = (10, 30, 100)


def evaluate_badges(sessions: list[WalkSession]) -> list[str]:
    """Badge catalog (owner's design, 2026-09-19): every badge is tracked
    per pet, not pooled across the owner's pets - two dogs each build up
    their own distance/walk-count progress independently. Only
    `completed` sessions count."""
    completed = [session for session in sessions if session.status == "completed"]

    sessions_by_pet: dict[str, list[WalkSession]] = {}
    for session in completed:
        sessions_by_pet.setdefault(session.pet_id, []).append(session)

    badges: list[str] = []
    for pet_id, pet_sessions in sessions_by_pet.items():
        badges.append(f"{FIRST_WALK_BADGE_PREFIX}{pet_id}")

        total_distance_km = sum(session.distance_meters for session in pet_sessions) / 1000
        total_walks = len(pet_sessions)

        for threshold in DISTANCE_BADGE_THRESHOLDS_KM:
            if total_distance_km >= threshold:
                badges.append(f"distance_{threshold}km_pet_{pet_id}")

        for threshold in WALK_COUNT_BADGE_THRESHOLDS:
            if total_walks >= threshold:
                badges.append(f"walks_{threshold}_pet_{pet_id}")

    return badges
