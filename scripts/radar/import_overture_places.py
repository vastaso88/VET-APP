"""Imports pet-related places for Italy from Overture Maps into Supabase.

    uv run --with duckdb --with truststore python scripts/radar/import_overture_places.py

(`--with truststore` matters only where an antivirus intercepts HTTPS: see
scripts/radar/common.py. On such a machine uv itself may also need
`--system-certs` to download the two packages.)

Reads the public Overture release on S3 with DuckDB (no account needed),
keeps veterinarians, groomers, pet shops, boarding, sitters, trainers and
breeders that Overture is confident about and that are not closed, and
replaces the content of `radar_places_open`. Use --dry-run to see the
numbers without touching the database.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any
from urllib.request import urlopen

from common import (  # type: ignore[import-not-found]
    ITALY_BOUNDS,
    ROOT_DIR,
    build_client,
    delete_rows_not_imported_at,
    load_excluded_ids,
    now_iso,
    save_source,
    upsert_rows,
)

from packages.core.domain.radar_places.models import OVERTURE_SOURCE_NAME  # noqa: E402
from packages.infrastructure.radar_places.overture_mapping import (  # noqa: E402
    DEFAULT_MIN_CONFIDENCE,
    OVERTURE_CATEGORIES,
    OVERTURE_DEFAULT_LICENSE,
    overture_rows_to_places,
    place_to_open_row,
)

STAC_CATALOG_URL = "https://stac.overturemaps.org/catalog.json"
LICENSE_MANIFEST = ROOT_DIR / "docs" / "licenses" / "overture_places_release.md"
ATTRIBUTION = "© Overture Maps Foundation — Places"


def latest_release() -> str:
    with urlopen(STAC_CATALOG_URL, timeout=30) as response:
        return str(json.load(response)["latest"])


def fetch_rows(release: str, country: str) -> list[dict[str, Any]]:
    import duckdb

    categories = ", ".join(f"'{name}'" for name in sorted(OVERTURE_CATEGORIES))
    connection = duckdb.connect()
    connection.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")
    # The bbox predicate lets DuckDB skip most of the planet's files; the
    # country check then drops the neighbours inside the same rectangle.
    query = f"""
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
        WHERE bbox.xmin BETWEEN {ITALY_BOUNDS["min_longitude"]} AND {ITALY_BOUNDS["max_longitude"]}
          AND bbox.ymin BETWEEN {ITALY_BOUNDS["min_latitude"]} AND {ITALY_BOUNDS["max_latitude"]}
          AND taxonomy.primary IN ({categories})
          AND addresses[1].country = '{country}'
    """
    cursor = connection.execute(query)
    columns = [description[0] for description in cursor.description]
    return [dict(zip(columns, row, strict=True)) for row in cursor.fetchall()]


def write_license_manifest(release: str, imported_at: str, licenses: Counter[str]) -> None:
    """Records which release was imported and under which licenses, next
    to the license texts kept in docs/licenses/."""
    lines = [
        "# Overture Maps Places: release importata",
        "",
        f"- Release: `{release}`",
        f"- Importata il: {imported_at}",
        "- Fonte: https://docs.overturemaps.org/guides/places/",
        f"- Attribuzione mostrata nell'app: {ATTRIBUTION}",
        "",
        "## Licenze dei record importati",
        "",
        "| Licenza | Record |",
        "| --- | --- |",
        *[f"| {name} | {count} |" for name, count in licenses.most_common()],
        "",
        "Testo delle licenze: `docs/licenses/CDLA-Permissive-2.0.txt`.",
        "File generato da `scripts/radar/import_overture_places.py`: non modificarlo a mano.",
        "",
    ]
    LICENSE_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    LICENSE_MANIFEST.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--release", help="Overture release (default: the latest)")
    parser.add_argument("--country", default="IT")
    parser.add_argument("--min-confidence", type=float, default=DEFAULT_MIN_CONFIDENCE)
    parser.add_argument("--dry-run", action="store_true", help="count only, write nothing")
    parser.add_argument("--output", type=Path, help="also save the places as JSON (inspection)")
    args = parser.parse_args()

    release = args.release or latest_release()
    print(f"Overture release {release}, paese {args.country}: scarico i luoghi...", flush=True)
    started = time.monotonic()
    rows = fetch_rows(release, args.country)
    print(f"  {len(rows)} righe delle categorie pet in {time.monotonic() - started:.0f} s")

    client = None if args.dry_run else build_client()
    excluded = load_excluded_ids(client, OVERTURE_SOURCE_NAME) if client else frozenset()
    places = overture_rows_to_places(
        rows, release=release, min_confidence=args.min_confidence, excluded_source_ids=excluded
    )
    print(f"  {len(places)} luoghi dopo soglia di confidenza, chiusi, esclusioni e doppioni")
    for place_type, count in Counter(place.place_type for place in places).most_common():
        print(f"    {place_type}: {count}")

    imported_at = now_iso()
    open_rows = [place_to_open_row(place, imported_at=imported_at) for place in places]
    if args.output:
        args.output.write_text(json.dumps(open_rows, ensure_ascii=False), encoding="utf-8")
    if client is None:
        print("Dry run: nessuna scrittura.")
        return 0
    if not open_rows:
        print("Nessun luogo trovato: lascio il database com'è.", file=sys.stderr)
        return 1

    upsert_rows(client, "radar_places_open", open_rows)
    delete_rows_not_imported_at(
        client, "radar_places_open", imported_at, source=OVERTURE_SOURCE_NAME
    )
    licenses = Counter(str(place.license or OVERTURE_DEFAULT_LICENSE) for place in places)
    save_source(
        client,
        {
            "source": OVERTURE_SOURCE_NAME,
            "release": release,
            "license": OVERTURE_DEFAULT_LICENSE,
            "attribution": ATTRIBUTION,
            "url": "https://overturemaps.org",
            "place_count": len(open_rows),
            "imported_at": imported_at,
            **ITALY_BOUNDS,
        },
    )
    write_license_manifest(release, imported_at, licenses)
    print(f"Fatto: {len(open_rows)} luoghi in radar_places_open.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
