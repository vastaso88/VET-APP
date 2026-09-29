from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
)
from packages.core.domain.radar_places.models import RadarPlace
from packages.infrastructure.radar_places import (
    RadarPlacesEngineConfig,
    build_default_radar_places_orchestrator,
    build_default_radar_places_provider_registry,
)
from packages.infrastructure.radar_places.google_places_source import GooglePlacesRadarPlacesSource
from packages.infrastructure.radar_places.overpass_places_source import OverpassRadarPlacesSource
from packages.shared.config.settings import Settings


def test_test_radar_places_provider_registry_exposes_catalog_source() -> None:
    registry = build_default_radar_places_provider_registry()

    assert registry.list_provider_names() == ["catalog_seed"]
    assert [source.name for source in registry.list_sources()] == ["catalog_seed"]


def test_google_places_provider_registry_selects_google_source() -> None:
    settings = Settings(
        ENVIRONMENT="test",
        RADAR_PLACES_PROVIDER="google_places",
        GOOGLE_PLACES_API_KEY="google-key",
    )

    registry = build_default_radar_places_provider_registry(settings=settings)

    assert registry.list_provider_names() == ["google_places"]
    assert isinstance(registry.list_sources()[0], GooglePlacesRadarPlacesSource)


def test_overpass_provider_registry_selects_openstreetmap_source() -> None:
    settings = Settings(
        ENVIRONMENT="test",
        RADAR_PLACES_PROVIDER="openstreetmap_overpass",
        RADAR_SEARCH_RADIUS_KM=10,
        RADAR_INGESTION_RADIUS_KM=10,
        RADAR_FRESHNESS_TTL_HOURS=168,
    )

    registry = build_default_radar_places_provider_registry(settings=settings)

    assert registry.list_provider_names() == ["openstreetmap_overpass"]
    assert isinstance(registry.list_sources()[0], OverpassRadarPlacesSource)


def test_radar_places_orchestrator_uses_injected_source_factory() -> None:
    class _InjectedSource:
        name = "injected_seed"

        def fetch_places(
            self,
            request: RequestRadarPlacesIngestionInput,
        ) -> list[RadarPlace]:
            return []

    orchestrator = build_default_radar_places_orchestrator(
        source_factory=_InjectedSource,
    )

    assert orchestrator.source_names() == ["injected_seed"]


def test_radar_places_orchestrator_resolves_search_and_ingestion_radius_from_config() -> None:
    orchestrator = build_default_radar_places_orchestrator(
        config=RadarPlacesEngineConfig(
            default_search_radius_km=50,
            ingestion_radius_km=1,
            freshness_ttl_hours=12,
        )
    )

    window = orchestrator.coverage_window(
        owner_id="test-user",
        center_latitude=45.4642,
        center_longitude=9.1899,
        radius_km=80,
    )

    assert orchestrator.config.resolve_search_radius_km(80) == 50
    assert orchestrator.config.resolve_ingestion_radius_km(80) == 1
    assert window.radius_km == 1
    assert window.freshness_ttl_hours == 12
