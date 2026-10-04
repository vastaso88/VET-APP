"""Lists candidate duplicate pairs between OpenStreetMap and Overture.

    uv run python scripts/radar/dedup_sample.py

For checking, by eye, what the dedup rules merge and what they keep apart
in one area. The output holds REAL business names and phone numbers, some
of sole practitioners: it is written under `.local/radar/`, which git
ignores, and must not be copied into the repository. The committed
summary is docs/features/radar_dedup_sample.md (aggregates only).

Inputs, also under `.local/radar/` by default:
- osm.json: the `elements` array of an Overpass answer for the area;
- overture.json: rows with id, name, cat, confidence, operating_status,
  lat, lon, addr, phone, web (as extracted with DuckDB from Overture).
"""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime
from pathlib import Path

from common import ROOT_DIR  # type: ignore[import-not-found]

from packages.core.domain.radar_places.dedup import (  # noqa: E402
    distance_meters,
    name_tokens,
    same_place,
)
from packages.core.domain.radar_places.models import RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    map_osm_element,
)
from packages.infrastructure.radar_places.overture_mapping import (  # noqa: E402
    overture_rows_to_places,
)

LOCAL_DIR = ROOT_DIR / ".local" / "radar"
RULE_LABELS = {
    "same_phone": "stesso telefono",
    "same_website": "stesso sito",
    "same_spot": "stesso punto",
    "near_same_name": "entro 120 m e nome compatibile",
    None: "nessuna",
}
PER_RULE = 7
MAX_CANDIDATE_METERS = 300


def load_osm(path: Path) -> list[RadarPlace]:
    now = datetime.now(UTC)
    places = (
        map_osm_element(element, owner_id="", coverage_key="catalog", fetched_at=now)
        for element in json.loads(path.read_text(encoding="utf-8"))
    )
    return [place for place in places if place is not None and place.place_type != "dog_park"]


def load_overture(path: Path) -> list[RadarPlace]:
    rows = [
        {
            "id": row["id"],
            "name": row["name"],
            "category": row["cat"],
            "confidence": row["confidence"],
            "operating_status": row["operating_status"],
            "latitude": row["lat"],
            "longitude": row["lon"],
            "address": row.get("addr"),
            "phone": row.get("phone"),
            "website": row.get("web"),
        }
        for row in json.loads(path.read_text(encoding="utf-8"))
    ]
    return overture_rows_to_places(rows, release="sample")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--osm", type=Path, default=LOCAL_DIR / "osm.json")
    parser.add_argument("--overture", type=Path, default=LOCAL_DIR / "overture.json")
    parser.add_argument("--output", type=Path, default=LOCAL_DIR / "radar_dedup_sample.md")
    args = parser.parse_args()

    osm, overture = load_osm(args.osm), load_overture(args.overture)
    pairs: list[tuple[str | None, float, RadarPlace, RadarPlace]] = []
    for candidate in overture:
        nearest = sorted(
            (
                (distance_meters(candidate, place), place)
                for place in osm
                if place.place_type == candidate.place_type
            ),
            key=lambda item: item[0],
        )[:3]
        pairs.extend(
            (same_place(place, candidate), meters, place, candidate)
            for meters, place in nearest
            if meters <= MAX_CANDIDATE_METERS
        )

    merged: dict[str, list[tuple[str | None, float, RadarPlace, RadarPlace]]] = {}
    for pair in pairs:
        if pair[0]:
            merged.setdefault(pair[0], []).append(pair)
    apart_close = sorted((pair for pair in pairs if not pair[0] and pair[1] <= 120), key=_meters)
    apart_named = sorted(
        (
            pair
            for pair in pairs
            if not pair[0]
            and pair[1] > 120
            and name_tokens(pair[2].name) & name_tokens(pair[3].name)
        ),
        key=_meters,
    )

    sample = [
        pair
        for rule in RULE_LABELS
        if rule
        # The farthest merges of each rule are the ones most at risk.
        for pair in sorted(merged.get(rule, []), key=_meters, reverse=True)[:PER_RULE]
    ]
    sample += apart_close + apart_named

    lines = [
        "# Campione di deduplica (DATI REALI: non committare)",
        "",
        f"OSM: {len(osm)} luoghi. Overture: {len(overture)} luoghi.",
        "",
        "| Regola | Coppie unite |",
        "| --- | --- |",
        *[f"| {RULE_LABELS[rule]} | {len(items)} |" for rule, items in merged.items()],
        f"| candidati entro 120 m lasciati separati | {len(apart_close)} |",
        "",
        "| # | Categoria | Esito | Regola | Distanza | OSM | Tel. OSM | Overture | Tel. Overture |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for number, (rule, meters, place, candidate) in enumerate(sample, 1):
        lines.append(
            f"| {number} | {place.place_type} | {'uniti' if rule else 'separati'} "
            f"| {RULE_LABELS[rule]} | {meters:.0f} m | {_cell(place.name)} | {_cell(place.phone)} "
            f"| {_cell(candidate.name)} | {_cell(candidate.phone)} |"
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(sample)} coppie scritte in {args.output} (cartella ignorata da git).")
    return 0


def _meters(pair: tuple[str | None, float, RadarPlace, RadarPlace]) -> float:
    return pair[1]


def _cell(text: str | None) -> str:
    return (text or "—").replace("|", "/")


if __name__ == "__main__":
    raise SystemExit(main())
