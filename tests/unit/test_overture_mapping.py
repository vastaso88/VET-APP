from typing import Any

from packages.infrastructure.radar_places.overture_mapping import (
    overture_row_to_place,
    overture_rows_to_places,
    place_to_open_row,
)


def _row(**overrides: Any) -> dict[str, Any]:
    row: dict[str, Any] = {
        "id": "abc-1",
        "name": "Ambulatorio Veterinario Esempio",
        "category": "veterinarian",
        "confidence": 0.95,
        "operating_status": "open",
        "latitude": 45.4901,
        "longitude": 9.1502,
        "address": "Via Esempio 1",
        "locality": "Milano",
        "phone": "+390200000004",
        "website": None,
        "license": "CDLA-Permissive-2.0",
    }
    row.update(overrides)
    return row


def test_maps_a_confident_open_veterinarian() -> None:
    place = overture_row_to_place(_row(), release="2026-09-23.1")

    assert place is not None
    assert place.id == "overture|abc-1"
    assert (place.place_type, place.subtype) == ("veterinary", "veterinarian")
    assert place.source_name == "overture"
    assert place.address_label == "Via Esempio 1"
    assert place.phone == "+390200000004"
    assert place.release == "2026-09-23.1"
    assert place.license == "CDLA-Permissive-2.0"


def test_category_match_is_exact() -> None:
    # "carpet_store" contains "pet_store": a substring match would import
    # every carpet shop in the country.
    assert overture_row_to_place(_row(category="carpet_store"), release="r") is None
    assert overture_row_to_place(_row(category="dog_park"), release="r") is None
    groomer = overture_row_to_place(_row(category="pet_groomer"), release="r")
    assert groomer is not None and groomer.place_type == "grooming"


def test_low_confidence_closed_and_incomplete_rows_are_skipped() -> None:
    assert overture_row_to_place(_row(confidence=0.69), release="r") is None
    assert overture_row_to_place(_row(confidence=None), release="r") is None
    assert overture_row_to_place(_row(operating_status="permanently_closed"), release="r") is None
    assert overture_row_to_place(_row(name="  "), release="r") is None
    assert overture_row_to_place(_row(latitude=None), release="r") is None
    assert overture_row_to_place(_row(operating_status=None), release="r") is not None


def test_internal_duplicates_collapse_keeping_the_most_confident() -> None:
    rows = [
        _row(id="low", confidence=0.75),
        _row(id="high", confidence=0.99),
        _row(id="other", name="Clinica Lotto", latitude=45.60, phone="+390200000009"),
    ]

    places = overture_rows_to_places(rows, release="r")

    assert sorted(place.source_external_id for place in places) == ["high", "other"]
    assert all(place.confirmed_by == [] for place in places)


def test_manual_exclusions_are_respected() -> None:
    places = overture_rows_to_places(
        [_row(id="keep"), _row(id="drop", latitude=45.7)],
        release="r",
        excluded_source_ids=frozenset({"drop"}),
    )

    assert [place.source_external_id for place in places] == ["keep"]


def test_open_row_carries_provenance() -> None:
    place = overture_row_to_place(_row(), release="2026-09-23.1")
    assert place is not None

    row = place_to_open_row(place, imported_at="2026-10-04T00:00:00+00:00")

    assert row["source"] == "overture"
    assert row["source_id"] == "abc-1"
    assert row["license"] == "CDLA-Permissive-2.0"
    assert row["release"] == "2026-09-23.1"
    assert row["imported_at"] == "2026-10-04T00:00:00+00:00"
    assert "confirmed_by" not in row
