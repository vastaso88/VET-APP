from datetime import date
from pathlib import Path
from typing import Any

import pytest

from packages.core.domain.events.regions import REGIONS_BY_COUNTRY
from packages.core.domain.geo.countries import get_radar_country
from packages.infrastructure.events.curated_events import validate_curated_event
from packages.infrastructure.events.gazetteer import (
    Gazetteer,
    Town,
    fill_missing_places,
    load_gazetteer,
    normalize_place_name,
    write_table,
)
from packages.infrastructure.events.overture_divisions import (
    ATTRIBUTION_LINES,
    ITALIAN_PROVINCES,
    app_region_names,
    build_localities_query,
    missing_app_regions,
    province_code,
    rows_to_towns,
)

TODAY = date(2026, 11, 26)

# Fictional coordinates: the tests check the matching, not geography.
GAZETTEER = Gazetteer(
    {
        "IT": [
            Town("Modena", 44.6, 10.9, province="MO", region="Emilia-Romagna", seat=True),
            Town("Città di Castello", 43.4, 12.2, province="PG", region="Umbria", seat=True),
            # Same name, two provinces.
            Town("Calliano", 45.9, 11.1, province="TN", region="Trentino-Alto Adige", seat=True),
            Town("Calliano", 45.0, 8.2, province="AT", region="Piemonte", seat=True),
            # Same name, same province, a seat and a hamlet: the seat wins.
            Town("Fermo", 43.1, 13.7, province="FM", region="Marche", seat=True),
            Town("Fermo", 43.2, 13.6, province="FM", region="Marche", seat=False),
            # Same name, same province, two hamlets: ambiguous.
            Town("San Martino", 45.1, 9.1, province="PV", region="Lombardia"),
            Town("San Martino", 45.2, 9.3, province="PV", region="Lombardia"),
            # A Sardinian province of the 2025 reform: no abbreviation in the source.
            Town("Iglesias", 39.3, 8.5, province=None, region="Sardegna", seat=True),
        ],
        "US": [
            Town("Springfield", 39.8, -89.6, region="Illinois", seat=True),
            Town("Springfield", 37.2, -93.3, region="Missouri", seat=True),
        ],
        "DE": [Town("München", 48.1, 11.6, region="Bayern", seat=True)],
    }
)


def _event(**overrides: Any) -> Any:
    raw: dict[str, Any] = {
        "slug": "fiera-di-prova-2026",
        "title": "Fiera di prova",
        "event_type": "pet_fair",
        "level": "local",
        "level_basis": "default",
        "starts_on": "2026-12-05",
        "ends_on": "2026-12-06",
        "region": "Emilia-Romagna",
        "city": "Modena",
        "province_code": "MO",
        "source_url": "https://www.example.org/fiera",
        "verified_on": "2026-11-20",
    }
    raw.update(overrides)
    return validate_curated_event(raw, today=TODAY)


def _fill_one(**overrides: Any) -> tuple[Any, str]:
    events, notes = fill_missing_places([_event(**overrides)], GAZETTEER)
    return events[0], notes[0]


def test_names_match_without_accents_case_or_punctuation() -> None:
    assert normalize_place_name("CITTÀ  di-Castello") == normalize_place_name("Città di Castello")
    assert normalize_place_name("Reggio nell'Emilia") == "reggio nell emilia"


def test_an_italian_town_is_found_by_name_and_province() -> None:
    event, note = _fill_one()
    assert event.place is not None
    assert (event.place.latitude, event.place.longitude) == (44.6, 10.9)
    assert "provincia MO" in note


def test_accents_and_case_do_not_matter() -> None:
    event, _ = _fill_one(city="citta DI castello", province_code="PG", region="Umbria")
    assert event.place is not None and event.place.latitude == 43.4


def test_the_province_tells_apart_two_towns_with_the_same_name() -> None:
    event, _ = _fill_one(city="Calliano", province_code="AT", region="Piemonte")
    assert event.place is not None and event.place.longitude == 8.2


def test_the_seat_wins_over_a_hamlet_with_the_same_name() -> None:
    event, _ = _fill_one(city="Fermo", province_code="FM", region="Marche")
    assert event.place is not None and event.place.latitude == 43.1


def test_an_ambiguous_name_leaves_the_event_without_coordinates() -> None:
    event, note = _fill_one(city="San Martino", province_code="PV", region="Lombardia")
    assert event.place is None
    assert "ambiguo" in note


def test_a_town_not_in_the_table_leaves_the_event_without_coordinates() -> None:
    event, note = _fill_one(city="Esempiopoli", province_code="MI", region="Lombardia")
    assert event.place is None
    assert "non trovato" in note


def test_a_town_of_another_province_is_not_taken() -> None:
    event, note = _fill_one(city="Modena", province_code="BO", region="Lombardia")
    assert event.place is None
    assert "non trovato" in note


def test_the_region_helps_when_the_source_has_no_province_for_the_town() -> None:
    event, note = _fill_one(city="Iglesias", province_code="SU", region="Sardegna")
    assert event.place is not None and event.place.latitude == 39.3
    assert "regione Sardegna" in note


def test_the_region_never_overrules_a_known_province() -> None:
    # Modena is in the table with MO: an event saying BO must not get it through the region.
    event, note = _fill_one(city="Modena", province_code="BO", region="Emilia-Romagna")
    assert event.place is None
    assert "non trovato" in note


def test_the_region_never_hands_out_a_hamlet_of_another_province() -> None:
    # Only a hamlet "Fermo" would be left if the seat were missing: not good enough.
    gazetteer = Gazetteer(
        {"IT": [Town("Fermo", 43.2, 13.6, province="AP", region="Marche", seat=False)]}
    )
    events, notes = fill_missing_places(
        [_event(city="Fermo", province_code="FM", region="Marche")], gazetteer
    )
    assert events[0].place is None
    assert "non trovato" in notes[0]


def test_explicit_coordinates_always_win() -> None:
    event, note = _fill_one(latitude=44.65, longitude=10.93)
    assert event.place is not None
    assert (event.place.latitude, event.place.longitude) == (44.65, 10.93)
    assert "già nel file" in note


def test_another_country_is_matched_by_region() -> None:
    event, note = _fill_one(country="US", city="Springfield", province_code="MO", region="Missouri")
    assert event.place is not None and event.place.longitude == -93.3
    assert "regione Missouri" in note


def test_abroad_two_places_with_one_name_in_a_region_are_ambiguous_even_with_a_seat() -> None:
    gazetteer = Gazetteer(
        {
            "GB": [
                Town("Newport", 51.6, -3.0, region="Wales", seat=False),
                Town("Newport", 52.0, -4.8, region="Wales", seat=True),
            ]
        }
    )
    lookup = gazetteer.locate(country="GB", city="Newport", region="Wales")
    assert lookup.town is None and "ambiguo" in lookup.reason


def test_a_bilingual_name_answers_to_each_language() -> None:
    gazetteer = Gazetteer(
        {
            "IT": [
                Town("Aosta / Aoste", 45.7, 7.3, province="AO", region="Valle d'Aosta", seat=True),
                Town("Bolzano - Bozen", 46.5, 11.4, province="BZ", region="Trentino-Alto Adige"),
            ]
        }
    )
    for city, province in (("Aosta", "AO"), ("Aoste", "AO"), ("Bozen", "BZ"), ("Bolzano", "BZ")):
        assert gazetteer.locate(country="IT", city=city, province_code=province).town is not None
    assert len(gazetteer) == 2


def test_without_region_a_shared_name_abroad_is_not_guessed() -> None:
    event, note = _fill_one(country="US", city="Springfield", province_code=None, region=None)
    assert event.place is None
    assert "manca la provincia o la regione" in note


def test_a_country_without_a_table_is_said_clearly() -> None:
    event, note = _fill_one(country="FR", city="Rennes", province_code="35", region="Bretagne")
    assert event.place is None
    assert "nessuna tabella" in note


def test_the_table_round_trips_through_its_file(tmp_path: Path) -> None:
    towns = [Town("München", 48.13743, 11.57549, region="Bayern", seat=True)]
    write_table(tmp_path / "DE.tsv", towns, header_comments=ATTRIBUTION_LINES)
    text = (tmp_path / "DE.tsv").read_text(encoding="utf-8")
    assert text.startswith("# © OpenStreetMap contributors")
    loaded = load_gazetteer(tmp_path)
    lookup = loaded.locate(country="DE", city="munchen", region="Bayern")
    assert lookup.town == Town("München", 48.137, 11.575, region="Bayern", seat=True)


def test_a_missing_folder_is_an_empty_table(tmp_path: Path) -> None:
    assert len(load_gazetteer(tmp_path / "nothing")) == 0


def test_a_malformed_table_is_refused(tmp_path: Path) -> None:
    (tmp_path / "IT.tsv").write_text("name\tlatitude\n", encoding="utf-8")
    with pytest.raises(ValueError):
        load_gazetteer(tmp_path)


# --- Overture divisions -----------------------------------------------------------------------


def _level(subtype: str, name: str) -> dict[str, str]:
    return {"division_id": name.lower(), "subtype": subtype, "name": name}


def _locality(name: str, region_code: str, *levels: dict[str, str], cls: str = "town") -> Any:
    return {
        "name": name,
        "class": cls,
        "region_code": region_code,
        "longitude": 10.92557,
        "latitude": 44.64588,
        "hierarchy": [*levels, _level("locality", name)],
        "license": "ODbL-1.0",
    }


ITALY = get_radar_country("IT")
EMILIA = [_level("country", "Italia"), _level("region", "Emilia-Romagna")]


@pytest.mark.parametrize(
    ("county", "code"),
    [
        ("Modena", "MO"),
        ("Città metropolitana di Milano", "MI"),
        ("Provincia di Fermo", "FM"),
        ("Ente di decentramento regionale di Pordenone", "PN"),
        ("Bolzano - Alto Adige / Bozen - Südtirol", "BZ"),
        ("Reggio nell'Emilia", "RE"),
        ("Roma Capitale", "RM"),
        ("Medio Campidano", None),
        ("Nowhere", None),
        (None, None),
    ],
)
def test_the_county_name_gives_the_province_abbreviation(county: str | None, code: str) -> None:
    assert province_code(county) == code


def test_the_province_table_has_every_italian_province_once() -> None:
    assert len(ITALIAN_PROVINCES) == 107
    names = [normalize_place_name(n) for names in ITALIAN_PROVINCES.values() for n in names]
    assert len(names) == len(set(names))


def test_a_municipality_is_a_seat_and_its_hamlet_is_not() -> None:
    assert ITALY is not None
    county = _level("county", "Modena")
    result = rows_to_towns(
        [
            _locality("Modena", "IT-45", *EMILIA, county, cls="city"),
            _locality("Cognento", "IT-45", *EMILIA, county, _level("locality", "Modena")),
        ],
        ITALY,
    )
    modena, cognento = result.towns
    assert modena == Town(
        "Modena", 44.64588, 10.92557, province="MO", region="Emilia-Romagna", seat=True
    )
    assert cognento.seat is False and cognento.province == "MO"
    assert result.licenses == {"ODbL-1.0": 2}


def test_an_unknown_county_is_counted_and_the_town_keeps_its_region() -> None:
    assert ITALY is not None
    result = rows_to_towns(
        [_locality("Paese", "IT-45", *EMILIA, _level("county", "Nowhere"))], ITALY
    )
    assert result.towns[0].province is None
    assert result.towns[0].region == "Emilia-Romagna"
    assert result.unknown_counties == {"Nowhere": 1}


def test_aosta_valley_has_no_county_and_is_ao() -> None:
    assert ITALY is not None
    valley = [_level("country", "Italia"), _level("region", "Valle d'Aosta")]
    result = rows_to_towns([_locality("Aosta", "IT-23", *valley, cls="city")], ITALY)
    assert result.towns[0].province == "AO"
    assert not result.unknown_counties


def test_another_country_gets_the_region_from_the_iso_code() -> None:
    spain = get_radar_country("ES")
    assert spain is not None
    result = rows_to_towns([_locality("Getafe", "ES-MD", _level("country", "España"))], spain)
    assert result.towns[0].region == "Comunidad de Madrid"
    assert result.towns[0].province is None


def test_corsica_has_the_code_overture_writes() -> None:
    france = get_radar_country("FR")
    assert france is not None
    assert app_region_names(france)["FR-20R"] == "Corse"


@pytest.mark.parametrize("code", sorted(REGIONS_BY_COUNTRY))
def test_every_region_of_the_app_has_an_iso_code(code: str) -> None:
    country = get_radar_country(code)
    assert country is not None
    assert missing_app_regions(country) == []
    assert set(app_region_names(country).values()) <= REGIONS_BY_COUNTRY[code]


def test_the_query_reads_only_the_country_and_its_municipalities() -> None:
    assert ITALY is not None
    sql = build_localities_query("2026-11-18.0", ITALY)
    assert "release/2026-11-18.0/theme=divisions/type=division/" in sql
    assert "country = 'IT'" in sql and "subtype = 'locality'" in sql


def test_every_committed_table_carries_the_licence_attribution() -> None:
    folder = Path(__file__).resolve().parents[2] / "scripts" / "events" / "gazetteer"
    for path in folder.glob("*.tsv"):
        head = path.read_text(encoding="utf-8").splitlines()[: len(ATTRIBUTION_LINES)]
        assert head == [f"# {line}" for line in ATTRIBUTION_LINES], path.name
        assert len(load_gazetteer(folder)) > 0


@pytest.mark.parametrize(
    ("city", "province", "region"),
    [
        ("Cremona", "CR", "Lombardia"),
        ("Modena", "MO", "Emilia-Romagna"),
        ("Busto Arsizio", "VA", "Lombardia"),
        ("Fermo", "FM", "Marche"),
        ("Pordenone", "PN", "Friuli-Venezia Giulia"),
    ],
)
def test_the_committed_italian_table_finds_the_towns_of_the_real_events(
    city: str, province: str, region: str
) -> None:
    folder = Path(__file__).resolve().parents[2] / "scripts" / "events" / "gazetteer"
    if not (folder / "IT.tsv").exists():
        pytest.skip("no Italian table committed")
    lookup = load_gazetteer(folder).locate(
        country="IT", city=city, province_code=province, region=region
    )
    assert lookup.town is not None, lookup.reason
    assert lookup.town.province == province
