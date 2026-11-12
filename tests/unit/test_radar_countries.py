"""The radar's per-country pieces: registry, address formats, category and
name mapping, coverage levels and the offline importers. Everything runs
on the small synthetic file tests/fixtures/radar_countries_sample.json and
on temporary folders: no network, no database."""

import importlib
import json
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

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
from packages.core.domain.coverage.country_coverage import coverage_level
from packages.core.domain.geo.address_format import AddressParts, format_address
from packages.core.domain.geo.countries import (
    RADAR_COUNTRIES,
    get_radar_country,
    radar_country_for_point,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.radar_places.dedup import name_tokens, normalize_phone
from packages.core.domain.radar_places.labels import DEFAULT_PLACE_NAMES
from packages.core.domain.radar_places.models import (
    OSM_SOURCE_NAME,
    RadarCountryCoverage,
    RadarDataSource,
    RadarPlace,
)
from packages.core.domain.radar_reports.models import clean_place_name
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
)
from packages.infrastructure.radar_places.country_estimates import (
    COUNTRY_ESTIMATES,
    overpass_requests,
    total_database_mb,
)
from packages.infrastructure.radar_places.overpass_places_source import map_osm_element
from packages.infrastructure.radar_places.overture_mapping import (
    build_overture_query,
    overture_rows_to_places,
    place_to_open_row,
)
from packages.shared.errors.base import ValidationError

ROOT = Path(__file__).resolve().parents[2]
SAMPLE: dict[str, Any] = json.loads(
    (ROOT / "tests" / "fixtures" / "radar_countries_sample.json").read_text(encoding="utf-8")
)
NOW = datetime(2026, 10, 14, tzinfo=UTC)

# --- registry -----------------------------------------------------------------


def test_registry_has_the_seven_countries_with_unique_codes_and_regions() -> None:
    codes = [country.code for country in RADAR_COUNTRIES]
    assert codes == ["IT", "GB", "US", "AU", "DE", "FR", "ES"]
    region_codes = [code for country in RADAR_COUNTRIES for code in country.region_codes]
    assert len(region_codes) == len(set(region_codes))
    for country in RADAR_COUNTRIES:
        assert country.regions, country.code
        assert country.nominatim_code == country.code.lower()
        assert country.language in DEFAULT_PLACE_NAMES
        # Region codes are ISO 3166-2 of their own country.
        assert all(code.startswith(f"{country.code}-") for code in country.region_codes)


def test_region_counts_match_the_administrative_divisions() -> None:
    counts = {country.code: len(country.regions) for country in RADAR_COUNTRIES}
    assert counts == {"IT": 20, "GB": 4, "US": 51, "AU": 8, "DE": 16, "FR": 13, "ES": 19}


@pytest.mark.parametrize(
    ("latitude", "longitude", "expected"),
    [
        (45.4642, 9.19, "IT"),  # Milan
        (51.5072, -0.1276, "GB"),  # London
        (41.8781, -87.6298, "US"),  # Chicago
        (61.2181, -149.9003, "US"),  # Anchorage
        (21.3069, -157.8583, "US"),  # Honolulu
        (-33.8688, 151.2093, "AU"),  # Sydney
        (52.52, 13.405, "DE"),  # Berlin
        (48.8566, 2.3522, "FR"),  # Paris
        (40.4168, -3.7038, "ES"),  # Madrid
        (28.1235, -15.4363, "ES"),  # Las Palmas
        (35.6762, 139.6503, None),  # Tokyo
        (0.0, 0.0, None),
    ],
)
def test_country_of_a_point(latitude: float, longitude: float, expected: str | None) -> None:
    country = radar_country_for_point(Coordinates(latitude=latitude, longitude=longitude))
    assert (country.code if country else None) == expected


def test_overlapping_rectangles_resolve_to_the_smaller_country() -> None:
    # Dover lies in the rectangles of both Great Britain and France.
    dover = Coordinates(latitude=51.13, longitude=1.31)
    assert get_radar_country("FR").contains(dover)  # type: ignore[union-attr]
    country = radar_country_for_point(dover)
    assert country is not None and country.code == "GB"


def test_get_radar_country_ignores_case_and_rejects_unknown_codes() -> None:
    assert get_radar_country(" de ") is not None
    assert get_radar_country("XX") is None


# --- addresses ----------------------------------------------------------------


@pytest.mark.parametrize(
    ("country", "parts", "expected"),
    [
        ("IT", AddressParts("Via Roma", "12", "20100", "Milano"), "Via Roma 12, 20100 Milano"),
        (
            "US",
            AddressParts("Main St", "12", "62704", "Springfield", "IL"),
            "12 Main St, Springfield, IL 62704",
        ),
        (
            "US",
            AddressParts("Main St", "12", "62704", "Springfield", "US-IL"),
            "12 Main St, Springfield, IL 62704",
        ),
        (
            "GB",
            AddressParts("Downing Street", "10", "SW1A 2AA", "London"),
            "10 Downing Street, London SW1A 2AA",
        ),
        (
            "DE",
            AddressParts("Musterstraße", "12", "10115", "Berlin"),
            "Musterstraße 12, 10115 Berlin",
        ),
        (
            "FR",
            AddressParts("rue de la Paix", "12", "75002", "Paris"),
            "12 rue de la Paix, 75002 Paris",
        ),
        (
            "ES",
            AddressParts("Calle Mayor", "12", "28013", "Madrid"),
            "Calle Mayor 12, 28013 Madrid",
        ),
        (
            "AU",
            AddressParts("George St", "12", "2000", "Sydney", "nsw"),
            "12 George St, Sydney NSW 2000",
        ),
    ],
)
def test_one_function_writes_every_country_address(
    country: str, parts: AddressParts, expected: str
) -> None:
    assert format_address(parts, country) == expected


def test_missing_parts_are_left_out_without_stray_separators() -> None:
    assert (
        format_address(AddressParts("Via Roma", None, None, "Milano"), "IT") == "Via Roma, Milano"
    )
    assert format_address(AddressParts(None, None, "62704", "Springfield", "IL"), "US") == (
        "Springfield, IL 62704"
    )
    assert format_address(AddressParts(city="Berlin"), "DE") == "Berlin"
    assert format_address(AddressParts(), "FR") == ""
    assert format_address(AddressParts("  Calle   Mayor ", " 12 "), "ES") == "Calle Mayor 12"


def test_unknown_country_uses_the_european_default_order() -> None:
    parts = AddressParts("Rua Exemplo", "5", "1000", "Lisboa")
    assert format_address(parts, None) == "Rua Exemplo 5, 1000 Lisboa"
    assert format_address(parts, "PT") == "Rua Exemplo 5, 1000 Lisboa"
    # A full state name is shown as given, not guessed.
    assert format_address(
        AddressParts("Main St", "1", "62704", "Springfield", "Illinois"), "US"
    ) == ("1 Main St, Springfield, Illinois 62704")


# --- OpenStreetMap mapping (category, generic name, address) -----------------


@pytest.mark.parametrize("item", SAMPLE["osm"], ids=lambda item: f"{item['country']}-{item['id']}")
def test_osm_sample_maps_in_every_country(item: dict[str, Any]) -> None:
    element = {key: value for key, value in item.items() if key not in {"country", "expect"}}
    for given_country in (item["country"], None):
        # Same result whether the importer names the country or only the
        # position tells (the live source does not know it).
        place = map_osm_element(
            element, owner_id="", coverage_key="catalog", fetched_at=NOW, country_code=given_country
        )
        assert place is not None
        assert place.place_type == item["expect"]["place_type"]
        assert place.name == item["expect"]["name"]
        assert place.address_label == item["expect"]["address_label"]


def test_every_osm_category_has_a_generic_name_in_every_language() -> None:
    kinds = set(DEFAULT_PLACE_NAMES["it"])
    for language, names in DEFAULT_PLACE_NAMES.items():
        assert set(names) == kinds, language


def test_place_outside_every_supported_country_gets_an_english_generic_name() -> None:
    element = {
        "type": "node",
        "id": 5,
        "lat": 35.68,
        "lon": 139.65,
        "tags": {"amenity": "veterinary"},
    }
    place = map_osm_element(element, owner_id="", coverage_key="catalog", fetched_at=NOW)
    assert place is not None and place.name == "Veterinarian"


def test_addr_country_tag_beats_the_position_for_the_language() -> None:
    element = {
        "type": "node",
        "id": 6,
        "lat": 47.37,  # Zurich, in no supported country...
        "lon": 8.54,
        "tags": {"leisure": "dog_park", "addr:country": "DE"},
    }
    place = map_osm_element(element, owner_id="", coverage_key="catalog", fetched_at=NOW)
    assert place is not None and place.name == "Hundeauslaufplatz"


# --- Overture mapping ----------------------------------------------------------


def test_overture_sample_is_classified_in_every_country() -> None:
    for item in SAMPLE["overture"]:
        places = overture_rows_to_places([item], release="test")
        assert len(places) == 1, item["id"]
        assert places[0].place_type == item["expect"], (item["id"], item["name"])


def test_a_wrong_veterinary_category_is_only_corrected_by_a_plain_name() -> None:
    def kind(name: str) -> str:
        row = {
            "id": "x",
            "name": name,
            "category": "veterinarian",
            "confidence": 0.9,
            "operating_status": "open",
            "longitude": 0.0,
            "latitude": 0.0,
        }
        return overture_rows_to_places([row], release="t")[0].place_type

    assert kind("Oak Street Veterinary Clinic") == "veterinary"
    assert kind("Pet Hospital of Springfield") == "veterinary"
    assert kind("Bella Vet") == "veterinary"
    assert kind("Poodle Parlour Pet Groomers") == "grooming"
    assert kind("Elite Dog Training School") == "school"
    assert kind("Hundeschule Muster") == "school"
    assert kind("Pension canine Exemple") == "veterinary"  # "pension" alone is not specific
    assert kind("Pension pour animaux Exemple") == "hotel"
    # Two kinds in one name decide nothing.
    assert kind("Grooming and Pet Store") == "veterinary"


def test_overture_query_covers_the_country_rectangles_and_code() -> None:
    query = build_overture_query("2026-09-23.1", get_radar_country("US"))  # type: ignore[arg-type]
    assert "release/2026-09-23.1/theme=places" in query
    assert "addresses[1].country = 'US'" in query
    # contiguous states, Alaska and Hawaii: three rectangles joined by OR
    assert query.count("bbox.xmin BETWEEN") == 3 and query.count(" OR ") == 2
    assert "'veterinarian'" in query and "'pet_groomer'" in query


def test_open_rows_carry_the_country() -> None:
    place = overture_rows_to_places([SAMPLE["overture"][0]], release="t")[0]
    assert place_to_open_row(place, imported_at="2026-10-14", country="GB")["country"] == "GB"
    assert place_to_open_row(place, imported_at="2026-10-14")["country"] == "IT"


# --- dedup in other languages --------------------------------------------------


def test_generic_business_words_of_every_language_do_not_make_names_alike() -> None:
    assert not name_tokens("City Veterinary Clinic") & name_tokens("Park Veterinary Clinic")
    assert not name_tokens("Tierarztpraxis Nord") & name_tokens("Tierarztpraxis Süd")
    assert not name_tokens("Clinique Vétérinaire Nord") & name_tokens("Clinique Vétérinaire Sud")
    assert not name_tokens("Clínica Veterinaria Norte") & name_tokens("Clínica Veterinaria Sur")


def test_phone_numbers_compare_equal_in_national_and_international_form() -> None:
    pairs = [
        ("+44 20 7946 0000", "020 7946 0000"),
        ("+49 30 1234567", "030 1234567"),
        ("+33 1 42 68 53 00", "01 42 68 53 00"),
        ("+34 912 345 678", "912 345 678"),
        ("+1 415 555 0100", "(415) 555-0100"),
        ("+61 2 9374 4000", "(02) 9374 4000"),
        ("0039 02 0000 0001", "02 0000 0001"),
    ]
    for international, national in pairs:
        assert normalize_phone(international) == normalize_phone(national), international


# --- Segnala! without Italy -----------------------------------------------------


def test_place_names_are_checked_in_every_language() -> None:
    assert clean_place_name("  Happy   Paws ", place_type="grooming") == "Happy Paws"
    assert clean_place_name("Tierhandlung Müller", place_type="shop") == "Tierhandlung Müller"
    assert clean_place_name(None, place_type="dog_park", language="de") == "Hundeauslaufplatz"
    assert clean_place_name(None, place_type="dog_park", language="en") == "Dog park"
    for bad in (
        "Fuck this place",
        "Scheiße Tierarzt",
        "Mierda de sitio",
        "Putain de chien",
        "vets.co.uk",
        "praxis-beispiel.de",
        "Call 020 7946 0000",
        "ventes@exemple.fr",
    ):
        with pytest.raises(ValidationError):
            clean_place_name(bad, place_type="grooming")
    # An accented word that merely contains a blocked one is fine.
    assert clean_place_name("Shitake Café", place_type="shop") == "Shitake Café"


# --- coverage -------------------------------------------------------------------


def _row(country: str, **fields: Any) -> RadarCountryCoverage:
    return RadarCountryCoverage(country=country, **fields)


def test_coverage_levels() -> None:
    germany = get_radar_country("DE")
    assert coverage_level(None, None) == "unsupported"
    assert coverage_level(germany, None) == "live"
    assert coverage_level(germany, _row("DE")) == "live"
    assert coverage_level(germany, _row("DE", osm_regions=["DE-BY"])) == "partial"
    assert coverage_level(germany, _row("DE", overture_imported_at=utc_now())) == "partial"
    assert coverage_level(germany, _row("DE", osm_complete_at=utc_now())) == "complete"
    # Italy imported before the country table existed.
    assert coverage_level(get_radar_country("IT"), None, legacy_osm_covers=True) == "complete"


class _FakeSource:
    name = "fake"

    def __init__(self) -> None:
        self.requests: list[RequestRadarPlacesIngestionInput] = []

    def fetch_places(self, request_data: RequestRadarPlacesIngestionInput) -> list[RadarPlace]:
        self.requests.append(request_data)
        return []


def _catalog_place(name: str, lat: float, lon: float) -> RadarPlace:
    return RadarPlace(
        coverage_key="catalog",
        place_type="dog_park",
        name=name,
        latitude=lat,
        longitude=lon,
        source_name=OSM_SOURCE_NAME,
        source_external_id=name,
    )


def _service(catalog: InMemoryRadarCatalogRepository, source: _FakeSource) -> Any:
    repository = InMemoryRadarPlacesRepository()
    return ListNearbyRadarPlacesService(
        repository,
        RequestRadarPlacesIngestionService(repository, source),
        catalog,
        max_search_radius_km=50,
        freshness_ttl_hours=168,
    )


def _osm_source_row() -> RadarDataSource:
    # The row the importers write for other countries: no area at all.
    return RadarDataSource(
        source=OSM_SOURCE_NAME, release="2026-10-14", license="ODbL-1.0", attribution="x",
        imported_at=utc_now(),
    )  # fmt: skip


def test_complete_country_is_served_from_the_catalog_without_live_calls() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_osm_source_row()]
    catalog.country_coverage = [_row("DE", osm_complete_at=utc_now() - timedelta(days=1))]
    catalog.osm_places = [_catalog_place("Beispielpark", 52.521, 13.405)]
    source = _FakeSource()

    result = _service(catalog, source).execute(
        ListNearbyRadarPlacesInput(latitude=52.52, longitude=13.405)
    )

    assert source.requests == []
    assert [item.place.name for item in result.places] == ["Beispielpark"]
    assert (result.country, result.coverage_level) == ("DE", "complete")
    assert result.coverage_status == "fresh"


def test_empty_area_of_a_complete_country_falls_back_to_the_live_provider() -> None:
    # Dublin is inside the rectangle of Great Britain; nothing of ours is there.
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_osm_source_row()]
    catalog.country_coverage = [_row("GB", osm_complete_at=utc_now())]
    catalog.osm_places = [_catalog_place("Parkfar", 51.5, -0.12)]
    source = _FakeSource()

    result = _service(catalog, source).execute(
        ListNearbyRadarPlacesInput(latitude=53.35, longitude=-6.26)
    )

    assert len(source.requests) == 1
    assert result.coverage_status == "refreshed"
    assert result.country == "GB"


def test_supported_country_not_imported_yet_is_served_live_and_says_so() -> None:
    source = _FakeSource()
    result = _service(InMemoryRadarCatalogRepository(), source).execute(
        ListNearbyRadarPlacesInput(latitude=40.4168, longitude=-3.7038)
    )
    assert len(source.requests) == 1
    assert (result.country, result.coverage_level) == ("ES", "live")


def test_unsupported_country_is_served_live_and_says_so() -> None:
    source = _FakeSource()
    result = _service(InMemoryRadarCatalogRepository(), source).execute(
        ListNearbyRadarPlacesInput(latitude=35.68, longitude=139.65)
    )
    assert len(source.requests) == 1
    assert (result.country, result.coverage_level) == (None, "unsupported")


def test_one_country_complete_does_not_cover_another() -> None:
    catalog = InMemoryRadarCatalogRepository()
    catalog.sources = [_osm_source_row()]
    catalog.country_coverage = [_row("DE", osm_complete_at=utc_now())]
    catalog.osm_places = [_catalog_place("Beispielpark", 52.521, 13.405)]
    source = _FakeSource()

    result = _service(catalog, source).execute(
        ListNearbyRadarPlacesInput(latitude=48.8566, longitude=2.3522)  # Paris
    )

    assert len(source.requests) == 1
    assert (result.country, result.coverage_level) == ("FR", "live")


# --- estimates ------------------------------------------------------------------


def test_every_country_has_an_estimate_and_the_total_is_stated() -> None:
    assert set(COUNTRY_ESTIMATES) == {country.code for country in RADAR_COUNTRIES}
    assert COUNTRY_ESTIMATES["IT"].measured
    assert not any(
        estimate.measured for code, estimate in COUNTRY_ESTIMATES.items() if code != "IT"
    )
    # Italy: ~9 MB per source (measured).
    assert COUNTRY_ESTIMATES["IT"].overture_mb == pytest.approx(9, abs=1)
    assert COUNTRY_ESTIMATES["IT"].osm_mb == pytest.approx(9, abs=1)
    assert total_database_mb(["DE"]) == pytest.approx(COUNTRY_ESTIMATES["DE"].total_mb)
    for country in RADAR_COUNTRIES:
        low, high = overpass_requests(country)
        assert low == len(country.regions) < high


# --- offline importer, on cached files -------------------------------------------


def _load_script(name: str) -> Any:
    scripts = str(ROOT / "scripts" / "radar")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    return importlib.import_module(name)


def test_osm_importer_lists_regions_and_dry_runs_from_the_cache(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    importer = _load_script("import_osm_places")
    monkeypatch.setattr(importer, "CACHE_DIR", tmp_path)

    monkeypatch.setattr(sys, "argv", ["import_osm_places.py", "--country", "DE", "--list-regions"])
    assert importer.main() == 0
    listing = capsys.readouterr().out
    assert "DE-BY" in listing and "16 regioni" in listing

    # Two German regions "already downloaded" from the synthetic sample.
    elements = [
        {key: value for key, value in item.items() if key not in {"country", "expect"}}
        for item in SAMPLE["osm"]
        if item["country"] == "DE"
    ]
    for code in ("DE-BE", "DE-BY"):
        (tmp_path / f"{code}.json").write_text(
            json.dumps({"fetched_at": datetime.now(UTC).isoformat(), "elements": elements}),
            encoding="utf-8",
        )
    monkeypatch.setattr(
        sys,
        "argv",
        ["import_osm_places.py", "--country", "DE", "--regions", "DE-BE", "DE-BY", "--dry-run"],
    )
    assert importer.main() == 0
    report = capsys.readouterr().out
    # The same elements in two regions are one place each (keyed by id).
    assert "2 luoghi in totale da 2 regioni (DE)" in report
    assert "Dry run" in report


def test_osm_importer_refuses_regions_of_another_country_and_empty_answers(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    importer = _load_script("import_osm_places")
    monkeypatch.setattr(importer, "CACHE_DIR", tmp_path)

    monkeypatch.setattr(
        sys, "argv", ["import_osm_places.py", "--country", "DE", "--regions", "IT-25"]
    )
    with pytest.raises(SystemExit):
        importer.main()

    (tmp_path / "DE-HB.json").write_text(
        json.dumps({"fetched_at": datetime.now(UTC).isoformat(), "elements": []}),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        sys,
        "argv",
        ["import_osm_places.py", "--country", "DE", "--regions", "DE-HB", "--max-seconds", "1"],
    )
    # An empty region from the cache is not trusted (wrong area code?): it is
    # asked again, and with no time budget the run stops cleanly to resume.
    assert importer.main() == importer.EXIT_RESUME
    assert "Nulla è stato scritto" in capsys.readouterr().out


def test_unknown_country_is_refused_with_the_list_of_known_ones() -> None:
    common = _load_script("common")
    with pytest.raises(SystemExit) as raised:
        common.parse_country("JP")
    assert "IT, GB, US, AU, DE, FR, ES" in str(raised.value)
    assert common.legacy_bounds_for(common.parse_country("DE")) == {}
    assert common.legacy_bounds_for(common.parse_country("IT"))["min_latitude"] == 35.2
