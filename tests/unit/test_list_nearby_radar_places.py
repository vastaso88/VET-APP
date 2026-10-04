from datetime import timedelta

import pytest

from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesInput,
    ListNearbyRadarPlacesService,
)
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
    RequestRadarPlacesIngestionService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.coverage.models import (
    RADAR_COVERAGE_TIERS,
    ingestion_radius_km,
    tier_for_radius,
)
from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
)
from packages.shared.errors.base import ProviderError

MILAN_LAT, MILAN_LON = 45.4642, 9.1900


class _FakeSource:
    name = "fake_source"

    def __init__(self) -> None:
        self.requests: list[RequestRadarPlacesIngestionInput] = []
        self.fail = False

    def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
        self.requests.append(request_data)
        if self.fail:
            raise ProviderError("provider down")
        key = request_data.coverage_window().coverage_key
        return [
            _place(key, "node/1", "Veterinario vicino", "veterinary", 45.4650, 9.1910),
            _place(key, "node/2", "Toelettatura media", "grooming", 45.5000, 9.2300),
            _place(key, "node/3", "Negozio a 13 km", "shop", 45.5800, 9.1900),
            _place(key, "node/4", "Area cani A", "dog_park", 45.4660, 9.1900),
            _place(key, "node/5", "Area cani B", "dog_park", 45.4680, 9.1900),
            _place(key, "node/6", "Area cani C", "dog_park", 45.4700, 9.1900),
        ]


def _place(
    coverage_key: str, external_id: str, name: str, place_type: str, lat: float, lon: float
) -> RadarPlace:
    return RadarPlace.model_validate(
        {
            "coverage_key": coverage_key,
            "place_type": place_type,
            "name": name,
            "latitude": lat,
            "longitude": lon,
            "source_name": "fake_source",
            "source_external_id": external_id,
        }
    )


def _service(
    repository: InMemoryRadarPlacesRepository,
    source: _FakeSource,
    *,
    max_search_radius_km: float = 50,
    catalog: InMemoryRadarCatalogRepository | None = None,
) -> ListNearbyRadarPlacesService:
    return ListNearbyRadarPlacesService(
        repository,
        RequestRadarPlacesIngestionService(repository, source),
        catalog or InMemoryRadarCatalogRepository(),
        max_search_radius_km=max_search_radius_km,
        freshness_ttl_hours=168,
    )


def _names(service: ListNearbyRadarPlacesService, **kwargs: object) -> list[str]:
    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, **kwargs)  # type: ignore[arg-type]
    )
    return [item.place.name for item in result.places]


def test_default_radius_imports_the_cell_and_sorts_by_distance() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource())

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert result.coverage_status == "refreshed"
    assert result.search_radius_km == 10
    distances = [item.distance_km for item in result.places]
    assert distances == sorted(distances)
    assert "Negozio a 13 km" not in [item.place.name for item in result.places]


def test_ingestion_is_centered_on_the_cell_not_on_the_user() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    request = source.requests[0]
    assert (request.center_latitude, request.center_longitude) == (45.45, 9.2)
    assert request.owner_id == "shared"
    # 10 km search + ~3.4 km worst-case offset inside a 0.05 deg cell.
    assert request.radius_km == 14


def test_second_user_in_the_same_cell_reuses_the_cache() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))
    result = service.execute(ListNearbyRadarPlacesInput(latitude=45.4610, longitude=9.1950))

    assert len(source.requests) == 1
    assert result.coverage_status == "fresh"
    assert result.places


def test_wider_radius_uses_a_wider_tier_with_its_own_import() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    assert "Negozio a 13 km" not in _names(service, radius_km=10)
    assert "Negozio a 13 km" in _names(service, radius_km=25)

    narrow, wide = source.requests
    assert wide.cell_size_degrees > narrow.cell_size_degrees
    assert wide.radius_km > 25
    assert wide.coverage_window().coverage_key != narrow.coverage_window().coverage_key


def test_radius_is_capped_by_the_configured_maximum() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource(), max_search_radius_km=10)

    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, radius_km=50)
    )

    assert result.search_radius_km == 10


def test_narrow_radius_filters_inside_the_smallest_tier() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource())

    assert _names(service, radius_km=0.15) == ["Veterinario vicino"]


def test_place_type_filter_accepts_several_types() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource())

    names = _names(service, place_types=["grooming", "veterinary"])

    assert names == ["Veterinario vicino", "Toelettatura media"]


def test_per_type_limit_keeps_scarce_categories_visible() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource())

    names = _names(service, per_type_limit=1)

    # Nearest of each category, not just the three nearest dog parks.
    assert names == ["Veterinario vicino", "Area cani A", "Toelettatura media"]


def test_expired_cell_serves_stale_data_when_the_provider_fails() -> None:
    repository = InMemoryRadarPlacesRepository()
    source = _FakeSource()
    service = _service(repository, source)
    first = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    coverage = repository.get_coverage(first.coverage_key)
    assert coverage is not None
    expired = coverage.model_copy(update={"expires_at": utc_now() - timedelta(hours=1)})
    repository.replace_coverage(expired, repository.list_places(expired.coverage_key))
    source.fail = True

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert result.coverage_status == "stale"
    assert len(result.places) == len(first.places)


def test_provider_failure_without_any_cache_propagates() -> None:
    source = _FakeSource()
    source.fail = True
    service = _service(InMemoryRadarPlacesRepository(), source)

    with pytest.raises(ProviderError):
        service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))


def test_every_tier_import_covers_its_search_radius_across_italy() -> None:
    for latitude in (36.7, 41.9, 45.5, 46.9):
        for tier in RADAR_COVERAGE_TIERS:
            radius = ingestion_radius_km(tier, latitude=latitude, longitude=12.5)
            half = tier.cell_size_degrees / 2 * 111.32
            assert radius >= tier.search_radius_km + half
            assert radius <= 70

    assert tier_for_radius(5, max_search_radius_km=50).search_radius_km == 10
    assert tier_for_radius(25, max_search_radius_km=50).search_radius_km == 25
    assert tier_for_radius(200, max_search_radius_km=50).search_radius_km == 50


def test_narrower_search_is_served_from_a_wider_cached_import() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    _names(service, radius_km=25)
    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, radius_km=10)
    )

    assert len(source.requests) == 1
    assert result.coverage_status == "fresh"
    assert result.search_radius_km == 10
    assert "Negozio a 13 km" not in [item.place.name for item in result.places]


def test_failed_wider_import_serves_the_narrower_cache_as_partial() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)
    _names(service, radius_km=10)
    source.fail = True

    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, radius_km=50)
    )

    assert result.coverage_status == "partial"
    assert result.search_radius_km == 10
    assert result.places


def test_clinics_are_never_truncated_by_the_per_type_limit() -> None:
    class _ManyClinics(_FakeSource):
        def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
            key = request_data.coverage_window().coverage_key
            return [
                _place(key, f"node/{i}", f"Clinica {i}", "veterinary", 45.4642 + i * 0.0005, 9.19)
                for i in range(80)
            ] + [
                _place(key, f"way/{i}", f"Area cani {i}", "dog_park", 45.4642, 9.19 + i * 0.0005)
                for i in range(80)
            ]

    service = _service(InMemoryRadarPlacesRepository(), _ManyClinics())

    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, per_type_limit=10)
    )

    types = [item.place.place_type for item in result.places]
    assert types.count("veterinary") == 80
    assert types.count("dog_park") == 10


def _catalog_place(
    name: str, place_type: str, lat: float, lon: float, *, source: str, phone: str | None = None
) -> RadarPlace:
    return RadarPlace(
        coverage_key="catalog",
        place_type=place_type,
        name=name,
        latitude=lat,
        longitude=lon,
        source_name=source,
        source_external_id=name,
        phone=phone,
    )


def _source(name: str, *, covers_italy: bool = True) -> RadarDataSource:
    return RadarDataSource(
        source=name,
        release="2026-09",
        license="test",
        attribution="test",
        imported_at=utc_now(),
        min_latitude=35.0 if covers_italy else None,
        max_latitude=47.5 if covers_italy else None,
        min_longitude=6.0 if covers_italy else None,
        max_longitude=19.0 if covers_italy else None,
    )


def test_offline_osm_catalog_answers_without_calling_the_provider() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_source("openstreetmap_overpass")]
    catalog.osm_places = [
        _catalog_place("Area cani", "dog_park", 45.4660, 9.19, source="openstreetmap_overpass"),
        _catalog_place("Lontano", "dog_park", 46.4, 9.19, source="openstreetmap_overpass"),
    ]
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source, catalog=catalog)

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert source.requests == []
    assert result.coverage_status == "fresh"
    assert [item.place.name for item in result.places] == ["Area cani"]
    assert [item.source for item in result.sources] == ["openstreetmap_overpass"]


def test_outside_the_offline_osm_area_the_live_cache_is_still_used() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_source("openstreetmap_overpass")]
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source, catalog=catalog)

    # Paris: not inside the imported area.
    service.execute(ListNearbyRadarPlacesInput(latitude=48.8566, longitude=2.3522))

    assert len(source.requests) == 1


def test_open_places_are_merged_with_osm_and_duplicates_collapse() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_source("openstreetmap_overpass"), _source("overture", covers_italy=False)]
    catalog.osm_places = [
        _catalog_place(
            "Clinica Duomo", "veterinary", 45.4650, 9.1910, source="openstreetmap_overpass"
        ),
    ]
    catalog.open_places = [
        _catalog_place(
            "Clinica Veterinaria Duomo",
            "veterinary",
            45.4651,
            9.1910,
            source="overture",
            phone="02 0000 0001",
        ),
        _catalog_place("Toelettatura Bau", "grooming", 45.4700, 9.1950, source="overture"),
    ]
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource(), catalog=catalog)

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    by_name = {item.place.name: item.place for item in result.places}
    assert sorted(by_name) == ["Clinica Veterinaria Duomo", "Toelettatura Bau"]
    assert by_name["Clinica Veterinaria Duomo"].confirmed_by == ["openstreetmap_overpass"]
    assert sorted(item.source for item in result.sources) == ["openstreetmap_overpass", "overture"]


def test_open_places_alone_are_served_when_the_live_provider_fails() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_source("overture", covers_italy=False)]
    catalog.open_places = [
        _catalog_place("Ambulatorio Lotto", "veterinary", 45.4700, 9.1950, source="overture"),
    ]
    source = _FakeSource()
    source.fail = True
    service = _service(InMemoryRadarPlacesRepository(), source, catalog=catalog)

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert result.coverage_status == "partial"
    assert [item.place.name for item in result.places] == ["Ambulatorio Lotto"]


def test_municipal_sources_are_read_like_any_other_open_source() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [
        _source("openstreetmap_overpass"),
        _source("comune_torino", covers_italy=False),
    ]
    catalog.open_places = [
        _catalog_place("Area cani Esempio", "dog_park", 45.4660, 9.19, source="comune_torino")
    ]
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource(), catalog=catalog)

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert [item.place.source_name for item in result.places] == ["comune_torino"]
    assert sorted(item.source for item in result.sources) == [
        "comune_torino",
        "openstreetmap_overpass",
    ]
