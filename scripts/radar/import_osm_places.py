"""Imports pet-related places for one country from OpenStreetMap into Supabase.

    uv run --system-certs --extra radar-import --with truststore \\
        python scripts/radar/import_osm_places.py --country DE --pbf-dir E:/tmp/radar_paesi/pbf

The data come from the country's Geofabrik extract (osm_pbf.py): it is
downloaded once (one logged request, `QuokkaImport/1.0`) into `--pbf-dir`,
which must be outside the repository, and read with pyosmium. Public
Overpass servers are no longer used (docs/maps/COUNTRIES.md §2).

The places (dog parks, veterinarians, shops, groomers, boarding, trainers,
sitters, breeders, shelters, associations: the same mapping as the Overpass
answers had) replace the content of `radar_places_osm` for that country,
with its `country` column. OSM data stays in its own table: it is never
merged into another. Only the rows of the country being imported are ever
replaced or deleted.

- A country counts as complete only when its whole extract was read: the
  elements are saved to `.local/radar/osm_pbf/<CC>.json` with
  `"complete": true` only after the read ends, and only such a file is
  imported (reused for `--cache-hours`, default 24; `--refresh` reads the
  extract again). Then rows the import did not see are deleted and the
  country is declared covered (`radar_country_coverage`).
- The extract is read in three sequential passes without a node-location
  index (osm_pbf.read_elements), so memory stays small for every country.
- `--delete-pbf` removes the extract once its places are saved (CI disk).
- `--dry-run` reads and counts, writes nothing; without it the production
  project is refused unless `--allow-production` (common.py).

`--with truststore` is only needed where an antivirus intercepts HTTPS
(see scripts/radar/common.py); it is harmless elsewhere.
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

from common import (  # type: ignore[import-not-found]
    ROOT_DIR,
    add_allow_production,
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
from osm_pbf import (  # type: ignore[import-not-found]
    EXTRACTS,
    PeakMemory,
    download,
    map_elements,
    outside_repository,
    read_elements,
)
from request_log import HostStoppedError  # type: ignore[import-not-found]

from packages.core.domain.geo.countries import RadarCountry  # noqa: E402
from packages.core.domain.radar_places.models import OSM_SOURCE_NAME, RadarPlace  # noqa: E402

LOCAL_DIR = ROOT_DIR / ".local" / "radar"
DEFAULT_CACHE_HOURS = 24
EXIT_STOPPED = 4


def elements_path(code: str) -> Path:
    return LOCAL_DIR / "osm_pbf" / f"{code}.json"


def load_complete_elements(code: str, *, max_age: timedelta) -> dict[str, Any] | None:
    """The saved elements of a whole extract, or None (missing, too old, or
    not marked complete: a partial read never makes a country complete)."""
    path = elements_path(code)
    if not path.exists():
        return None
    saved = json.loads(path.read_text(encoding="utf-8"))
    if saved.get("complete") is not True:
        return None
    if datetime.now(UTC) - datetime.fromisoformat(saved["fetched_at"]) > max_age:
        return None
    return dict(saved)


def read_extract(country: RadarCountry, pbf_dir: Path, *, delete_pbf: bool) -> dict[str, Any]:
    """Downloads (if needed) and reads the whole extract, then saves the
    elements that became places, marked complete."""
    path = download(country.code, pbf_dir, local_dir=LOCAL_DIR)
    size_mb = path.stat().st_size / 1e6
    print(f"Leggo {path.name} ({size_mb:.0f} MB)...", flush=True)
    started = time.monotonic()
    with PeakMemory() as memory:
        elements, looked_at = read_elements(path)
    seconds = time.monotonic() - started
    places, kept = map_elements(elements, country)
    record = {
        "fetched_at": now_iso(),
        "complete": True,
        "source": path.name,
        "source_mb": round(size_mb),
        "read_seconds": round(seconds),
        "peak_memory_mb": round(memory.peak_bytes / 1e6) if memory.peak_bytes else None,
        "objects_with_keys": looked_at,
        "elements": kept,
    }
    target = elements_path(country.code)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(record), encoding="utf-8")
    print(f"  letto in {seconds:.0f} s, {looked_at} oggetti con una chiave dei selettori")
    if memory.peak_bytes:
        print(f"  memoria massima: {memory.peak_bytes / 1e6:.0f} MB")
    print(f"  {len(places)} luoghi, salvati in {target}")
    if delete_pbf:
        path.unlink()
        print(f"  {path.name} cancellato")
    return record


def place_to_osm_row(place: RadarPlace, *, imported_at: str, country: str) -> dict[str, Any]:
    """Row for the `radar_places_osm` table."""
    return {
        "id": f"{OSM_SOURCE_NAME}|{place.source_external_id}",
        "country": country,
        "place_type": place.place_type,
        "subtype": place.subtype,
        "name": place.name,
        "summary": place.summary,
        "opening_hours": place.opening_hours,
        "species": place.species,
        "details": place.details,
        "city": place.city,
        "address_label": place.address_label,
        "latitude": place.latitude,
        "longitude": place.longitude,
        "source_external_id": place.source_external_id,
        "source_url": place.source_url,
        "phone": place.phone,
        "website_url": place.website_url,
        "imported_at": imported_at,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--country", default="IT", help="ISO code of the country (default IT)")
    parser.add_argument(
        "--pbf-dir", type=Path, help="folder of the .osm.pbf extracts (outside the repository)"
    )
    parser.add_argument(
        "--cache-hours",
        type=float,
        default=DEFAULT_CACHE_HOURS,
        help=f"reuse the elements of a read extract this long (default {DEFAULT_CACHE_HOURS})",
    )
    parser.add_argument("--refresh", action="store_true", help="read the extract again")
    parser.add_argument(
        "--delete-pbf", action="store_true", help="delete the extract once its places are saved"
    )
    parser.add_argument(
        "--cache-dir", type=Path, help="folder for saved elements and request log (.local/radar)"
    )
    add_allow_production(parser)
    parser.add_argument("--dry-run", action="store_true", help="read and count, write nothing")
    args = parser.parse_args()

    country = parse_country(args.country)
    if country.code not in EXTRACTS:
        parser.error(f"nessun estratto Geofabrik configurato per {country.code}")
    global LOCAL_DIR
    if args.cache_dir:
        LOCAL_DIR = args.cache_dir

    record = (
        None
        if args.refresh
        else load_complete_elements(country.code, max_age=timedelta(hours=args.cache_hours))
    )
    if record is None:
        if args.pbf_dir is None:
            parser.error("serve --pbf-dir: nessun estratto già letto e completo per questo paese")
        if not outside_repository(args.pbf_dir):
            parser.error("--pbf-dir deve stare fuori dal repository")
        try:
            record = read_extract(country, args.pbf_dir, delete_pbf=args.delete_pbf)
        except HostStoppedError as exc:
            print(f"Host fermato: {exc.host} ({exc.reason}). Avvisare l'Orchestratore.")
            return EXIT_STOPPED
    else:
        print(f"{country.name}: estratto {record['source']} già letto per intero")

    # Same mapping and dedup (by OSM id) as the saved elements were made with.
    places, _ = map_elements(list(record["elements"]), country)
    print(f"\n{len(places)} luoghi in totale ({country.code}, estratto completo)")
    for place_type, count in Counter(place.place_type for place in places.values()).most_common():
        print(f"  {place_type}: {count}")
    if args.dry_run:
        print("Dry run: nessuna scrittura.")
        return 0
    if not places:
        print("Nessun luogo trovato: lascio il database com'è.", file=sys.stderr)
        return 1

    client = build_client(allow_production=args.allow_production)
    excluded = load_excluded_ids(client, OSM_SOURCE_NAME)
    imported_at = now_iso()
    rows = [
        place_to_osm_row(place, imported_at=imported_at, country=country.code)
        for place in places.values()
        if place.source_external_id not in excluded
    ]
    upsert_rows(client, "radar_places_osm", rows)
    # The whole extract was read: delete what it did not see and declare
    # the country covered (all its regions, as the coverage rows expect).
    delete_rows_not_imported_at(client, "radar_places_osm", imported_at, country=country.code)
    save_country_coverage(
        client,
        country.code,
        {
            "osm_complete_at": imported_at,
            "osm_release": imported_at[:10],
            "osm_place_count": len(rows),
            "osm_regions": list(country.region_codes),
        },
    )
    save_source(
        client,
        {
            "source": OSM_SOURCE_NAME,
            "release": imported_at[:10],
            "license": "ODbL-1.0",
            "attribution": "© OpenStreetMap contributors",
            "url": "https://www.openstreetmap.org/copyright",
            "place_count": sum_country_counts(client, "osm_place_count"),
            "imported_at": imported_at,
            **legacy_bounds_for(country),
        },
    )
    print(f"Fatto: {len(rows)} luoghi in radar_places_osm, {country.name} dichiarato coperto.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
