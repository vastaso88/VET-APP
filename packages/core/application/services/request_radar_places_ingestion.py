from pydantic import BaseModel

from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.ports.radar_places_source import RadarPlacesSource
from packages.core.domain.common.entity import utc_now
from packages.core.domain.coverage.models import RadarCoverage, RadarCoverageWindow
from packages.core.domain.radar_places.models import RadarPlace


class RequestRadarPlacesIngestionInput(BaseModel):
    owner_id: str
    center_latitude: float
    center_longitude: float
    radius_km: float
    freshness_ttl_hours: int

    def coverage_window(self) -> RadarCoverageWindow:
        return RadarCoverageWindow(
            owner_id=self.owner_id,
            center_latitude=self.center_latitude,
            center_longitude=self.center_longitude,
            radius_km=self.radius_km,
            freshness_ttl_hours=self.freshness_ttl_hours,
        )


class RequestRadarPlacesIngestionOutput(BaseModel):
    coverage: RadarCoverage
    places: list[RadarPlace]


class RequestRadarPlacesIngestionService:
    """Imports one coverage cell from the external source and replaces the
    cached copy. Lets ProviderError propagate: the caller decides whether
    stale data is an acceptable fallback."""

    def __init__(self, repository: RadarPlacesRepository, source: RadarPlacesSource) -> None:
        self._repository = repository
        self._source = source

    def execute(self, data: RequestRadarPlacesIngestionInput) -> RequestRadarPlacesIngestionOutput:
        # One timestamp for the whole import: the repository tells this
        # import's rows from leftovers of a previous one by comparing
        # `source_fetched_at` with the coverage's `refreshed_at`.
        imported_at = utc_now()
        places = [
            place.model_copy(update={"source_fetched_at": imported_at})
            for place in self._source.fetch_places(data)
        ]
        coverage = RadarCoverage.from_window(
            data.coverage_window(),
            source_name=self._source.name,
            place_count=len(places),
            now=imported_at,
        )
        self._repository.replace_coverage(coverage, places)
        return RequestRadarPlacesIngestionOutput(coverage=coverage, places=places)
