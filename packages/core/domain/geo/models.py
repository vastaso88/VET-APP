import hashlib
import math
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from packages.core.domain.common.entity import utc_now

EARTH_RADIUS_KM = 6371.0088


class Coordinates(BaseModel):
    latitude: float
    longitude: float

    @field_validator("latitude")
    @classmethod
    def _validate_latitude(cls, value: float) -> float:
        if not -90 <= value <= 90:
            raise ValueError("latitude must be between -90 and 90")
        return value

    @field_validator("longitude")
    @classmethod
    def _validate_longitude(cls, value: float) -> float:
        if not -180 <= value <= 180:
            raise ValueError("longitude must be between -180 and 180")
        return value


def haversine_distance_km(a: Coordinates, b: Coordinates) -> float:
    """Great-circle distance between two points. The single distance
    primitive every "nearby" filter (marketplace, local activities) reuses,
    so the notion of "close" stays consistent across features."""
    lat1, lon1, lat2, lon2 = (
        math.radians(a.latitude),
        math.radians(a.longitude),
        math.radians(b.latitude),
        math.radians(b.longitude),
    )
    delta_lat = lat2 - lat1
    delta_lon = lon2 - lon1
    h = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(h))


def fuzz_coordinates(exact: Coordinates, listing_id: str) -> Coordinates:
    """Offsets a coordinate by a 300-800m shift that looks random but is
    deterministic per `listing_id`, so a listing's marker never jitters
    between reloads. Uses a random bearing + distance (polar offset)
    rather than rounding the coordinate: rounding snaps nearby listings
    from the same seller onto a shared grid, which makes triangulating the
    real address easier. The exact coordinate is never persisted -
    callers must fuzz before saving, not after."""
    digest = hashlib.sha256(listing_id.encode("utf-8")).digest()
    bearing_seed = int.from_bytes(digest[:4], "big")
    distance_seed = int.from_bytes(digest[4:8], "big")

    bearing_radians = (bearing_seed / 0xFFFFFFFF) * 2 * math.pi
    distance_meters = 300 + (distance_seed / 0xFFFFFFFF) * 500

    meters_per_degree_latitude = 111_320
    cos_latitude = math.cos(math.radians(exact.latitude))
    meters_per_degree_longitude = (
        meters_per_degree_latitude * cos_latitude if cos_latitude else meters_per_degree_latitude
    )

    delta_lat = (distance_meters * math.cos(bearing_radians)) / meters_per_degree_latitude
    delta_lon = (distance_meters * math.sin(bearing_radians)) / meters_per_degree_longitude

    return Coordinates(
        latitude=max(-90.0, min(90.0, exact.latitude + delta_lat)),
        longitude=max(-180.0, min(180.0, exact.longitude + delta_lon)),
    )


LocationSource = Literal["device_gps", "manual"]
LocationMode = Literal["current_position", "home_residence"]


class UserLocation(BaseModel):
    """One record per owner (mirrors AccountConsents' single-row-per-owner
    shape). `mode` picks which of `home`/`current` other features should
    read; the UI's exact toggle label is a presentation-layer decision, not
    modeled here (see docs/settings/01_brainstorm.md)."""

    owner_id: str
    mode: LocationMode = "current_position"
    home: Coordinates | None = None
    home_label: str | None = None
    current: Coordinates | None = None
    current_label: str | None = None
    current_source: LocationSource | None = None
    current_captured_at: datetime | None = None
    updated_at: datetime = Field(default_factory=utc_now)
