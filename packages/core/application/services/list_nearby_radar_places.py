from collections import Counter
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
    RequestRadarPlacesIngestionService,
)
from packages.core.domain.coverage.models import (
    RADAR_COVERAGE_TIERS,
    RadarCoverage,
    RadarCoverageTier,
    ingestion_radius_km,
    tier_for_radius,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.radar_places.models import RadarPlace
from packages.shared.errors.base import ProviderError

# The cache is shared by cell, so imports are not attributed to whoever
# happened to trigger them.
SHARED_RADAR_OWNER_ID = "shared"

# fresh: served from a valid import. refreshed: imported during this
# request. stale: the import expired and could not be renewed. partial:
# the requested radius could not be imported, a narrower cached one is
# served instead (see `search_radius_km` for how far it reaches).
CoverageStatus = Literal["fresh", "refreshed", "stale", "partial"]

# Never truncated by `per_type_limit`: a clinic missing from the list is
# the one failure this page cannot afford, and even the widest radius
# holds only a few hundred of them.
UNCAPPED_PLACE_TYPES = frozenset({"veterinary"})


class ListNearbyRadarPlacesInput(BaseModel):
    latitude: float
    longitude: float
    radius_km: float | None = None
    place_types: list[str] = Field(default_factory=list)
    # Cap per category rather than overall: in a city a plain "nearest N"
    # is all dog parks and pet shops. Clinics are exempt altogether (see
    # UNCAPPED_PLACE_TYPES).
    per_type_limit: int = 60


class NearbyRadarPlace(BaseModel):
    place: RadarPlace
    distance_km: float


class ListNearbyRadarPlacesOutput(BaseModel):
    places: list[NearbyRadarPlace]
    coverage: RadarCoverage
    coverage_status: CoverageStatus
    search_radius_km: float


class ListNearbyRadarPlacesService:
    """Pet services around a point, served from the per-cell cache.

    The external source is slow and regularly unavailable, so it is the
    last resort, not the default path: any valid import that already
    covers the request is used first (the cell of the requested radius,
    then wider ones), and when an import is needed but fails, whatever is
    cached for the area - expired or narrower - is served instead of an
    error. Only an area nobody ever imported can fail."""

    def __init__(
        self,
        repository: RadarPlacesRepository,
        ingestion_service: RequestRadarPlacesIngestionService,
        *,
        max_search_radius_km: float,
        freshness_ttl_hours: int,
    ) -> None:
        self._repository = repository
        self._ingestion_service = ingestion_service
        self._max_search_radius_km = max_search_radius_km
        self._freshness_ttl_hours = freshness_ttl_hours

    def execute(self, data: ListNearbyRadarPlacesInput) -> ListNearbyRadarPlacesOutput:
        requested_radius_km = data.radius_km or RADAR_COVERAGE_TIERS[0].search_radius_km
        tier = tier_for_radius(requested_radius_km, max_search_radius_km=self._max_search_radius_km)
        search_radius_km = min(requested_radius_km, tier.search_radius_km)
        tiers = [
            item
            for item in RADAR_COVERAGE_TIERS
            if item.search_radius_km <= max(self._max_search_radius_km, tier.search_radius_km)
        ]
        wider = [item for item in tiers if item.search_radius_km > tier.search_radius_km]
        narrower = [item for item in tiers if item.search_radius_km < tier.search_radius_km]

        own_request = self._ingestion_request(tier, data)
        own_coverage = self._repository.get_coverage(own_request.coverage_window().coverage_key)
        if own_coverage is not None and own_coverage.is_fresh():
            return self._output(data, own_coverage, "fresh", search_radius_km)

        # A wider import of the same area already contains everything a
        # narrower search needs: no reason to call the provider again.
        wider_coverages = [self._cached_coverage(item, data) for item in wider]
        for coverage in wider_coverages:
            if coverage is not None and coverage.is_fresh():
                return self._output(data, coverage, "fresh", search_radius_km)

        try:
            result = self._ingestion_service.execute(own_request)
        except ProviderError:
            for coverage in (own_coverage, *wider_coverages):
                if coverage is not None:
                    return self._output(data, coverage, "stale", search_radius_km)
            for item in reversed(narrower):
                coverage = self._cached_coverage(item, data)
                if coverage is not None:
                    return self._output(
                        data, coverage, "partial", min(search_radius_km, item.search_radius_km)
                    )
            raise
        return self._output(
            data, result.coverage, "refreshed", search_radius_km, places=result.places
        )

    def _ingestion_request(
        self, tier: RadarCoverageTier, data: ListNearbyRadarPlacesInput
    ) -> RequestRadarPlacesIngestionInput:
        """Import request for the cell of `tier` that contains the user.
        Centered on the cell, never on the user's exact position: that is
        what makes the cache shareable, and it also means the external
        provider never sees where a specific user is."""
        located = RequestRadarPlacesIngestionInput(
            owner_id=SHARED_RADAR_OWNER_ID,
            center_latitude=data.latitude,
            center_longitude=data.longitude,
            radius_km=ingestion_radius_km(tier, latitude=data.latitude, longitude=data.longitude),
            freshness_ttl_hours=self._freshness_ttl_hours,
            cell_size_degrees=tier.cell_size_degrees,
        )
        cell_center = located.coverage_window().cell_center
        return located.model_copy(
            update={
                "center_latitude": cell_center.latitude,
                "center_longitude": cell_center.longitude,
            }
        )

    def _cached_coverage(
        self, tier: RadarCoverageTier, data: ListNearbyRadarPlacesInput
    ) -> RadarCoverage | None:
        window = self._ingestion_request(tier, data).coverage_window()
        return self._repository.get_coverage(window.coverage_key)

    def _output(
        self,
        data: ListNearbyRadarPlacesInput,
        coverage: RadarCoverage,
        status: CoverageStatus,
        search_radius_km: float,
        *,
        places: list[RadarPlace] | None = None,
    ) -> ListNearbyRadarPlacesOutput:
        if places is None:
            places = self._repository.list_places(coverage.coverage_key)
        origin = Coordinates(latitude=data.latitude, longitude=data.longitude)
        wanted_types = set(data.place_types)
        in_range = sorted(
            (
                NearbyRadarPlace(
                    place=place, distance_km=haversine_distance_km(origin, place.location)
                )
                for place in places
                if place.status == "active"
                and (not wanted_types or place.place_type in wanted_types)
            ),
            key=lambda item: item.distance_km,
        )
        taken: Counter[str] = Counter()
        nearby: list[NearbyRadarPlace] = []
        for item in in_range:
            if item.distance_km > search_radius_km:
                break
            if (
                item.place.place_type not in UNCAPPED_PLACE_TYPES
                and taken[item.place.place_type] >= data.per_type_limit
            ):
                continue
            taken[item.place.place_type] += 1
            nearby.append(item)

        return ListNearbyRadarPlacesOutput(
            places=nearby,
            coverage=coverage,
            coverage_status=status,
            search_radius_km=search_radius_km,
        )
