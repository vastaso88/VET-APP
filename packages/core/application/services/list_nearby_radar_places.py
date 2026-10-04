import math
from collections import Counter
from typing import Any, Literal

from pydantic import BaseModel, Field

from packages.core.application.ports.radar_catalog_repository import (
    BoundingBox,
    RadarCatalogRepository,
)
from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.services.radar_reports import RadarCommunityView
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
    RequestRadarPlacesIngestionService,
)
from packages.core.domain.coverage.models import (
    KM_PER_DEGREE_LATITUDE,
    RADAR_COVERAGE_TIERS,
    RadarCoverage,
    RadarCoverageTier,
    ingestion_radius_km,
    tier_for_radius,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.radar_places.dedup import merge_radar_places
from packages.core.domain.radar_places.models import (
    OSM_SOURCE_NAME,
    RadarDataSource,
    RadarPlace,
)
from packages.shared.errors.base import ProviderError

# The cache is shared by cell, so imports are not attributed to whoever
# happened to trigger them.
SHARED_RADAR_OWNER_ID = "shared"

# fresh: served from a valid import. refreshed: imported during this
# request. stale: the import expired and could not be renewed. partial:
# something is missing - a narrower radius than requested, or one source
# could not be read (see `search_radius_km` for how far the answer reaches).
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
    # Who is asking, to report back their own votes. Never stored.
    viewer_id: str | None = None


class NearbyRadarPlace(BaseModel):
    place: RadarPlace
    distance_km: float


class ListNearbyRadarPlacesOutput(BaseModel):
    places: list[NearbyRadarPlace]
    coverage_key: str
    coverage_status: CoverageStatus
    refreshed_at: str | None
    search_radius_km: float
    sources: list[RadarDataSource] = Field(default_factory=list)
    # Community data per place id (pending report, rating): kept apart
    # from the place so open-data records stay as their source gave them.
    extras: dict[str, dict[str, Any]] = Field(default_factory=dict)


class _OsmPlaces(BaseModel):
    places: list[RadarPlace]
    status: CoverageStatus
    search_radius_km: float
    coverage_key: str
    refreshed_at: str | None


class ListNearbyRadarPlacesService:
    """Pet services around a point, from our own database.

    Two kinds of data are combined, in memory, per request:

    - the offline catalog (scripts/radar/): OpenStreetMap and Overture
      imported in bulk for a whole country, read by bounding box;
    - the per-cell cache of live OpenStreetMap/Overpass calls, used only
      where the offline OSM import does not reach.

    A live provider call is therefore the last resort. When even that
    fails, whatever else is available for the area is served instead of
    an error; only an area with no data from any source can fail."""

    def __init__(
        self,
        repository: RadarPlacesRepository,
        ingestion_service: RequestRadarPlacesIngestionService,
        catalog: RadarCatalogRepository,
        community: RadarCommunityView | None = None,
        *,
        max_search_radius_km: float,
        freshness_ttl_hours: int,
    ) -> None:
        self._repository = repository
        self._ingestion_service = ingestion_service
        self._catalog = catalog
        self._community = community
        self._max_search_radius_km = max_search_radius_km
        self._freshness_ttl_hours = freshness_ttl_hours

    def execute(self, data: ListNearbyRadarPlacesInput) -> ListNearbyRadarPlacesOutput:
        origin = Coordinates(latitude=data.latitude, longitude=data.longitude)
        requested_radius_km = data.radius_km or RADAR_COVERAGE_TIERS[0].search_radius_km
        tier = tier_for_radius(requested_radius_km, max_search_radius_km=self._max_search_radius_km)
        search_radius_km = min(requested_radius_km, tier.search_radius_km)
        box = _bounding_box(origin, search_radius_km)
        sources = {source.source: source for source in self._catalog.list_sources()}

        # Everything imported that is not OpenStreetMap (Overture, municipal
        # datasets) shares one table.
        has_open_sources = any(name != OSM_SOURCE_NAME for name in sources)
        open_places = self._catalog.list_open_places(box) if has_open_sources else []

        osm_source = sources.get(OSM_SOURCE_NAME)
        if osm_source is not None and osm_source.covers(origin):
            osm = _OsmPlaces(
                places=self._catalog.list_osm_places(box),
                status="fresh",
                search_radius_km=search_radius_km,
                coverage_key=f"catalog:{osm_source.release}",
                refreshed_at=osm_source.imported_at.isoformat(),
            )
        else:
            try:
                osm = self._osm_from_cells(data, tier, search_radius_km)
            except ProviderError:
                if not open_places:
                    raise
                # The other source still answers: better its clinics alone
                # than an error. Marked partial so the app can say so.
                osm = _OsmPlaces(
                    places=[],
                    status="partial",
                    search_radius_km=search_radius_km,
                    coverage_key="catalog:open-only",
                    refreshed_at=None,
                )

        places = merge_radar_places(osm.places, open_places)
        if self._community is not None:
            # Places users reported as missing join the others (a report of
            # something already listed collapses into it); places confirmed
            # closed or duplicate drop out.
            places = merge_radar_places(places, self._community.user_places(box))
            places = self._community.without_excluded(places)
        nearest = _nearest(places, origin, data, search_radius_km)
        return ListNearbyRadarPlacesOutput(
            places=nearest,
            extras=(
                self._community.extras(
                    [item.place for item in nearest], box, viewer_id=data.viewer_id
                )
                if self._community is not None
                else {}
            ),
            coverage_key=osm.coverage_key,
            coverage_status=osm.status,
            refreshed_at=osm.refreshed_at,
            # The open catalog always reaches the full radius; a narrower
            # OSM answer only means dog parks and the like stop earlier.
            search_radius_km=search_radius_km if open_places else osm.search_radius_km,
            sources=[
                source
                for name, source in sources.items()
                if name != OSM_SOURCE_NAME or osm.coverage_key.startswith("catalog:")
            ],
        )

    def _osm_from_cells(
        self, data: ListNearbyRadarPlacesInput, tier: RadarCoverageTier, search_radius_km: float
    ) -> _OsmPlaces:
        """OSM places from the per-cell cache, importing the cell from the
        live provider only when nothing cached covers the request."""
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
            return self._cached(own_coverage, "fresh", search_radius_km)

        # A wider import of the same area already contains everything a
        # narrower search needs: no reason to call the provider again.
        wider_coverages = [self._cached_coverage(item, data) for item in wider]
        for coverage in wider_coverages:
            if coverage is not None and coverage.is_fresh():
                return self._cached(coverage, "fresh", search_radius_km)

        try:
            result = self._ingestion_service.execute(own_request)
        except ProviderError:
            for coverage in (own_coverage, *wider_coverages):
                if coverage is not None:
                    return self._cached(coverage, "stale", search_radius_km)
            for item in reversed(narrower):
                coverage = self._cached_coverage(item, data)
                if coverage is not None:
                    return self._cached(
                        coverage, "partial", min(search_radius_km, item.search_radius_km)
                    )
            raise
        return _OsmPlaces(
            places=result.places,
            status="refreshed",
            search_radius_km=search_radius_km,
            coverage_key=result.coverage.coverage_key,
            refreshed_at=result.coverage.refreshed_at.isoformat(),
        )

    def _cached(
        self, coverage: RadarCoverage, status: CoverageStatus, search_radius_km: float
    ) -> _OsmPlaces:
        return _OsmPlaces(
            places=self._repository.list_places(coverage.coverage_key),
            status=status,
            search_radius_km=search_radius_km,
            coverage_key=coverage.coverage_key,
            refreshed_at=coverage.refreshed_at.isoformat(),
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


def _bounding_box(origin: Coordinates, radius_km: float) -> BoundingBox:
    """Square that contains the search circle; the exact distance filter
    runs afterwards on the rows it returns."""
    latitude_delta = radius_km / KM_PER_DEGREE_LATITUDE
    longitude_delta = radius_km / (
        KM_PER_DEGREE_LATITUDE * max(0.1, math.cos(math.radians(origin.latitude)))
    )
    return BoundingBox(
        min_latitude=origin.latitude - latitude_delta,
        max_latitude=origin.latitude + latitude_delta,
        min_longitude=origin.longitude - longitude_delta,
        max_longitude=origin.longitude + longitude_delta,
    )


def _nearest(
    places: list[RadarPlace],
    origin: Coordinates,
    data: ListNearbyRadarPlacesInput,
    search_radius_km: float,
) -> list[NearbyRadarPlace]:
    wanted_types = set(data.place_types)
    in_range = sorted(
        (
            NearbyRadarPlace(place=place, distance_km=haversine_distance_km(origin, place.location))
            for place in places
            if place.status == "active" and (not wanted_types or place.place_type in wanted_types)
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
    return nearby
