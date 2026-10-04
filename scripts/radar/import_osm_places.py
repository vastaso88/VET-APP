"""Imports pet-related places for Italy from OpenStreetMap into Supabase.

    uv run python scripts/radar/import_osm_places.py

Asks the public Overpass API for one Italian region at a time (dog parks,
veterinarians, shops, groomers, boarding, trainers, sitters, breeders) and
replaces the content of `radar_places_osm`. With this table filled the
API answers from our database and no longer calls Overpass while a user
waits. OSM data stays in its own table: it is never merged into another.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from datetime import UTC, datetime
from typing import Any
from urllib import error, parse, request

from common import (  # type: ignore[import-not-found]
    ITALY_BOUNDS,
    build_client,
    delete_rows_not_imported_at,
    load_excluded_ids,
    now_iso,
    save_source,
    upsert_rows,
)

from packages.core.domain.radar_places.models import OSM_SOURCE_NAME, RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    build_overpass_area_query,
    map_osm_element,
)

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
USER_AGENT = "VET-APP/1.0 (+https://vet-app-psi-nine.vercel.app; import periodico)"
QUERY_TIMEOUT_SECONDS = 180
PAUSE_BETWEEN_REGIONS_SECONDS = 15
RETRY_WAITS_SECONDS = (30, 60, 120, 240)

# ISO 3166-2 codes of the twenty Italian regions.
ITALIAN_REGIONS = {
    "IT-21": "Piemonte",
    "IT-23": "Valle d'Aosta",
    "IT-25": "Lombardia",
    "IT-32": "Trentino-Alto Adige",
    "IT-34": "Veneto",
    "IT-36": "Friuli-Venezia Giulia",
    "IT-42": "Liguria",
    "IT-45": "Emilia-Romagna",
    "IT-52": "Toscana",
    "IT-55": "Umbria",
    "IT-57": "Marche",
    "IT-62": "Lazio",
    "IT-65": "Abruzzo",
    "IT-67": "Molise",
    "IT-72": "Campania",
    "IT-75": "Puglia",
    "IT-77": "Basilicata",
    "IT-78": "Calabria",
    "IT-82": "Sicilia",
    "IT-88": "Sardegna",
}


def fetch_region(code: str) -> list[dict[str, Any]]:
    """Elements of one region. Retries on the errors a busy public server
    answers with; a region that keeps failing aborts the whole run, so a
    half-imported country is never marked as complete."""
    body = parse.urlencode(
        {"data": build_overpass_area_query(iso_3166_2=code, timeout_seconds=QUERY_TIMEOUT_SECONDS)}
    ).encode("utf-8")
    last_error = ""
    for wait in (0, *RETRY_WAITS_SECONDS):
        if wait:
            print(f"    riprovo tra {wait} s ({last_error})", flush=True)
            time.sleep(wait)
        http_request = request.Request(
            OVERPASS_URL, data=body, headers={"User-Agent": USER_AGENT}, method="POST"
        )
        try:
            with request.urlopen(http_request, timeout=QUERY_TIMEOUT_SECONDS + 30) as response:
                payload = json.load(response)
        except (error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = str(exc)[:80]
            continue
        # A query that ran out of time answers 200 with a remark and no data.
        if payload.get("remark"):
            last_error = str(payload["remark"])[:80]
            continue
        return [item for item in payload.get("elements", []) if isinstance(item, dict)]
    raise RuntimeError(f"Overpass non ha risposto per {code}: {last_error}")


def place_to_osm_row(place: RadarPlace, *, imported_at: str) -> dict[str, Any]:
    """Row for the `radar_places_osm` table."""
    return {
        "id": f"{OSM_SOURCE_NAME}|{place.source_external_id}",
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
    parser.add_argument(
        "--regions", nargs="*", help="ISO codes to import (default: all of Italy), e.g. IT-25"
    )
    parser.add_argument("--dry-run", action="store_true", help="count only, write nothing")
    args = parser.parse_args()

    codes = args.regions or list(ITALIAN_REGIONS)
    unknown = [code for code in codes if code not in ITALIAN_REGIONS]
    if unknown:
        parser.error(f"regioni sconosciute: {', '.join(unknown)}")
    whole_country = set(codes) == set(ITALIAN_REGIONS)

    client = None if args.dry_run else build_client()
    excluded = load_excluded_ids(client, OSM_SOURCE_NAME) if client else frozenset()

    imported_at = now_iso()
    fetched_at = datetime.now(UTC)
    places: dict[str, RadarPlace] = {}
    for index, code in enumerate(codes):
        if index:
            time.sleep(PAUSE_BETWEEN_REGIONS_SECONDS)
        print(f"{ITALIAN_REGIONS[code]} ({code})...", flush=True)
        started = time.monotonic()
        elements = fetch_region(code)
        for element in elements:
            place = map_osm_element(
                element, owner_id="", coverage_key="catalog", fetched_at=fetched_at
            )
            # Border features can come back for two regions: keyed by id.
            if place is not None and place.source_external_id not in excluded:
                places[place.source_external_id] = place
        print(f"  {len(elements)} elementi in {time.monotonic() - started:.0f} s")

    print(f"{len(places)} luoghi in totale")
    for place_type, count in Counter(place.place_type for place in places.values()).most_common():
        print(f"  {place_type}: {count}")
    if client is None:
        print("Dry run: nessuna scrittura.")
        return 0
    if not places:
        print("Nessun luogo trovato: lascio il database com'è.", file=sys.stderr)
        return 1

    rows = [place_to_osm_row(place, imported_at=imported_at) for place in places.values()]
    upsert_rows(client, "radar_places_osm", rows)
    if not whole_country:
        print("Import parziale: righe aggiornate, copertura nazionale NON dichiarata.")
        return 0

    # Only a complete run may delete what it did not see and declare the
    # country covered: from then on the API stops calling Overpass for it.
    delete_rows_not_imported_at(client, "radar_places_osm", imported_at)
    save_source(
        client,
        {
            "source": OSM_SOURCE_NAME,
            "release": imported_at[:10],
            "license": "ODbL-1.0",
            "attribution": "© OpenStreetMap contributors",
            "url": "https://www.openstreetmap.org/copyright",
            "place_count": len(rows),
            "imported_at": imported_at,
            **ITALY_BOUNDS,
        },
    )
    print(f"Fatto: {len(rows)} luoghi in radar_places_osm, Italia dichiarata coperta.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
