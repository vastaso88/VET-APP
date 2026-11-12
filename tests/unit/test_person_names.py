"""People are never on the map: only facilities (owner's decision, 2026-11-08).
Every name here is invented."""

from datetime import UTC, datetime

import pytest

from packages.core.domain.radar_places.person_names import is_person_only
from packages.core.domain.radar_reports.models import clean_place_name
from packages.infrastructure.radar_places.overpass_places_source import map_osm_element
from packages.infrastructure.radar_places.overture_mapping import overture_row_to_place
from packages.shared.errors.base import ValidationError


@pytest.mark.parametrize(
    "name",
    [
        "Dott. Mario Esempi",
        "Dott.ssa Anna Esempio",
        "Dr. Esempio",
        "Esempio Dr. Mario",
        "Esempio Dott.ssa Paola",
        "Esempio Anna",
        "Mario Esempi",
        "Anna Maria Esempio",
        "Mario Esempi Veterinario",
        "Alessandra della Esempio",
        "Di Esempio Dr. Attilio",
        "Dr. G. Esempi",
    ],
)
def test_a_person_is_recognised(name: str) -> None:
    assert is_person_only(name)


@pytest.mark.parametrize(
    "name",
    [
        "Ambulatorio Veterinario Dott. Esempi",
        "Clinica Veterinaria Esempio",
        "Studio Veterinario Esempio",
        "Esempi Mario Srl",
        "Toelettatura Claudia",
        "Santa Lucia",
        "Veterinario San Pietro",
        "La Cuccia di Ettore",
        "Pelolindo di Laura Esempi",
        "Mario e Luca",
        "Villa Lisetta",
        "Andrea's Pets",
        "BlueReef Paola",
        "Albero Verde",
        "Esempio",
        "Area cani",
    ],
)
def test_a_facility_is_not_a_person(name: str) -> None:
    assert not is_person_only(name)


NOW = datetime(2026, 11, 8, tzinfo=UTC)


def _osm(name: str) -> object:
    return map_osm_element(
        {
            "type": "node",
            "id": 1,
            "lat": 45.46,
            "lon": 9.19,
            "tags": {"amenity": "veterinary", "name": name},
        },
        owner_id="",
        coverage_key="catalog",
        fetched_at=NOW,
    )


def test_openstreetmap_import_and_live_cache_drop_people() -> None:
    assert _osm("Dott. Mario Esempi") is None
    assert _osm("Ambulatorio Veterinario Esempio") is not None


def _overture(name: str) -> object:
    return overture_row_to_place(
        {
            "id": "ov-1",
            "name": name,
            "category": "veterinarian",
            "confidence": 0.9,
            "latitude": 45.46,
            "longitude": 9.19,
        },
        release="test",
    )


def test_overture_import_drops_people() -> None:
    assert _overture("Esempio Dr. Mario") is None
    assert _overture("Clinica Veterinaria Esempio") is not None


def test_a_user_report_cannot_name_a_person() -> None:
    with pytest.raises(ValidationError, match="non quello di una persona"):
        clean_place_name("Dott.ssa Anna Esempio", place_type="veterinary")
    assert clean_place_name("Studio Veterinario Esempio", place_type="veterinary")


def test_rows_already_stored_are_never_served() -> None:
    from packages.core.application.services.list_nearby_radar_places import (
        ListNearbyRadarPlacesInput,
        ListNearbyRadarPlacesService,
    )
    from packages.core.application.services.request_radar_places_ingestion import (
        RequestRadarPlacesIngestionService,
    )
    from packages.core.domain.radar_places.models import RadarDataSource, RadarPlace
    from packages.infrastructure.persistence.in_memory_repositories import (
        InMemoryRadarCatalogRepository,
        InMemoryRadarPlacesRepository,
    )

    class _NoSource:
        name = "none"

        def fetch_places(self, request_data: object) -> list[RadarPlace]:
            return []

    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [
        RadarDataSource(
            source="openstreetmap_overpass",
            release="test",
            license="ODbL",
            attribution="test",
            imported_at=NOW,
            min_latitude=35.0,
            max_latitude=47.5,
            min_longitude=6.0,
            max_longitude=19.0,
        )
    ]
    # As if imported before the rule: stored under a person's name.
    catalog.osm_places = [
        RadarPlace(
            coverage_key="catalog",
            place_type="veterinary",
            name=name,
            latitude=45.4642,
            longitude=9.19,
            source_name="openstreetmap_overpass",
            source_external_id=name,
        )
        for name in ("Dott. Mario Esempi", "Clinica Veterinaria Esempio")
    ]
    cells = InMemoryRadarPlacesRepository()
    service = ListNearbyRadarPlacesService(
        cells,
        RequestRadarPlacesIngestionService(cells, _NoSource()),  # type: ignore[arg-type]
        catalog,
        max_search_radius_km=50,
        freshness_ttl_hours=168,
    )

    result = service.execute(ListNearbyRadarPlacesInput(latitude=45.4642, longitude=9.19))

    assert [item.place.name for item in result.places] == ["Clinica Veterinaria Esempio"]


def test_exotic_competence_from_names_is_on_by_default() -> None:
    from packages.shared.config.settings import Settings

    assert Settings().radar_exotic_name_matching is True
