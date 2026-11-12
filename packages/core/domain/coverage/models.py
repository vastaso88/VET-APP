import math
from datetime import datetime, timedelta

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates

KM_PER_DEGREE_LATITUDE = 111.32

# Bumped whenever the cached place shape changes in a way old rows cannot
# satisfy (v2: opening hours, species, dog parks). Old keys simply stop
# being read and age out.
COVERAGE_KEY_VERSION = "v2"


class RadarCoverageTier(BaseModel):
    """One step of the radius ladder the app can ask for. Wider searches
    use coarser cells: a 50 km search does not need 5 km precision on
    where the import is centered, and coarser cells mean far fewer distinct
    imports of a large area."""

    search_radius_km: float
    cell_size_degrees: float


RADAR_COVERAGE_TIERS: tuple[RadarCoverageTier, ...] = (
    RadarCoverageTier(search_radius_km=10, cell_size_degrees=0.05),
    RadarCoverageTier(search_radius_km=25, cell_size_degrees=0.10),
    RadarCoverageTier(search_radius_km=50, cell_size_degrees=0.20),
)


def tier_for_radius(radius_km: float, *, max_search_radius_km: float) -> RadarCoverageTier:
    """Smallest tier that fully serves `radius_km`, never above the
    configured maximum."""
    allowed = [
        tier for tier in RADAR_COVERAGE_TIERS if tier.search_radius_km <= max_search_radius_km
    ] or [RADAR_COVERAGE_TIERS[0]]
    for tier in allowed:
        if radius_km <= tier.search_radius_km:
            return tier
    return allowed[-1]


def _snap(value: float, cell_size_degrees: float) -> float:
    return round(round(value / cell_size_degrees) * cell_size_degrees, 2)


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
    cell_size_degrees: float = RADAR_COVERAGE_TIERS[0].cell_size_degrees

    @property
    def cell_center(self) -> Coordinates:
        return Coordinates(
            latitude=_snap(self.center_latitude, self.cell_size_degrees),
            longitude=_snap(self.center_longitude, self.cell_size_degrees),
        )

    @property
    def coverage_key(self) -> str:
        center = self.cell_center
        return (
            f"radar:{COVERAGE_KEY_VERSION}:{self.cell_size_degrees:g}:"
            f"{center.latitude:.2f}:{center.longitude:.2f}:r{self.radius_km:g}"
        )

    @property
    def max_offset_km(self) -> float:
        """Farthest a point of this cell can be from the cell center."""
        half_cell = self.cell_size_degrees / 2
        half_latitude_km = half_cell * KM_PER_DEGREE_LATITUDE
        half_longitude_km = (
            half_cell * KM_PER_DEGREE_LATITUDE * math.cos(math.radians(self.cell_center.latitude))
        )
        return math.hypot(half_latitude_km, half_longitude_km)


def ingestion_radius_km(tier: RadarCoverageTier, *, latitude: float, longitude: float) -> float:
    """Radius to import around the cell center so that the tier's search
    radius is fully covered from anywhere inside the cell."""
    probe = RadarCoverageWindow(
        owner_id="",
        center_latitude=latitude,
        center_longitude=longitude,
        radius_km=tier.search_radius_km,
        freshness_ttl_hours=1,
        cell_size_degrees=tier.cell_size_degrees,
    )
    return float(math.ceil(tier.search_radius_km + probe.max_offset_km))


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
