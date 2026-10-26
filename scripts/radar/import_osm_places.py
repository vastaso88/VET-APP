"""Imports pet-related places for one country from OpenStreetMap into Supabase.

    uv run --system-certs --with truststore python scripts/radar/import_osm_places.py --country DE

Countries and their regions (Italian regions, German Länder, US states, ...)
are those of packages/core/domain/geo/countries.py; `--list-regions` prints
them. Asks the public Overpass servers for one region at a time (dog parks,
veterinarians, shops, groomers, boarding, trainers, sitters, breeders) and
replaces the content of `radar_places_osm` for that country. With the
country complete the API answers from our database and no longer calls
Overpass while a user waits. OSM data stays in its own table: it is never
merged into another. Only the rows of the country being imported are ever
replaced or deleted.

The public servers are slow and often busy, so the import is built to be
run several times:

- every region downloaded is kept under `.local/radar/osm/` (ignored by
  git) and reused for 24 hours (`--cache-hours` for a country whose regions
  take days, such as the United States), so a new run only fetches what is
  missing;
- the main server is waited for when it says it is busy (its status page
  tells for how long), the mirrors are a second chance, and a region that
  fails as a whole is fetched one category at a time;
- `--max-seconds` stops the run cleanly before an outer time limit (exit
  code 3): when it prints "riprendi", launch the same command again;
- nothing is written to Supabase until every region is present;
- politeness toward the public servers (Overpass usage policy): one
  request at a time, `--pause-seconds` between regions, a User-Agent that
  names the app, and the cache above so nothing is asked twice. A region
  that answers with no element at all is treated as a wrong area code, not
  as an empty region (`--allow-empty` for a region that really is).

`--with truststore` is only needed where an antivirus intercepts HTTPS
(see scripts/radar/common.py); it is harmless elsewhere.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from collections import Counter
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib import error, parse, request

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
from packages.core.domain.radar_places.models import OSM_SOURCE_NAME, RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    OSM_SELECTORS,
    build_overpass_area_query,
    map_osm_element,
)

# Same servers the backend uses (packages/shared/config/settings.py).
MAIN_SERVER = "https://overpass-api.de/api/interpreter"
MAIN_STATUS_URL = "https://overpass-api.de/api/status"
MIRROR_SERVERS = (
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
)
MAIN_SERVER_ATTEMPTS = 3
BUSY_WAIT_SECONDS = 20
MIRROR_TIMEOUT_SECONDS = 45
USER_AGENT = "VET-APP/1.0 (+https://vet-app-psi-nine.vercel.app; import periodico)"
CACHE_DIR = ROOT_DIR / ".local" / "radar" / "osm"
DEFAULT_CACHE_HOURS = 24
QUERY_TIMEOUT_SECONDS = 90
# Margin between the query's own timeout and the HTTP one, and the least
# time worth starting a request with.
HTTP_MARGIN_SECONDS = 15
MIN_REQUEST_SECONDS = 20
DEFAULT_PAUSE_SECONDS = 5
DEFAULT_MAX_SECONDS = 480
EXIT_RESUME = 3


class OutOfTimeError(Exception):
    """The run's time budget is over: stop cleanly and resume later."""


class Fetcher:
    """Runs Overpass queries inside one overall time budget.

    What a morning of failed runs taught: the main server is the only one
    that answers reliably, but it gives each address two slots and makes a
    client wait after a heavy query (429) or when it is busy (504). So the
    main server is asked first and waited for, using its own status page
    to know for how long; the mirrors are a second chance with a short
    timeout, and one that times out is not asked again in this run."""

    def __init__(self, max_seconds: float, pause_seconds: float = DEFAULT_PAUSE_SECONDS) -> None:
        self._deadline = time.monotonic() + max_seconds
        self._pause_seconds = pause_seconds
        self._dead_mirrors: set[str] = set()

    def remaining(self) -> float:
        return self._deadline - time.monotonic()

    def pause(self) -> None:
        if self.remaining() > self._pause_seconds + MIN_REQUEST_SECONDS:
            time.sleep(self._pause_seconds)

    def elements(self, query: str) -> list[dict[str, Any]] | None:
        """Elements of `query`, or None when no server would serve it now."""
        body = parse.urlencode({"data": query}).encode("utf-8")
        for attempt in range(MAIN_SERVER_ATTEMPTS):
            if attempt:
                self._sleep(BUSY_WAIT_SECONDS)
            self._wait_for_slot()
            result = self._request(MAIN_SERVER, body, QUERY_TIMEOUT_SECONDS + HTTP_MARGIN_SECONDS)
            if result is not None:
                return result
        for mirror in MIRROR_SERVERS:
            if mirror in self._dead_mirrors:
                continue
            result = self._request(mirror, body, MIRROR_TIMEOUT_SECONDS)
            if result is not None:
                return result
        return None

    def _sleep(self, seconds: float) -> None:
        if self.remaining() < seconds + MIN_REQUEST_SECONDS:
            raise OutOfTimeError
        time.sleep(seconds)

    def _wait_for_slot(self) -> None:
        """Waits until the main server says this address has a free slot.
        Best-effort: if the status page cannot be read, just go ahead."""
        try:
            with request.urlopen(
                request.Request(MAIN_STATUS_URL, headers={"User-Agent": USER_AGENT}), timeout=15
            ) as response:
                status = response.read().decode("utf-8", errors="replace")
        except (error.URLError, TimeoutError, OSError):
            return
        if "slots available now" in status:
            return
        waits = [int(value) for value in re.findall(r"in (\d+) seconds", status)]
        if waits:
            wait = min(waits) + 1
            print(f"    server occupato per questo indirizzo: attendo {wait} s", flush=True)
            self._sleep(wait)

    def _request(self, server: str, body: bytes, timeout: float) -> list[dict[str, Any]] | None:
        if self.remaining() < MIN_REQUEST_SECONDS:
            raise OutOfTimeError
        host = parse.urlsplit(server).netloc
        http_request = request.Request(
            server, data=body, headers={"User-Agent": USER_AGENT}, method="POST"
        )
        try:
            with request.urlopen(http_request, timeout=min(timeout, self.remaining())) as response:
                payload = json.load(response)
        except error.HTTPError as exc:
            print(f"    {host}: HTTP {exc.code}", flush=True)
            return None
        except (error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            print(f"    {host}: {str(exc)[:60]}", flush=True)
            if server != MAIN_SERVER:
                self._dead_mirrors.add(server)
            return None
        # A query that ran out of time answers 200 with a remark and
        # partial or no data.
        if payload.get("remark"):
            print(f"    {host}: {str(payload['remark'])[:60]}", flush=True)
            return None
        return [item for item in payload.get("elements", []) if isinstance(item, dict)]


def _selector_query(code: str, selector: str) -> str:
    return (
        f'[out:json][timeout:{QUERY_TIMEOUT_SECONDS}];\narea["ISO3166-2"="{code}"]->.a;\n'
        f"nwr(area.a){selector};\nout center tags qt;"
    )


def _cache_path(code: str, *, partial: bool = False) -> Path:
    return CACHE_DIR / f"{code}{'.partial' if partial else ''}.json"


def load_cached_region(
    code: str, *, max_age: timedelta = timedelta(hours=DEFAULT_CACHE_HOURS)
) -> list[dict[str, Any]] | None:
    path = _cache_path(code)
    if not path.exists():
        return None
    saved = json.loads(path.read_text(encoding="utf-8"))
    fetched_at = datetime.fromisoformat(saved["fetched_at"])
    if datetime.now(UTC) - fetched_at > max_age:
        return None
    return list(saved["elements"])


def fetch_region(code: str, fetcher: Fetcher) -> list[dict[str, Any]] | None:
    """Elements of one region, saved to the local cache when complete.
    None when the servers would not serve it now (whatever was obtained is
    kept, per category, for the next run)."""
    elements = fetcher.elements(
        build_overpass_area_query(iso_3166_2=code, timeout_seconds=QUERY_TIMEOUT_SECONDS)
    )
    if elements is None:
        # Too heavy as one query: one category at a time is nine light
        # queries instead of one that keeps timing out.
        print("    regione intera rifiutata: provo una categoria alla volta", flush=True)
        partial_path = _cache_path(code, partial=True)
        by_selector: dict[str, list[dict[str, Any]]] = (
            json.loads(partial_path.read_text(encoding="utf-8")) if partial_path.exists() else {}
        )
        try:
            for selector in OSM_SELECTORS:
                if selector in by_selector:
                    continue
                fetcher.pause()
                part = fetcher.elements(_selector_query(code, selector))
                if part is None:
                    return None
                by_selector[selector] = part
        finally:
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            partial_path.write_text(json.dumps(by_selector), encoding="utf-8")
        elements = [item for part in by_selector.values() for item in part]
        partial_path.unlink(missing_ok=True)

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    _cache_path(code).write_text(
        json.dumps({"fetched_at": now_iso(), "elements": elements}), encoding="utf-8"
    )
    return elements


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


def print_regions(country: RadarCountry) -> None:
    print(f"{country.flag} {country.name} ({country.code}): {len(country.regions)} regioni")
    for region in country.regions:
        print(f"  {region.code}  {region.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--country", default="IT", help="ISO code of the country (default IT)")
    parser.add_argument(
        "--regions", nargs="*", help="ISO 3166-2 codes to import (default: all), e.g. IT-25"
    )
    parser.add_argument("--list-regions", action="store_true", help="print the regions and exit")
    parser.add_argument(
        "--max-seconds",
        type=float,
        default=DEFAULT_MAX_SECONDS,
        help=f"stop cleanly after this long and resume later (default {DEFAULT_MAX_SECONDS})",
    )
    parser.add_argument(
        "--pause-seconds",
        type=float,
        default=DEFAULT_PAUSE_SECONDS,
        help=f"wait between two regions (default {DEFAULT_PAUSE_SECONDS})",
    )
    parser.add_argument(
        "--cache-hours",
        type=float,
        default=DEFAULT_CACHE_HOURS,
        help=f"reuse a downloaded region for this long (default {DEFAULT_CACHE_HOURS})",
    )
    parser.add_argument("--refresh", action="store_true", help="ignore the local cache")
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="accept regions that come back without any element",
    )
    parser.add_argument("--dry-run", action="store_true", help="download and count, write nothing")
    args = parser.parse_args()

    country = parse_country(args.country)
    if args.list_regions:
        print_regions(country)
        return 0
    names = {region.code: region.name for region in country.regions}
    codes = args.regions or list(names)
    unknown = [code for code in codes if code not in names]
    if unknown:
        parser.error(f"regioni sconosciute per {country.code}: {', '.join(unknown)}")
    whole_country = set(codes) == set(names)
    max_age = timedelta(hours=args.cache_hours)

    fetcher = Fetcher(args.max_seconds, args.pause_seconds)
    regions: dict[str, list[dict[str, Any]]] = {}
    missing: list[str] = []
    out_of_time = False
    for code in codes:
        cached = None if args.refresh else load_cached_region(code, max_age=max_age)
        if cached is not None and (cached or args.allow_empty):
            regions[code] = cached
            print(f"{names[code]} ({code}): {len(cached)} elementi, già scaricata")
            continue
        if out_of_time:
            missing.append(code)
            continue
        print(f"{names[code]} ({code})...", flush=True)
        started = time.monotonic()
        try:
            elements = fetch_region(code, fetcher)
        except OutOfTimeError:
            out_of_time = True
            missing.append(code)
            continue
        if elements is None:
            print("    non disponibile ora: riprovo al prossimo lancio")
            missing.append(code)
        elif not elements and not args.allow_empty:
            # An area code that matches nothing answers 200 and no element.
            print(
                f"    nessun elemento: il codice area {code} potrebbe essere sbagliato "
                "(se la regione è davvero vuota, rilancia con --allow-empty)"
            )
            missing.append(code)
        else:
            regions[code] = elements
            print(f"  {len(elements)} elementi in {time.monotonic() - started:.0f} s")
        fetcher.pause()

    if missing:
        listed = ", ".join(names[code] for code in missing)
        print(
            f"\nMancano {len(missing)} regioni su {len(codes)}: {listed}.\n"
            "Nulla è stato scritto. Riprendi rilanciando lo stesso comando: "
            "le regioni già scaricate non vengono richieste di nuovo."
        )
        return EXIT_RESUME

    fetched_at = datetime.now(UTC)
    places: dict[str, RadarPlace] = {}
    for elements in regions.values():
        for element in elements:
            place = map_osm_element(
                element,
                owner_id="",
                coverage_key="catalog",
                fetched_at=fetched_at,
                country_code=country.code,
            )
            # Border features can come back for two regions: keyed by id.
            if place is not None:
                places[place.source_external_id] = place

    print(f"\n{len(places)} luoghi in totale da {len(regions)} regioni ({country.code})")
    for place_type, count in Counter(place.place_type for place in places.values()).most_common():
        print(f"  {place_type}: {count}")
    if args.dry_run:
        print("Dry run: nessuna scrittura.")
        return 0
    if not places:
        print("Nessun luogo trovato: lascio il database com'è.", file=sys.stderr)
        return 1

    client = build_client()
    excluded = load_excluded_ids(client, OSM_SOURCE_NAME)
    imported_at = now_iso()
    rows = [
        place_to_osm_row(place, imported_at=imported_at, country=country.code)
        for place in places.values()
        if place.source_external_id not in excluded
    ]
    upsert_rows(client, "radar_places_osm", rows)
    if not whole_country:
        save_country_coverage(client, country.code, {"osm_regions": codes})
        print("Import parziale: righe aggiornate, copertura del paese NON dichiarata.")
        return 0

    # Only a complete run may delete what it did not see and declare the
    # country covered: from then on the API stops calling Overpass for it.
    delete_rows_not_imported_at(client, "radar_places_osm", imported_at, country=country.code)
    save_country_coverage(
        client,
        country.code,
        {
            "osm_complete_at": imported_at,
            "osm_release": imported_at[:10],
            "osm_place_count": len(rows),
            "osm_regions": codes,
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
