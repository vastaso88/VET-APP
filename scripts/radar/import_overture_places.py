"""Imports pet-related places for one country from Overture Maps into Supabase.

    uv run --system-certs --with duckdb --with truststore python \\
        scripts/radar/import_overture_places.py --country GB

(`--system-certs` and `--with truststore` matter only where an antivirus
intercepts HTTPS: the first lets uv download the packages, the second lets
the script reach Supabase. See scripts/radar/common.py.)

Reads the public Overture release on S3 with DuckDB (no account needed),
keeps veterinarians, groomers, pet shops, boarding, sitters, trainers and
breeders that Overture is confident about and that are not closed, and
replaces the content of `radar_places_open` for that country (the places of
other countries and of other sources are never touched). Use --dry-run to
see the numbers without touching the database.

What was downloaded is kept under `.local/radar/overture/` (ignored by git)
and reused for 24 hours, so a failed write does not mean downloading the
country again. `--list-categories` prints the pet-looking categories a
country has in the release, to check that the mapping in
overture_mapping.py misses none; it writes nothing.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.request import urlopen

from common import (  # type: ignore[import-not-found]
    ROOT_DIR,
    build_client,
    delete_rows_not_imported_at,
    legacy_bounds_for,
    load_excluded_ids,
    now_iso,
    parse_country,
    save_country_coverage,
    save_source,
    sum_country_counts,
    upsert_rows,
)

from packages.core.domain.geo.countries import RadarCountry  # noqa: E402
from packages.core.domain.radar_places.models import OVERTURE_SOURCE_NAME  # noqa: E402
from packages.infrastructure.radar_places.overture_mapping import (  # noqa: E402
    DEFAULT_MIN_CONFIDENCE,
    OVERTURE_DEFAULT_LICENSE,
    build_overture_query,
    overture_rows_to_places,
    place_to_open_row,
)

STAC_CATALOG_URL = "https://stac.overturemaps.org/catalog.json"
LICENSE_DIR = ROOT_DIR / "docs" / "licenses"
CACHE_DIR = ROOT_DIR / ".local" / "radar" / "overture"
DEFAULT_CACHE_HOURS = 24
ATTRIBUTION = "© Overture Maps Foundation — Places"


def latest_release() -> str:
    with urlopen(STAC_CATALOG_URL, timeout=30) as response:
        return str(json.load(response)["latest"])


def _connect() -> Any:
    import duckdb

    connection = duckdb.connect()
    connection.execute("INSTALL httpfs; LOAD httpfs; SET s3_region='us-west-2';")
    return connection


def fetch_rows(release: str, country: RadarCountry) -> list[dict[str, Any]]:
    cursor = _connect().execute(build_overture_query(release, country))
    columns = [description[0] for description in cursor.description]
    return [dict(zip(columns, row, strict=True)) for row in cursor.fetchall()]


def list_categories(release: str, country: RadarCountry) -> list[tuple[str, int]]:
    """Categories of the country whose name looks pet-related, with their
    counts: the check that the category mapping is complete for a country
    nobody has looked at yet."""
    inside = " OR ".join(
        f"(bbox.xmin BETWEEN {box.min_longitude} AND {box.max_longitude} "
        f"AND bbox.ymin BETWEEN {box.min_latitude} AND {box.max_latitude})"
        for box in country.bounds
    )
    cursor = _connect().execute(
        f"""
        SELECT taxonomy.primary AS category, count(*) AS places
        FROM read_parquet(
            's3://overturemaps-us-west-2/release/{release}/theme=places/type=place/*',
            hive_partitioning = 1
        )
        WHERE ({inside})
          AND addresses[1].country = '{country.code}'
          AND regexp_matches(taxonomy.primary, 'pet|vet|animal|dog|cat_|kennel|groom|horse')
        GROUP BY 1 ORDER BY 2 DESC
        """
    )
    return [(str(name), int(count)) for name, count in cursor.fetchall()]


def load_cached_rows(release: str, country: RadarCountry, max_age: timedelta) -> Any:
    path = CACHE_DIR / f"{release}_{country.code}.json"
    if not path.exists():
        return None
    saved = json.loads(path.read_text(encoding="utf-8"))
    if datetime.now(UTC) - datetime.fromisoformat(saved["fetched_at"]) > max_age:
        return None
    return list(saved["rows"])


def save_cached_rows(release: str, country: RadarCountry, rows: list[dict[str, Any]]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    (CACHE_DIR / f"{release}_{country.code}.json").write_text(
        json.dumps({"fetched_at": now_iso(), "rows": rows}, default=str), encoding="utf-8"
    )


def manifest_path(country: RadarCountry) -> Path:
    # Italy keeps the file name it has always had.
    suffix = "" if country.code == "IT" else f"_{country.code}"
    return LICENSE_DIR / f"overture_places_release{suffix}.md"


def write_license_manifest(
    country: RadarCountry, release: str, imported_at: str, licenses: Counter[str]
) -> None:
    """Records which release was imported for the country and under which
    licenses, next to the license texts kept in docs/licenses/."""
    lines = [
        f"# Overture Maps Places: release importata ({country.name})",
        "",
        f"- Paese: {country.code}",
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
    path = manifest_path(country)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--release", help="Overture release (default: the latest)")
    parser.add_argument("--country", default="IT", help="ISO code of the country (default IT)")
    parser.add_argument("--min-confidence", type=float, default=DEFAULT_MIN_CONFIDENCE)
    parser.add_argument(
        "--cache-hours",
        type=float,
        default=DEFAULT_CACHE_HOURS,
        help=f"reuse the downloaded country for this long (default {DEFAULT_CACHE_HOURS})",
    )
    parser.add_argument("--refresh", action="store_true", help="ignore the local cache")
    parser.add_argument(
        "--list-categories", action="store_true", help="print pet-looking categories and exit"
    )
    parser.add_argument("--dry-run", action="store_true", help="count only, write nothing")
    parser.add_argument("--output", type=Path, help="also save the places as JSON (inspection)")
    args = parser.parse_args()

    country = parse_country(args.country)
    release = args.release or latest_release()
    if args.list_categories:
        print(f"Overture release {release}, {country.name}: categorie simili a pet/veterinari")
        for name, count in list_categories(release, country):
            print(f"  {name}: {count}")
        return 0

    rows = (
        None
        if args.refresh
        else load_cached_rows(release, country, timedelta(hours=args.cache_hours))
    )
    if rows is None:
        print(f"Overture release {release}, {country.name}: scarico i luoghi...", flush=True)
        started = time.monotonic()
        rows = fetch_rows(release, country)
        save_cached_rows(release, country, rows)
        print(f"  {len(rows)} righe delle categorie pet in {time.monotonic() - started:.0f} s")
    else:
        print(f"Overture release {release}, {country.name}: {len(rows)} righe già scaricate")

    client = None if args.dry_run else build_client()
    excluded = load_excluded_ids(client, OVERTURE_SOURCE_NAME) if client else frozenset()
    places = overture_rows_to_places(
        rows, release=release, min_confidence=args.min_confidence, excluded_source_ids=excluded
    )
    print(f"  {len(places)} luoghi dopo soglia di confidenza, chiusi, esclusioni e doppioni")
    for place_type, count in Counter(place.place_type for place in places).most_common():
        print(f"    {place_type}: {count}")

    imported_at = now_iso()
    open_rows = [
        place_to_open_row(place, imported_at=imported_at, country=country.code) for place in places
    ]
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
        client, "radar_places_open", imported_at, country=country.code, source=OVERTURE_SOURCE_NAME
    )
    save_country_coverage(
        client,
        country.code,
        {
            "overture_release": release,
            "overture_imported_at": imported_at,
            "overture_place_count": len(open_rows),
        },
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
            "place_count": sum_country_counts(client, "overture_place_count"),
            "imported_at": imported_at,
            **legacy_bounds_for(country),
        },
    )
    write_license_manifest(country, release, imported_at, licenses)
    print(f"Fatto: {len(open_rows)} luoghi in radar_places_open ({country.name}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
