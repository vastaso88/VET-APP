from typing import Literal

from pydantic import BaseModel

from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
    RequestRadarPlacesIngestionService,
)
from packages.core.domain.coverage.models import RadarCoverage
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.radar_places.models import RadarPlace
from packages.shared.errors.base import ProviderError

# The cache is shared by cell, so imports are not attributed to whoever
# happened to trigger them.
SHARED_RADAR_OWNER_ID = "shared"

CoverageStatus = Literal["fresh", "refreshed", "stale"]


class ListNearbyRadarPlacesInput(BaseModel):
    latitude: float
    longitude: float
    radius_km: float | None = None
    limit: int = 50
    place_type: str | None = None


class NearbyRadarPlace(BaseModel):
    place: RadarPlace
    distance_km: float


class ListNearbyRadarPlacesOutput(BaseModel):
    places: list[NearbyRadarPlace]
    coverage: RadarCoverage
    coverage_status: CoverageStatus
    search_radius_km: float


class ListNearbyRadarPlacesService:
    """Pet services around a point, served from the per-cell cache. The
    external source is called only when the cell was never imported or its
    freshness window expired; if that refresh fails and an older import
    exists, the older data is served as `stale` rather than failing."""

    def __init__(
        self,
        repository: RadarPlacesRepository,
        ingestion_service: RequestRadarPlacesIngestionService,
        *,
        max_search_radius_km: float,
        ingestion_radius_km: float,
        freshness_ttl_hours: int,
    ) -> None:
        self._repository = repository
        self._ingestion_service = ingestion_service
        self._max_search_radius_km = max_search_radius_km
        self._ingestion_radius_km = ingestion_radius_km
        self._freshness_ttl_hours = freshness_ttl_hours

    def execute(self, data: ListNearbyRadarPlacesInput) -> ListNearbyRadarPlacesOutput:
        origin = Coordinates(latitude=data.latitude, longitude=data.longitude)
        search_radius_km = min(
            data.radius_km or self._max_search_radius_km, self._max_search_radius_km
        )

        # Ingest around the cell center, never the user's exact position:
        # that is what makes the cache shareable, and it also means the
        # external provider never sees where a specific user is.
        window = RequestRadarPlacesIngestionInput(
            owner_id=SHARED_RADAR_OWNER_ID,
            center_latitude=data.latitude,
            center_longitude=data.longitude,
            radius_km=self._ingestion_radius_km,
            freshness_ttl_hours=self._freshness_ttl_hours,
        ).coverage_window()
        cell_center = window.cell_center

        coverage = self._repository.get_coverage(window.coverage_key)
        status: CoverageStatus = "fresh"
        if coverage is not None and coverage.is_fresh():
            places = self._repository.list_places(window.coverage_key)
        else:
            try:
                result = self._ingestion_service.execute(
                    RequestRadarPlacesIngestionInput(
                        owner_id=SHARED_RADAR_OWNER_ID,
                        center_latitude=cell_center.latitude,
                        center_longitude=cell_center.longitude,
                        radius_km=self._ingestion_radius_km,
                        freshness_ttl_hours=self._freshness_ttl_hours,
                    )
                )
            except ProviderError:
                if coverage is None:
                    raise
                places = self._repository.list_places(window.coverage_key)
                status = "stale"
            else:
                coverage, places, status = result.coverage, result.places, "refreshed"

        nearby = [
            NearbyRadarPlace(place=place, distance_km=haversine_distance_km(origin, place.location))
            for place in places
            if place.status == "active"
            and (data.place_type is None or place.place_type == data.place_type)
        ]
        nearby = sorted(
            (item for item in nearby if item.distance_km <= search_radius_km),
            key=lambda item: item.distance_km,
        )
        return ListNearbyRadarPlacesOutput(
            places=nearby[: data.limit],
            coverage=coverage,
            coverage_status=status,
            search_radius_km=search_radius_km,
        )
