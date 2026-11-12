from typing import TYPE_CHECKING, Protocol

from packages.core.domain.radar_places.models import RadarPlace

if TYPE_CHECKING:
    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionInput,
    )


class RadarPlacesSource(Protocol):
    """An external catalog of pet-related places (OpenStreetMap/Overpass
    today). Raises ProviderError when the provider cannot be reached."""

    name: str

    def fetch_places(
        self, request_data: "RequestRadarPlacesIngestionInput"
    ) -> list[RadarPlace]: ...
