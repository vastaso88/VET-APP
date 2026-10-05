from typing import NamedTuple, Protocol

from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace


class BoundingBox(NamedTuple):
    min_latitude: float
    max_latitude: float
    min_longitude: float
    max_longitude: float


class RadarCatalogRepository(Protocol):
    """Places imported offline, in bulk, by scripts/radar/ - as opposed to
    RadarPlacesRepository, the per-cell cache filled by live provider
    calls. Each source lives in its own table and is read separately:
    sources are only ever combined in memory, per request."""

    def list_sources(self) -> list[RadarDataSource]: ...

    def list_osm_places(self, box: BoundingBox) -> list[RadarPlace]: ...

    def list_open_places(self, box: BoundingBox) -> list[RadarPlace]: ...

    def get_place(self, source: str, source_id: str) -> RadarPlace | None:
        """One imported place by its source and the source's own id."""
        ...
