from packages.core.domain.radar_places.dedup import (
    merge_radar_places,
    name_tokens,
    names_compatible,
    normalize_phone,
    same_place,
    website_domain,
)
from packages.core.domain.radar_places.models import RadarPlace

# ~11 m per 0.0001 deg of latitude.
BASE_LAT, BASE_LON = 45.4642, 9.1900


def _place(
    name: str,
    *,
    source: str = "openstreetmap_overpass",
    meters_north: float = 0,
    place_type: str = "veterinary",
    phone: str | None = None,
    website_url: str | None = None,
    opening_hours: str | None = None,
    address_label: str | None = None,
) -> RadarPlace:
    return RadarPlace(
        coverage_key=source,
        place_type=place_type,
        name=name,
        latitude=BASE_LAT + meters_north / 111_320,
        longitude=BASE_LON,
        source_name=source,
        source_external_id=f"{name}-{meters_north}",
        phone=phone,
        website_url=website_url,
        opening_hours=opening_hours,
        address_label=address_label,
    )


def test_phone_normalization_ignores_prefix_and_formatting() -> None:
    assert normalize_phone("+39 02 0000 0001") == normalize_phone("02-0000-0001") == "0200000001"
    assert normalize_phone("0039 02 0000 0004") == "0200000004"
    assert normalize_phone("123") is None
    assert normalize_phone(None) is None


def test_website_domain_ignores_shared_platforms() -> None:
    assert (
        website_domain("https://www.Clinica-Esempio.example/contatti") == "clinica-esempio.example"
    )
    assert website_domain("clinica-esempio.example") == "clinica-esempio.example"
    assert website_domain("https://www.facebook.com/clinica-esempio") is None
    assert website_domain("https://www.openstreetmap.org/node/1") is None
    assert website_domain(None) is None


def test_name_tokens_drop_generic_words_and_accents() -> None:
    assert name_tokens("Ambulatorio Veterinario Dott.ssa Bianchi S.r.l.") == {"bianchi"}
    assert name_tokens("Clinica Veterinaria Città Studi") == {"citta", "studi"}
    assert name_tokens("Ambulatorio Veterinario") == frozenset()


def test_names_made_only_of_generic_words_are_not_compatible() -> None:
    assert names_compatible("Clinica Veterinaria Duomo", "Ambulatorio Duomo")
    assert not names_compatible("Ambulatorio Veterinario", "Clinica Veterinaria")
    assert not names_compatible("Veterinario", "Ambulatorio Veterinario Rossi")
    assert not names_compatible("Ambulatorio Rossi", "Ambulatorio Bianchi")


def test_same_name_spaced_differently_is_compatible() -> None:
    assert names_compatible("Dog Cooker", "Dogcooker")
    assert names_compatible("Washdog", "Toelettatura Wash Dog")
    assert names_compatible("Zoo Planet", "Zooplanet")
    assert not names_compatible("Bau", "Ba U")


def test_differently_named_businesses_at_the_same_spot_stay_separate() -> None:
    first = _place("Coda Felice", place_type="shop")
    second = _place("Zampa Market", source="overture", place_type="shop", meters_north=7)

    assert same_place(first, second) is None


def test_same_phone_is_the_same_place_only_nearby() -> None:
    osm = _place("Clinica Duomo", phone="+39 02 0000 0001")
    near = _place("Duomo Vet", source="overture", meters_north=200, phone="0200000001")
    far = _place("Duomo Vet", source="overture", meters_north=2000, phone="0200000001")

    assert same_place(osm, near) == "same_phone"
    assert same_place(osm, far) is None


def test_chain_branches_sharing_a_website_stay_separate() -> None:
    first = _place(
        "Zampa Market", place_type="shop", website_url="https://www.zampa-market.example"
    )
    branch = _place(
        "Zampa Market",
        source="overture",
        place_type="shop",
        meters_north=250,
        website_url="https://zampa-market.example/negozi/milano",
    )
    same_shop = _place(
        "Zampa Market Milano",
        source="overture",
        place_type="shop",
        meters_north=90,
        website_url="https://zampa-market.example/negozi/milano",
    )

    assert same_place(first, branch) is None
    assert same_place(first, same_shop) == "same_website"


def test_same_spot_merges_unless_two_practices_share_the_building() -> None:
    osm = _place("Veterinario")
    unnamed_twin = _place("Ambulatorio Veterinario Rossi", source="overture", meters_north=15)
    assert same_place(osm, unnamed_twin) == "same_spot"

    rossi = _place("Ambulatorio Rossi", phone="02 0000 0002")
    bianchi = _place(
        "Ambulatorio Bianchi", source="overture", meters_north=10, phone="02 0000 0003"
    )
    assert same_place(rossi, bianchi) is None


def test_near_needs_a_distinctive_word_in_common() -> None:
    osm = _place("Clinica Veterinaria San Siro")
    match = _place("San Siro Vet Srl", source="overture", meters_north=100)
    generic = _place("Ambulatorio Veterinario", source="overture", meters_north=100)
    other = _place("Clinica Veterinaria Lotto", source="overture", meters_north=100)
    too_far = _place("Clinica Veterinaria San Siro", source="overture", meters_north=150)

    assert same_place(osm, match) == "near_same_name"
    assert same_place(osm, generic) is None
    assert same_place(osm, other) is None
    assert same_place(osm, too_far) is None


def test_different_categories_never_merge() -> None:
    clinic = _place("Zampa Felice")
    shop = _place("Zampa Felice", source="overture", place_type="shop", meters_north=5)

    assert same_place(clinic, shop) is None


def test_merge_keeps_one_record_from_the_richer_source_and_names_the_other() -> None:
    osm = _place("Clinica Duomo", opening_hours="Mo-Fr 09:00-19:00")
    overture = _place(
        "Clinica Veterinaria Duomo",
        source="overture",
        meters_north=20,
        phone="+39 02 0000 0001",
        website_url="https://clinica-duomo.example",
        address_label="Via Esempio 10",
    )

    merged = merge_radar_places([osm], [overture])

    assert len(merged) == 1
    place = merged[0]
    # The richer record wins whole: no OSM hours grafted onto Overture data.
    assert place.source_name == "overture"
    assert place.phone == "+39 02 0000 0001"
    assert place.opening_hours is None
    assert place.confirmed_by == ["openstreetmap_overpass"]


def test_merge_ties_go_to_the_first_source() -> None:
    osm = _place("Clinica Duomo", phone="02 0000 0001")
    overture = _place("Clinica Duomo", source="overture", meters_north=5, phone="02 0000 0001")

    merged = merge_radar_places([osm], [overture])

    assert [place.source_name for place in merged] == ["openstreetmap_overpass"]
    assert merged[0].confirmed_by == ["overture"]


def test_merge_keeps_unmatched_places_from_both_sources() -> None:
    osm = [_place("Clinica Duomo"), _place("Area cani", place_type="dog_park", meters_north=40)]
    overture = [
        _place("Ambulatorio Lotto", source="overture", meters_north=900),
        _place("Clinica Veterinaria Duomo", source="overture", meters_north=60),
    ]

    merged = merge_radar_places(osm, overture)

    assert sorted(place.name for place in merged) == [
        "Ambulatorio Lotto",
        "Area cani",
        "Clinica Duomo",
    ]


def test_merge_does_not_mutate_its_inputs() -> None:
    osm = [_place("Clinica Duomo")]
    overture = [_place("Clinica Duomo", source="overture", meters_north=5)]

    merge_radar_places(osm, overture)

    assert osm[0].confirmed_by == []
    assert overture[0].confirmed_by == []


def test_same_clinic_written_differently_by_two_sources_is_one_card() -> None:
    # What the two sources really do with one clinic: different capitals,
    # and the full name in one against the bare name in the other.
    for osm_name, overture_name in (
        ("Clinica Veterinaria Esempio", "CLINICA VETERINARIA ESEMPIO"),
        ("Ambulatorio Veterinario Esempio", "Esempio"),
        ("Ambulatorio Veterinario Dott. Esempio", "ambulatorio veterinario esempio"),
    ):
        osm = _place(osm_name)
        overture = _place(overture_name, source="overture", meters_north=80)

        merged = merge_radar_places([osm], [overture])

        assert len(merged) == 1, (osm_name, overture_name)
        assert merged[0].confirmed_by == ["overture"]


def test_generic_name_against_a_named_clinic_merges_only_at_the_same_spot() -> None:
    named = _place("Ambulatorio Veterinario Esempio")

    same_door = _place("Ambulatorio Veterinario", source="overture", meters_north=20)
    down_the_road = _place("Ambulatorio Veterinario", source="overture", meters_north=90)

    assert len(merge_radar_places([named], [same_door])) == 1
    # 90 m away it may well be another practice: kept apart on purpose.
    assert len(merge_radar_places([named], [down_the_road])) == 2
