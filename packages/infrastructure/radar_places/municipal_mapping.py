"""Dog parks published by Italian municipalities as open data.

Only datasets whose reuse license was checked on the publisher's own page
(CC BY 4.0, or CC BY 3.0 IT: attribution, commercial reuse, no share-alike)
are imported (docs/features/radar_places_overpass.md has the survey).
Each municipality is its own source, with its own attribution: the card
of a place names the city that published it.
"""

from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from packages.core.domain.radar_places.models import RadarPlace

_DEFAULT_NAME = "Area cani"


def _text(value: Any) -> str | None:
    text = value.strip() if isinstance(value, str) else ""
    return text or None


def _number(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _dog_park(
    *,
    source: str,
    source_id: str,
    name: str | None,
    latitude: float | None,
    longitude: float | None,
    address_label: str | None,
    city: str,
    license: str,
    release: str,
) -> RadarPlace | None:
    if latitude is None or longitude is None or not source_id:
        return None
    return RadarPlace(
        id=f"{source}|{source_id}",
        coverage_key="catalog",
        place_type="dog_park",
        subtype="municipal_dog_park",
        name=name or _DEFAULT_NAME,
        latitude=latitude,
        longitude=longitude,
        address_label=address_label,
        city=city,
        species=["dog"],
        source_name=source,
        source_external_id=source_id,
        confidence=1.0,
        license=license,
        release=release,
    )


def bologna_record_to_place(record: Mapping[str, Any], *, release: str) -> RadarPlace | None:
    """One record of Bologna's `sgambatura_cani` dataset (Opendatasoft)."""
    point = record.get("geo_point_2d")
    point = point if isinstance(point, Mapping) else {}
    zone = _text(record.get("nomezona"))
    return _dog_park(
        source=BOLOGNA.source,
        source_id=str(record.get("id") or "").strip(),
        name=_text(record.get("nome")),
        latitude=_number(point.get("lat")),
        longitude=_number(point.get("lon")),
        address_label=f"{zone.title()}, Bologna" if zone else None,
        city="Bologna",
        license=BOLOGNA.license,
        release=release,
    )


def torino_row_to_place(row: Mapping[str, Any], *, release: str) -> RadarPlace | None:
    """One row of Torino's `aree_cani_geo.csv`. The file has no id column:
    the position, which is what identifies a park, stands in for one."""
    latitude, longitude = _number(row.get("latitudine")), _number(row.get("longitudine"))
    source_id = f"{latitude:.6f},{longitude:.6f}" if latitude and longitude else ""
    address = _text(row.get("indirizzo"))
    return _dog_park(
        source=TORINO.source,
        source_id=source_id,
        name=_text(row.get("nome")),
        latitude=latitude,
        longitude=longitude,
        address_label=f"{address}, Torino" if address else None,
        city="Torino",
        license=TORINO.license,
        release=release,
    )


def _ring_centre(geometry: Any) -> tuple[float | None, float | None]:
    """Centre of the first outline of a GeoJSON Polygon/MultiPolygon: the
    mean of its vertices, close enough to place a marker on a small park."""
    coordinates = geometry.get("coordinates") if isinstance(geometry, Mapping) else None
    ring: Any = coordinates
    while isinstance(ring, list) and ring and isinstance(ring[0], list) and ring[0]:
        if isinstance(ring[0][0], (int, float)):
            break
        ring = ring[0]
    points = [
        point
        for point in (ring if isinstance(ring, list) else [])
        if isinstance(point, list) and len(point) >= 2 and _number(point[0]) is not None
    ]
    if not points:
        return None, None
    longitude = sum(float(point[0]) for point in points) / len(points)
    latitude = sum(float(point[1]) for point in points) / len(points)
    return latitude, longitude


def milano_feature_to_place(feature: Mapping[str, Any], *, release: str) -> RadarPlace | None:
    """One GeoJSON feature of Milano's dog-area dataset. Only the data is
    used (outline, id, street): the portal's icons and theme graphics are
    under a different license and are not touched."""
    properties = feature.get("properties")
    properties = properties if isinstance(properties, Mapping) else {}
    latitude, longitude = _ring_centre(feature.get("geometry"))
    # The street column is spelled with an accented letter ("località").
    street = next(
        (_text(value) for key, value in properties.items() if str(key).startswith("localit")),
        None,
    )
    return _dog_park(
        source=MILANO.source,
        source_id=str(properties.get("id_area") or "").strip(),
        name=f"Area cani {street}" if street else None,
        latitude=latitude,
        longitude=longitude,
        address_label=f"{street}, Milano" if street else None,
        city="Milano",
        license=MILANO.license,
        release=release,
    )


@dataclass(frozen=True)
class MunicipalDataset:
    source: str
    city: str
    license: str
    attribution: str
    dataset_url: str
    download_url: str
    file_format: str
    to_place: Callable[..., RadarPlace | None]


BOLOGNA = MunicipalDataset(
    source="comune_bologna",
    city="Bologna",
    license="CC-BY-4.0",
    attribution=(
        "Fonte: Comune di Bologna, Aree sgambatura cani (opendata.comune.bologna.it), "
        "licenza CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)."
    ),
    dataset_url="https://opendata.comune.bologna.it/explore/dataset/sgambatura_cani/",
    download_url=(
        "https://opendata.comune.bologna.it/api/explore/v2.1/catalog/datasets/"
        "sgambatura_cani/exports/json"
    ),
    file_format="json",
    to_place=bologna_record_to_place,
)

TORINO = MunicipalDataset(
    source="comune_torino",
    city="Torino",
    license="CC-BY-4.0",
    attribution=(
        "Fonte: Comune di Torino, Aree Cani (aperto.comune.torino.it), licenza CC BY 4.0 "
        "(https://creativecommons.org/licenses/by/4.0/). Dati del 2019."
    ),
    dataset_url="https://aperto.comune.torino.it/dataset/aree-cani",
    download_url="https://risorse.comune.torino.it/opendata/geodata/verde/aree_cani_geo.csv",
    file_format="csv",
    to_place=torino_row_to_place,
)

MILANO = MunicipalDataset(
    source="comune_milano",
    city="Milano",
    license="CC-BY-4.0",
    attribution=(
        "Fonte: Comune di Milano, Territorio: localizzazione delle aree cani "
        "(dati.comune.milano.it), licenza CC BY 4.0 "
        "(https://creativecommons.org/licenses/by/4.0/). Contiene elaborazioni di dati "
        "CC BY 3.0 da dati.gov.it."
    ),
    dataset_url=("https://dati.comune.milano.it/dataset/ds52_infogeo_aree_cani_localizzazione"),
    download_url=(
        "https://dati.comune.milano.it/dataset/7efe1ac1-7a5f-4e33-b7ab-c24438bc9fb1/resource/"
        "99011d87-d640-43a3-9f70-20e1825d7441/download/ds52_aree_fruizione_cani.geojson"
    ),
    file_format="geojson",
    to_place=milano_feature_to_place,
)

MUNICIPAL_DATASETS: tuple[MunicipalDataset, ...] = (BOLOGNA, TORINO, MILANO)


def municipal_records_to_places(
    dataset: MunicipalDataset, records: Iterable[Mapping[str, Any]], *, release: str
) -> list[RadarPlace]:
    places = (dataset.to_place(record, release=release) for record in records)
    unique = {place.id: place for place in places if place is not None}
    return list(unique.values())
