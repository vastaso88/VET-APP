"""Imports pet-related places for one country from OpenStreetMap into Supabase.

    uv run --system-certs --with truststore python scripts/radar/import_osm_places.py \
        --country DE --server <URL of a permitted Overpass server>

No public Overpass server is in use today (2026-11-26): there is no
default server, so without `--server` the script only works from the cache
(and says so). overpass-api.de is never contacted: its robots.txt forbids
/api/ to programs (packages/shared/config/external_hosts.py).

Countries and their regions (Italian regions, German Länder, US states, ...)
are those of packages/core/domain/geo/countries.py; `--list-regions` prints
them. Asks the Overpass server(s) given with `--server` for one region at a time (dog parks,
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
- the servers are asked in the order given, and a region that fails as a
  whole is fetched one category at a time;
- `--max-seconds` stops the run cleanly before an outer time limit (exit
  code 3): when it prints "riprendi", launch the same command again;
- nothing is written to Supabase until every region is present;
- politeness toward the public servers (Overpass usage policy and the
  project rule on external sites): one request at a time, at least
  `--pause-seconds` (10 s, never less) between two requests to the same
  server, also across reruns, a User-Agent that names the app, and the
  cache above so nothing is asked twice. Every request is written to
  `.local/radar/requests.log` (time, name, address, outcome: no content).
  A server that answers 403 or 429 is never asked again (it is listed in
  `.local/radar/host_fermati.json`) and the run stops (exit code 4); a
  forbidden host is refused before any request. A region
  that answers with no element at all is treated as a wrong area code, not
  as an empty region (`--allow-empty` for a region that really is).

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
from urllib import error, parse, request

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
from request_log import (  # type: ignore[import-not-found]
    LOG_NAME,
    MIN_GAP_SECONDS,
    STOP_STATUSES,
    HostStoppedError,
    HostTurns,
    log_request,
)

from packages.core.domain.geo.countries import RadarCountry  # noqa: E402
from packages.core.domain.radar_places.models import OSM_SOURCE_NAME, RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    OSM_SELECTORS,
    build_overpass_area_query,
    map_osm_element,
)
from packages.shared.config.external_hosts import forbidden_reason  # noqa: E402

USER_AGENT = "QuokkaImport/1.0 (+https://quokkapet.net; import periodico)"
LOCAL_DIR = ROOT_DIR / ".local" / "radar"
CACHE_DIR = LOCAL_DIR / "osm"
DEFAULT_CACHE_HOURS = 24
QUERY_TIMEOUT_SECONDS = 90
# Margin between the query's own timeout and the HTTP one, and the least
# time worth starting a request with.
HTTP_MARGIN_SECONDS = 15
MIN_REQUEST_SECONDS = 20
DEFAULT_PAUSE_SECONDS = MIN_GAP_SECONDS
DEFAULT_MAX_SECONDS = 480
EXIT_RESUME = 3
EXIT_STOPPED = 4
EXIT_NO_SERVER = 5


class OutOfTimeError(Exception):
    """The run's time budget is over: stop cleanly and resume later."""


class Fetcher:
    """Runs Overpass queries on the given servers, in order, inside one
    overall time budget.

    Every request waits for its turn on the host (at least `pause_seconds`,
    never under 10 s, since the last request there ended), is written to
    the request log, and a 403 or 429 stops the host for good
    (HostStoppedError): no retry, no other server "to get through". A
    forbidden host is refused before anything is sent."""

    def __init__(
        self,
        max_seconds: float,
        pause_seconds: float = DEFAULT_PAUSE_SECONDS,
        *,
        local_dir: Path | None = None,
        servers: tuple[str, ...] = (),
    ) -> None:
        self._deadline = time.monotonic() + max_seconds
        self._local_dir = local_dir or LOCAL_DIR
        self._turns = HostTurns(self._local_dir, pause_seconds)
        self._servers = servers

    def remaining(self) -> float:
        return self._deadline - time.monotonic()

    def elements(self, query: str) -> list[dict[str, Any]] | None:
        """Elements of `query`, or None when no server would serve it now."""
        body = parse.urlencode({"data": query}).encode("utf-8")
        for server in self._servers:
            result = self._request(server, body, QUERY_TIMEOUT_SECONDS + HTTP_MARGIN_SECONDS)
            if result is not None:
                return result
        return None

    def _sleep(self, seconds: float) -> None:
        if self.remaining() < seconds + MIN_REQUEST_SECONDS:
            raise OutOfTimeError
        time.sleep(seconds)

    def _take_turn(self, url: str) -> str:
        """Waits for the host's turn; refuses a stopped host. Returns the start time."""
        host = _host(url)
        if reason := self._turns.stopped_reason(host):
            raise HostStoppedError(host, reason)
        if self.remaining() < MIN_REQUEST_SECONDS:
            raise OutOfTimeError
        wait = self._turns.seconds_to_wait(host)
        if wait > 0:
            self._sleep(wait)
        return now_iso()

    def _done(self, url: str, started: str, outcome: object) -> None:
        """Logs a finished request and starts the host's gap; stops the host on 403/429."""
        host = _host(url)
        self._turns.record(host)
        log_request(
            self._local_dir / LOG_NAME,
            user_agent=USER_AGENT,
            url=url,
            outcome=outcome,
            started=started,
        )
        if isinstance(outcome, int) and outcome in STOP_STATUSES:
            self._turns.stop(host, f"HTTP {outcome}")
            print(f"    {host}: HTTP {outcome}, server fermato (nessuna riprova)", flush=True)
            raise HostStoppedError(host, f"HTTP {outcome}")

    def _request(self, server: str, body: bytes, timeout: float) -> list[dict[str, Any]] | None:
        started = self._take_turn(server)
        host = _host(server)
        http_request = request.Request(
            server, data=body, headers={"User-Agent": USER_AGENT}, method="POST"
        )
        try:
            with request.urlopen(http_request, timeout=min(timeout, self.remaining())) as response:
                code = response.status
                payload = json.load(response)
        except error.HTTPError as exc:
            self._done(server, started, exc.code)
            print(f"    {host}: HTTP {exc.code}", flush=True)
            return None
        except (error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            self._done(server, started, f"errore {type(exc).__name__}")
            print(f"    {host}: {str(exc)[:60]}", flush=True)
            return None
        # A query that ran out of time answers 200 with a remark and
        # partial or no data.
        if payload.get("remark"):
            self._done(server, started, f"{code} remark")
            print(f"    {host}: {str(payload['remark'])[:60]}", flush=True)
            return None
        self._done(server, started, code)
        return [item for item in payload.get("elements", []) if isinstance(item, dict)]


def _host(url: str) -> str:
    return parse.urlsplit(url).netloc


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
        help=(
            "least wait between two requests to the same server "
            f"(default and minimum {DEFAULT_PAUSE_SECONDS:.0f})"
        ),
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        help="folder for caches, request log and stopped servers (default .local/radar)",
    )
    parser.add_argument(
        "--server",
        action="append",
        default=[],
        metavar="URL",
        help="a permitted Overpass interpreter URL (repeatable; there is no default)",
    )
    add_allow_production(parser)
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
    global LOCAL_DIR, CACHE_DIR
    if args.cache_dir:
        LOCAL_DIR, CACHE_DIR = args.cache_dir, args.cache_dir / "osm"
    for server in args.server:
        if reason := forbidden_reason(server):
            parser.error(f"server non ammesso ({reason}): {server}")
    names = {region.code: region.name for region in country.regions}
    codes = args.regions or list(names)
    unknown = [code for code in codes if code not in names]
    if unknown:
        parser.error(f"regioni sconosciute per {country.code}: {', '.join(unknown)}")
    whole_country = set(codes) == set(names)
    max_age = timedelta(hours=args.cache_hours)

    fetcher = Fetcher(
        args.max_seconds,
        args.pause_seconds,
        local_dir=LOCAL_DIR,
        servers=tuple(args.server),
    )
    regions: dict[str, list[dict[str, Any]]] = {}
    missing: list[str] = []
    out_of_time = False
    stopped: HostStoppedError | None = None
    for code in codes:
        cached = None if args.refresh else load_cached_region(code, max_age=max_age)
        if cached is not None and (cached or args.allow_empty):
            regions[code] = cached
            print(f"{names[code]} ({code}): {len(cached)} elementi, già scaricata")
            continue
        if out_of_time or stopped or not args.server:
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
        except HostStoppedError as exc:
            stopped = exc
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

    if missing:
        listed = ", ".join(names[code] for code in missing)
        print(
            f"\nMancano {len(missing)} regioni su {len(codes)}: {listed}.\n"
            "Nulla è stato scritto. Riprendi rilanciando lo stesso comando: "
            "le regioni già scaricate non vengono richieste di nuovo."
        )
        if not args.server:
            print(
                "Nessun server Overpass indicato (--server): oggi nessun server pubblico è in "
                "uso, quindi le regioni mancanti non si possono scaricare."
            )
            return EXIT_NO_SERVER
        if stopped:
            print(
                f"Server fermato: {stopped.host} ({stopped.reason}). Non va richiesto di nuovo "
                "finché una persona non decide: avvisare l'Orchestratore."
            )
            return EXIT_STOPPED
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

    client = build_client(allow_production=args.allow_production)
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
