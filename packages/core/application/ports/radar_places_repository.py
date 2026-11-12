from typing import Protocol

from packages.core.domain.coverage.models import RadarCoverage
from packages.core.domain.radar_places.models import RadarPlace


class RadarPlacesRepository(Protocol):
    def get_coverage(self, coverage_key: str) -> RadarCoverage | None: ...

    def list_places(self, coverage_key: str) -> list[RadarPlace]: ...

    def replace_coverage(self, coverage: RadarCoverage, places: list[RadarPlace]) -> None:
        """Swaps every cached place of the cell for `places` and records
        the new freshness window."""
        ...
