from datetime import datetime, timedelta

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates

# Side of one cache cell, in degrees. 0.05 deg is ~5.5 km north-south and
# ~3.9 km east-west at Italian latitudes, so the farthest a user can be
# from their cell's center is ~3.4 km (see CELL_MAX_OFFSET_KM).
COVERAGE_CELL_SIZE_DEGREES = 0.05
CELL_MAX_OFFSET_KM = 3.5


def _snap(value: float) -> float:
    return round(round(value / COVERAGE_CELL_SIZE_DEGREES) * COVERAGE_CELL_SIZE_DEGREES, 2)


class RadarCoverageWindow(BaseModel):
    """The area one radar ingestion covers. The cache is shared by
    geographic cell, not per owner: `coverage_key` snaps the center to a
    fixed grid, so every user standing in the same cell reuses the same
    imported places instead of triggering their own provider call."""

    owner_id: str
    center_latitude: float
    center_longitude: float
    radius_km: float
    freshness_ttl_hours: int

    @property
    def cell_center(self) -> Coordinates:
        return Coordinates(
            latitude=_snap(self.center_latitude),
            longitude=_snap(self.center_longitude),
        )

    @property
    def coverage_key(self) -> str:
        center = self.cell_center
        return f"cell:{center.latitude:.2f}:{center.longitude:.2f}:r{self.radius_km:g}"


class RadarCoverage(BaseModel):
    """Bookkeeping row for one cell: when it was last imported and until
    when that import counts as fresh."""

    coverage_key: str
    center_latitude: float
    center_longitude: float
    radius_km: float
    source_name: str
    place_count: int = 0
    refreshed_at: datetime = Field(default_factory=utc_now)
    expires_at: datetime

    def is_fresh(self, *, now: datetime | None = None) -> bool:
        return (now or utc_now()) < self.expires_at

    @classmethod
    def from_window(
        cls,
        window: RadarCoverageWindow,
        *,
        source_name: str,
        place_count: int,
        now: datetime | None = None,
    ) -> "RadarCoverage":
        refreshed_at = now or utc_now()
        center = window.cell_center
        return cls(
            coverage_key=window.coverage_key,
            center_latitude=center.latitude,
            center_longitude=center.longitude,
            radius_km=window.radius_km,
            source_name=source_name,
            place_count=place_count,
            refreshed_at=refreshed_at,
            expires_at=refreshed_at + timedelta(hours=window.freshness_ttl_hours),
        )
