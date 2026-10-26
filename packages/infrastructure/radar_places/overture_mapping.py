"""Turning Overture Maps "places" rows into radar places.

Kept apart from scripts/radar/import_overture_places.py so the rules
(which categories count, what is trustworthy enough to show) are plain
functions with tests, independent of DuckDB and of the network.
"""

from collections.abc import Iterable, Mapping
from typing import Any

from packages.core.domain.geo.countries import RadarCountry
from packages.core.domain.radar_places.dedup import merge_radar_places
from packages.core.domain.radar_places.labels import (
    OTHER_KIND_NAME_HINTS,
    VETERINARY_NAME_HINTS,
    fold,
)
from packages.core.domain.radar_places.models import OVERTURE_SOURCE_NAME, RadarPlace

# Overture `taxonomy.primary` -> radar place type. Exact matches only: a
# substring match on "pet_store" also catches "carpet_store". Dog parks
# are left to OpenStreetMap, which knows ten times as many.
OVERTURE_CATEGORIES: dict[str, str] = {
    "veterinarian": "veterinary",
    "veterinary_care": "veterinary",
    "emergency_pet_hospital": "veterinary",
    "animal_hospital": "veterinary",
    "pet_groomer": "grooming",
    "pet_store": "shop",
    "aquatic_pet_store": "shop",
    "reptile_store": "shop",
    "pet_boarding": "hotel",
    "pet_sitting": "pet_sitting",
    "dog_walker": "pet_sitting",
    "dog_trainer": "school",
    "pet_training": "school",
    "pet_breeder": "breeder",
    "animal_shelter": "shelter",
    "pet_adoption": "shelter",
    "animal_rescue_service": "shelter",
}

# Below this Overture's own confidence the sample held mislabelled
# entries (a trade fair filed as a veterinarian, bare personal names).
DEFAULT_MIN_CONFIDENCE = 0.7

OVERTURE_DEFAULT_LICENSE = "CDLA-Permissive-2.0"


def place_type_for(category_type: str, name: str) -> str:
    """The radar type of an Overture place: its category's, unless the
    category says veterinarian and the name plainly says another kind of
    business (and nothing veterinary), in the language of any supported
    country (see radar_places/labels.py)."""
    if category_type != "veterinary":
        return category_type
    plain = fold(name)
    if VETERINARY_NAME_HINTS.search(plain):
        return category_type
    stated = [kind for kind, words in OTHER_KIND_NAME_HINTS.items() if words.search(plain)]
    # Two kinds in one name ("Toelettatura e pet shop") decide nothing.
    return stated[0] if len(stated) == 1 else category_type


def build_overture_query(release: str, country: RadarCountry) -> str:
    """DuckDB query for one country's pet places in an Overture release.
    The rectangles of the country let DuckDB skip most of the planet's
    files; the country code then drops the neighbours inside them."""
    categories = ", ".join(f"'{name}'" for name in sorted(OVERTURE_CATEGORIES))
    inside = " OR ".join(
        f"(bbox.xmin BETWEEN {box.min_longitude} AND {box.max_longitude} "
        f"AND bbox.ymin BETWEEN {box.min_latitude} AND {box.max_latitude})"
        for box in country.bounds
    )
    return f"""
        SELECT id,
               names.primary AS name,
               taxonomy.primary AS category,
               confidence,
               operating_status,
               bbox.xmin AS longitude,
               bbox.ymin AS latitude,
               addresses[1].freeform AS address,
               addresses[1].locality AS locality,
               phones[1] AS phone,
               websites[1] AS website,
               sources[1].license AS license
        FROM read_parquet(
            's3://overturemaps-us-west-2/release/{release}/theme=places/type=place/*',
            hive_partitioning = 1
        )
        WHERE ({inside})
          AND taxonomy.primary IN ({categories})
          AND addresses[1].country = '{country.code}'
    """


def _text(value: Any) -> str | None:
    text = value.strip() if isinstance(value, str) else ""
    return text or None


def overture_row_to_place(
    row: Mapping[str, Any], *, release: str, min_confidence: float = DEFAULT_MIN_CONFIDENCE
) -> RadarPlace | None:
    """None for anything not worth showing: unknown category, low
    confidence, closed, or without a name or position."""
    category_type = OVERTURE_CATEGORIES.get(str(row.get("category") or ""))
    name = _text(row.get("name"))
    place_type = place_type_for(category_type, name) if category_type and name else None
    latitude, longitude = row.get("latitude"), row.get("longitude")
    confidence = row.get("confidence")
    if (
        place_type is None
        or name is None
        or not isinstance(latitude, (int, float))
        or not isinstance(longitude, (int, float))
        or not isinstance(confidence, (int, float))
        or confidence < min_confidence
        or row.get("operating_status") in {"permanently_closed", "temporarily_closed"}
    ):
        return None

    source_id = str(row["id"])
    return RadarPlace(
        id=f"{OVERTURE_SOURCE_NAME}|{source_id}",
        coverage_key="catalog",
        place_type=place_type,
        subtype=str(row["category"]),
        name=name,
        latitude=float(latitude),
        longitude=float(longitude),
        address_label=_text(row.get("address")),
        city=_text(row.get("locality")),
        phone=_text(row.get("phone")),
        website_url=_text(row.get("website")),
        source_name=OVERTURE_SOURCE_NAME,
        source_external_id=source_id,
        confidence=float(confidence),
        license=_text(row.get("license")) or OVERTURE_DEFAULT_LICENSE,
        release=release,
    )


def overture_rows_to_places(
    rows: Iterable[Mapping[str, Any]],
    *,
    release: str,
    min_confidence: float = DEFAULT_MIN_CONFIDENCE,
    excluded_source_ids: frozenset[str] = frozenset(),
) -> list[RadarPlace]:
    """Usable places of an Overture extract: filtered, minus the manual
    exclusion list, with Overture's own duplicates collapsed (the dataset
    conflates several providers and repeats some businesses)."""
    places = [
        place
        for row in rows
        if str(row.get("id")) not in excluded_source_ids
        for place in [overture_row_to_place(row, release=release, min_confidence=min_confidence)]
        if place is not None
    ]
    # Highest confidence first, so that is the record kept for a duplicate.
    places.sort(key=lambda place: -(place.confidence or 0))
    merged = merge_radar_places([], places)
    return [place.model_copy(update={"confirmed_by": []}) for place in merged]


def place_to_open_row(
    place: RadarPlace, *, imported_at: str, country: str = "IT"
) -> dict[str, Any]:
    """Row for the `radar_places_open` table."""
    return {
        "id": place.id,
        "country": country,
        "source": place.source_name,
        "source_id": place.source_external_id,
        "place_type": place.place_type,
        "subtype": place.subtype,
        "name": place.name,
        "latitude": place.latitude,
        "longitude": place.longitude,
        "address_label": place.address_label,
        "city": place.city,
        "phone": place.phone,
        "website_url": place.website_url,
        "confidence": place.confidence,
        "license": place.license,
        "release": place.release,
        "imported_at": imported_at,
    }
