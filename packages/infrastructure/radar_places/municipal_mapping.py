"""Dog parks published by Italian municipalities as open data.

Only datasets whose reuse license was checked on the publisher's own page
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
    attribution="Comune di Bologna — Open Data",
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
    attribution="Città di Torino — aperTO",
    dataset_url="https://aperto.comune.torino.it/dataset/aree-cani",
    download_url="https://risorse.comune.torino.it/opendata/geodata/verde/aree_cani_geo.csv",
    file_format="csv",
    to_place=torino_row_to_place,
)

MUNICIPAL_DATASETS: tuple[MunicipalDataset, ...] = (BOLOGNA, TORINO)


def municipal_records_to_places(
    dataset: MunicipalDataset, records: Iterable[Mapping[str, Any]], *, release: str
) -> list[RadarPlace]:
    places = (dataset.to_place(record, release=release) for record in records)
    unique = {place.id: place for place in places if place is not None}
    return list(unique.values())
