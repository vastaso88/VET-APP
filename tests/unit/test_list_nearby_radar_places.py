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
from packages.core.domain.radar_places.models import RadarPlace
from packages.infrastructure.persistence.in_memory_repositories import (
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
            _place(key, "node/3", "Negozio lontano", "shop", 45.5800, 9.1900),
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
    repository: InMemoryRadarPlacesRepository, source: _FakeSource
) -> ListNearbyRadarPlacesService:
    return ListNearbyRadarPlacesService(
        repository,
        RequestRadarPlacesIngestionService(repository, source),
        max_search_radius_km=10,
        ingestion_radius_km=15,
        freshness_ttl_hours=168,
    )


def test_first_request_imports_the_cell_and_sorts_by_distance() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert result.coverage_status == "refreshed"
    assert [item.place.name for item in result.places] == [
        "Veterinario vicino",
        "Toelettatura media",
    ]
    assert result.places[0].distance_km < result.places[1].distance_km <= 10


def test_ingestion_is_centered_on_the_cell_not_on_the_user() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    request = source.requests[0]
    assert (request.center_latitude, request.center_longitude) == (45.45, 9.2)
    assert request.radius_km == 15
    assert request.owner_id == "shared"


def test_second_user_in_the_same_cell_reuses_the_cache() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))
    result = service.execute(ListNearbyRadarPlacesInput(latitude=45.4610, longitude=9.1950))

    assert len(source.requests) == 1
    assert result.coverage_status == "fresh"
    assert result.places


def test_requested_radius_is_capped_and_filters_results() -> None:
    source = _FakeSource()
    service = _service(InMemoryRadarPlacesRepository(), source)

    capped = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, radius_km=50)
    )
    narrow = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, radius_km=1)
    )

    assert capped.search_radius_km == 10
    assert [item.place.name for item in narrow.places] == ["Veterinario vicino"]


def test_place_type_filter() -> None:
    service = _service(InMemoryRadarPlacesRepository(), _FakeSource())

    result = service.execute(
        ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON, place_type="grooming")
    )

    assert [item.place.place_type for item in result.places] == ["grooming"]


def test_expired_cell_serves_stale_data_when_the_provider_fails() -> None:
    repository = InMemoryRadarPlacesRepository()
    source = _FakeSource()
    service = _service(repository, source)
    first = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    expired = first.coverage.model_copy(update={"expires_at": utc_now() - timedelta(hours=1)})
    repository.replace_coverage(expired, repository.list_places(expired.coverage_key))
    source.fail = True

    result = service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))

    assert result.coverage_status == "stale"
    assert len(result.places) == 2


def test_provider_failure_without_any_cache_propagates() -> None:
    source = _FakeSource()
    source.fail = True
    service = _service(InMemoryRadarPlacesRepository(), source)

    with pytest.raises(ProviderError):
        service.execute(ListNearbyRadarPlacesInput(latitude=MILAN_LAT, longitude=MILAN_LON))
