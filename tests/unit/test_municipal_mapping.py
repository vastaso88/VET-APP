from packages.core.domain.radar_places.dedup import merge_radar_places, same_place
from packages.core.domain.radar_places.models import RadarPlace
from packages.infrastructure.radar_places.municipal_mapping import (
    BOLOGNA,
    MILANO,
    TORINO,
    bologna_record_to_place,
    milano_feature_to_place,
    municipal_records_to_places,
    torino_row_to_place,
)
from packages.infrastructure.radar_places.overture_mapping import place_to_open_row

BOLOGNA_RECORD = {
    "geo_point_2d": {"lon": 11.340104717155295, "lat": 44.51570250355693},
    "id": "1",
    "nome": "Giardino Esempio",
    "nomezona": "ZONAESEMPIO",
    "area": "1518.12",
}

TORINO_ROW = {
    "longitudine": "7.65695483252664",
    "latitudine": "45.1077251962322",
    "nome": "Area cani Esempio",
    "indirizzo": "via Esempio 1",
    "gestione": "Circoscrizione",
}


def test_bologna_record_becomes_a_dog_park_with_its_own_source() -> None:
    place = bologna_record_to_place(BOLOGNA_RECORD, release="2026-10-04")

    assert place is not None
    assert place.id == "comune_bologna|1"
    assert (place.place_type, place.name) == ("dog_park", "Giardino Esempio")
    assert place.address_label == "Zonaesempio, Bologna"
    assert place.species == ["dog"]
    assert (place.source_name, place.license) == ("comune_bologna", "CC-BY-4.0")


def test_torino_row_uses_its_position_as_identifier() -> None:
    place = torino_row_to_place(TORINO_ROW, release="2026-10-04")

    assert place is not None
    assert place.source_external_id == "45.107725,7.656955"
    assert place.address_label == "via Esempio 1, Torino"
    assert place.source_name == "comune_torino"


def test_rows_without_a_position_are_skipped_and_duplicates_collapse() -> None:
    places = municipal_records_to_places(
        TORINO,
        [TORINO_ROW, TORINO_ROW, {"nome": "Senza posizione"}],
        release="2026-10-04",
    )
    assert len(places) == 1

    assert municipal_records_to_places(BOLOGNA, [{"id": "9"}], release="r") == []


def test_open_row_of_a_municipal_park_carries_its_license() -> None:
    place = bologna_record_to_place(BOLOGNA_RECORD, release="2026-10-04")
    assert place is not None

    row = place_to_open_row(place, imported_at="2026-10-04T00:00:00+00:00")

    assert (row["source"], row["license"], row["place_type"]) == (
        "comune_bologna",
        "CC-BY-4.0",
        "dog_park",
    )


def _osm_park(meters_north: float, **details: str) -> RadarPlace:
    return RadarPlace(
        coverage_key="catalog",
        place_type="dog_park",
        name="Area cani",
        latitude=45.1077251962322 + meters_north / 111_320,
        longitude=7.65695483252664,
        source_name="openstreetmap_overpass",
        source_external_id=f"way/{meters_north}",
        details=details,
    )


def test_the_same_dog_park_in_osm_and_in_the_municipal_list_is_one_place() -> None:
    municipal = torino_row_to_place(TORINO_ROW, release="r")
    assert municipal is not None

    # Centres of two outlines of the same park are tens of metres apart.
    assert same_place(_osm_park(50), municipal) == "same_spot"
    assert same_place(_osm_park(90), municipal) is None


def test_osm_details_are_not_lost_when_the_municipal_record_only_adds_an_address() -> None:
    municipal = torino_row_to_place(TORINO_ROW, release="r")
    assert municipal is not None

    merged = merge_radar_places([_osm_park(20, barrier="fence")], [municipal])

    assert len(merged) == 1
    assert merged[0].source_name == "openstreetmap_overpass"
    assert merged[0].details == {"barrier": "fence"}
    assert merged[0].confirmed_by == ["comune_torino"]


MILANO_FEATURE = {
    "type": "Feature",
    "properties": {"id_area": "1_043", "municipio": 1, "localit\u00e0": "via Esempio"},
    "geometry": {
        "type": "MultiPolygon",
        "coordinates": [[[[9.19, 45.46], [9.192, 45.46], [9.192, 45.462], [9.19, 45.462]]]],
    },
}


def test_milano_feature_is_placed_at_the_centre_of_its_outline() -> None:
    place = milano_feature_to_place(MILANO_FEATURE, release="2026-10-04")

    assert place is not None
    assert place.id == "comune_milano|1_043"
    assert place.name == "Area cani via Esempio"
    assert place.address_label == "via Esempio, Milano"
    assert (round(place.latitude, 3), round(place.longitude, 3)) == (45.461, 9.191)
    assert (place.source_name, place.license) == ("comune_milano", "CC-BY-4.0")


def test_milano_features_without_an_outline_or_id_are_skipped() -> None:
    no_geometry = {"properties": {"id_area": "1_001"}, "geometry": None}
    no_id = {**MILANO_FEATURE, "properties": {}}

    assert municipal_records_to_places(MILANO, [no_geometry, no_id], release="r") == []
