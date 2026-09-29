from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from packages.core.application.ports.radar_places_source import RadarPlacesSource
from packages.infrastructure.radar_places.google_places_source import GooglePlacesRadarPlacesSource
from packages.infrastructure.radar_places.overpass_places_source import OverpassRadarPlacesSource
from packages.shared.config.settings import Settings, get_settings


@dataclass(frozen=True)
class RadarPlacesProviderSpec:
    name: str
    source: RadarPlacesSource
    source_kind: str = "catalog"
    is_enabled: bool = True
    priority: int = 100
    supported_place_types: tuple[str, ...] = field(default_factory=tuple)


class RadarPlacesProviderRegistry:
    def __init__(self, providers: tuple[RadarPlacesProviderSpec, ...]) -> None:
        self._providers = providers

    def list_provider_specs(
        self,
        *,
        source_names: list[str] | None = None,
        enabled_only: bool = True,
    ) -> list[RadarPlacesProviderSpec]:
        wanted = _normalize_source_names(source_names)
        items = [item for item in self._providers if not enabled_only or item.is_enabled]
        if wanted is not None:
            items = [item for item in items if item.name.strip().lower() in wanted]
        return sorted(
            items,
            key=lambda item: (-int(item.is_enabled), item.priority, item.name.lower()),
        )

    def list_sources(
        self,
        *,
        source_names: list[str] | None = None,
        enabled_only: bool = True,
    ) -> list[RadarPlacesSource]:
        return [
            item.source
            for item in self.list_provider_specs(
                source_names=source_names,
                enabled_only=enabled_only,
            )
        ]

    def list_provider_names(
        self,
        *,
        source_names: list[str] | None = None,
        enabled_only: bool = True,
    ) -> list[str]:
        return [
            item.name
            for item in self.list_provider_specs(
                source_names=source_names,
                enabled_only=enabled_only,
            )
        ]


def build_default_radar_places_provider_registry(
    *,
    settings: Settings | None = None,
    catalog_source_factory: Callable[[], RadarPlacesSource] | None = None,
    source_factory: Callable[[], RadarPlacesSource] | None = None,
) -> RadarPlacesProviderRegistry:
    resolved_settings = settings or get_settings()
    if source_factory is not None:
        source = source_factory()
    elif resolved_settings.radar_places_provider == "google_places":
        source = GooglePlacesRadarPlacesSource(resolved_settings)
    elif resolved_settings.radar_places_provider == "openstreetmap_overpass":
        source = OverpassRadarPlacesSource(resolved_settings)
    elif (
        resolved_settings.environment == "test"
        and resolved_settings.radar_places_provider == "catalog"
    ):
        from packages.infrastructure.radar_places.catalog_places_source import (
            CatalogRadarPlacesSource,
        )

        factory = catalog_source_factory or CatalogRadarPlacesSource
        source = factory()
    else:
        raise ValueError("Unsupported radar places provider")

    source_name = getattr(source, "name", resolved_settings.radar_places_provider)
    return RadarPlacesProviderRegistry(
        providers=(
            RadarPlacesProviderSpec(
                name=str(source_name),
                source=source,
                source_kind=resolved_settings.radar_places_provider,
                is_enabled=True,
                priority=100,
                supported_place_types=(
                    "grooming",
                    "shop",
                    "veterinary",
                    "school",
                    "pet_sitting",
                    "breeder",
                    "hotel",
                ),
            ),
        )
    )


def _normalize_source_names(source_names: list[str] | None) -> set[str] | None:
    if source_names is None:
        return None
    cleaned = {name.strip().lower() for name in source_names if name.strip()}
    return cleaned or None
