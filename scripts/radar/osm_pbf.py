"""OpenStreetMap pet places of one country from a Geofabrik extract (.osm.pbf).

    uv run --system-certs --extra radar-import python scripts/radar/osm_pbf.py \\
        --country AU --pbf-dir E:/tmp/radar_paesi/pbf --download
    uv run --extra radar-import python scripts/radar/osm_pbf.py \\
        --country AU --pbf-dir E:/tmp/radar_paesi/pbf

TRIAL (2026-11-26): it only downloads and counts, it writes nothing to
Supabase. The permitted OSM path while public Overpass servers are not used
(docs/maps/COUNTRIES.md §2): Geofabrik's robots.txt and technical page
allow programs (checked 2026-11-26, notes in .local/radar/NOTE.md).

- `--download` fetches the country's `-latest.osm.pbf` once (skipped when
  the file is already there, `--refresh` to fetch it again): one request,
  User-Agent `QuokkaImport/1.0`, written to `.local/radar/requests.log`,
  at least 10 s after the last request to the host, and a 403/429 stops the
  host for good, like the other importers (request_log.py). The file goes
  to `--pbf-dir`, which must be outside the repository (it is GBs).
- Without `--download` it reads the file with pyosmium (the `radar-import`
  optional dependencies in pyproject.toml, never installed with the API):
  objects carrying one of the tag keys the Overpass selectors use are
  turned into Overpass-like elements (nodes with lat/lon, ways and
  multipolygons with the centre of their bounding box, as `out center`
  gives) and mapped by the same `map_osm_element` as import_osm_places.py,
  so the categories are exactly the same. Time and peak memory are printed;
  the elements are saved to `.local/radar/osm_pbf/<CC>.json`.
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib import error, request

from common import ROOT_DIR, now_iso, parse_country  # type: ignore[import-not-found]
from request_log import (  # type: ignore[import-not-found]
    LOG_NAME,
    STOP_STATUSES,
    HostStoppedError,
    HostTurns,
    log_request,
)

from packages.core.domain.radar_places.models import RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    map_osm_element,
)

USER_AGENT = "QuokkaImport/1.0 (+https://quokkapet.net; import periodico)"
GEOFABRIK = "https://download.geofabrik.de"
GEOFABRIK_HOST = "download.geofabrik.de"
# Country -> extract path. The United Kingdom includes Northern Ireland,
# like the radar's GB (GB-NIR); Geofabrik's "great-britain" does not.
EXTRACTS = {
    "IT": "europe/italy",
    "DE": "europe/germany",
    "FR": "europe/france",
    "ES": "europe/spain",
    "GB": "europe/united-kingdom",
    "AU": "australia-oceania/australia",
}
# Every key an Overpass selector of import_osm_places.py starts from; the
# exact values are checked by map_osm_element, as for Overpass answers.
SELECTOR_KEYS = ("amenity", "shop", "office", "craft", "leisure", "club")
LOCAL_DIR = ROOT_DIR / ".local" / "radar"
CHUNK_BYTES = 1 << 20


def extract_url(code: str) -> str:
    return f"{GEOFABRIK}/{EXTRACTS[code]}-latest.osm.pbf"


def pbf_path(pbf_dir: Path, code: str) -> Path:
    return pbf_dir / f"{EXTRACTS[code].rsplit('/', 1)[1]}-latest.osm.pbf"


def download(code: str, pbf_dir: Path, *, refresh: bool) -> Path:
    """The country's extract, downloaded once (one logged request)."""
    target = pbf_path(pbf_dir, code)
    if target.exists() and not refresh:
        print(f"{target.name}: già scaricato ({target.stat().st_size / 1e6:.0f} MB)")
        return target
    turns = HostTurns(LOCAL_DIR)
    if reason := turns.stopped_reason(GEOFABRIK_HOST):
        raise HostStoppedError(GEOFABRIK_HOST, reason)
    time.sleep(turns.seconds_to_wait(GEOFABRIK_HOST))
    url = extract_url(code)
    pbf_dir.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(".part")
    started, begun = now_iso(), time.monotonic()
    outcome: object = "errore"
    size = 0
    try:
        req = request.Request(url, headers={"User-Agent": USER_AGENT})
        with request.urlopen(req, timeout=60) as response, partial.open("wb") as handle:
            outcome = response.status
            while chunk := response.read(CHUNK_BYTES):
                handle.write(chunk)
                size += len(chunk)
        partial.replace(target)
    except error.HTTPError as exc:
        outcome = exc.code
        raise
    except (error.URLError, TimeoutError, OSError) as exc:
        outcome = f"errore {type(exc).__name__}"
        raise
    finally:
        turns.record(GEOFABRIK_HOST)
        log_request(
            LOCAL_DIR / LOG_NAME,
            user_agent=USER_AGENT,
            url=url,
            outcome=f"{outcome} ({size / 1e6:.0f} MB)" if outcome == 200 else outcome,
            started=started,
        )
        if isinstance(outcome, int) and outcome in STOP_STATUSES:
            turns.stop(GEOFABRIK_HOST, f"HTTP {outcome}")
            raise HostStoppedError(GEOFABRIK_HOST, f"HTTP {outcome}")
    print(f"{target.name}: {size / 1e6:.0f} MB in {time.monotonic() - begun:.0f} s")
    return target


class PeakMemory:
    """Samples the process's resident memory twice a second (psutil when
    installed; otherwise nothing is measured)."""

    def __init__(self) -> None:
        self.peak_bytes = 0
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def __enter__(self) -> PeakMemory:
        self._thread.start()
        return self

    def __exit__(self, *args: object) -> None:
        self._stop.set()
        self._thread.join()

    def _run(self) -> None:
        try:
            import psutil
        except ModuleNotFoundError:
            return
        process = psutil.Process()
        while not self._stop.wait(0.5):
            self.peak_bytes = max(self.peak_bytes, int(process.memory_info().rss))


def _tags(obj: Any) -> dict[str, str]:
    return {tag.k: tag.v for tag in obj.tags}


def _center(points: list[tuple[float, float]]) -> dict[str, float] | None:
    """Centre of the bounding box, as Overpass `out center` computes it."""
    if not points:
        return None
    lats = [lat for lat, _ in points]
    lons = [lon for _, lon in points]
    return {"lat": (min(lats) + max(lats)) / 2, "lon": (min(lons) + max(lons)) / 2}


def read_elements(path: Path, *, index: str) -> list[dict[str, Any]]:
    """Overpass-like elements of every object with a selector key."""
    import osmium

    processor = (
        osmium.FileProcessor(str(path))
        .with_locations(index)
        .with_areas(osmium.filter.KeyFilter(*SELECTOR_KEYS))
        .with_filter(osmium.filter.KeyFilter(*SELECTOR_KEYS))
    )
    elements: list[dict[str, Any]] = []
    for obj in processor:
        if obj.is_node():
            if obj.location.valid():
                elements.append(
                    {
                        "type": "node",
                        "id": obj.id,
                        "lat": obj.location.lat,
                        "lon": obj.location.lon,
                        "tags": _tags(obj),
                    }
                )
        elif obj.is_way():
            points = [(n.lat, n.lon) for n in obj.nodes if n.location.valid()]
            if center := _center(points):
                elements.append({"type": "way", "id": obj.id, "center": center, "tags": _tags(obj)})
        elif obj.is_area() and not obj.from_way():
            # Multipolygon relations (closed ways already came as ways).
            points = [
                (n.lat, n.lon) for ring in obj.outer_rings() for n in ring if n.location.valid()
            ]
            if center := _center(points):
                elements.append(
                    {"type": "relation", "id": obj.orig_id(), "center": center, "tags": _tags(obj)}
                )
    return elements


def map_elements(
    elements: list[dict[str, Any]], country_code: str
) -> tuple[dict[str, RadarPlace], list[dict[str, Any]]]:
    """Places by OSM id, with the same mapping as Overpass answers, and the
    elements that became a place (the only ones worth keeping on disk: a
    country has about a million objects with an `amenity` or `shop` key)."""
    fetched_at = datetime.now(UTC)
    places: dict[str, RadarPlace] = {}
    kept: list[dict[str, Any]] = []
    for element in elements:
        place = map_osm_element(
            element,
            owner_id="",
            coverage_key="catalog",
            fetched_at=fetched_at,
            country_code=country_code,
        )
        if place is not None:
            places[place.source_external_id] = place
            kept.append(element)
    return places, kept


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--country", required=True, help=f"one of {', '.join(EXTRACTS)}")
    parser.add_argument("--pbf-dir", type=Path, required=True, help="where the .pbf files live")
    parser.add_argument("--download", action="store_true", help="download the extract and stop")
    parser.add_argument("--refresh", action="store_true", help="download again even if present")
    parser.add_argument(
        "--index",
        default="flex_mem",
        help="pyosmium node-location storage (flex_mem; sparse_file_array,<file> for big files)",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        help="request log and output folder (default .local/radar)",
    )
    args = parser.parse_args()

    country = parse_country(args.country)
    if country.code not in EXTRACTS:
        parser.error(f"nessun estratto Geofabrik configurato per {country.code}")
    if ROOT_DIR in args.pbf_dir.resolve().parents or args.pbf_dir.resolve() == ROOT_DIR:
        parser.error("--pbf-dir deve stare fuori dal repository")
    global LOCAL_DIR
    if args.cache_dir:
        LOCAL_DIR = args.cache_dir
    if args.download:
        try:
            download(country.code, args.pbf_dir, refresh=args.refresh)
        except HostStoppedError as exc:
            print(f"Host fermato: {exc.host} ({exc.reason}). Avvisare l'Orchestratore.")
            return 4
        return 0

    path = pbf_path(args.pbf_dir, country.code)
    if not path.exists():
        parser.error(f"{path} non c'è: lancia prima con --download")
    started = time.monotonic()
    with PeakMemory() as memory:
        elements = read_elements(path, index=args.index)
    seconds = time.monotonic() - started
    places, kept = map_elements(elements, country.code)
    output = LOCAL_DIR / "osm_pbf" / f"{country.code}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps({"fetched_at": now_iso(), "source": path.name, "elements": kept}),
        encoding="utf-8",
    )
    print(f"{path.name}: {path.stat().st_size / 1e6:.0f} MB letti in {seconds:.0f} s")
    if memory.peak_bytes:
        print(f"  memoria massima: {memory.peak_bytes / 1e6:.0f} MB")
    print(f"  {len(elements)} oggetti con una chiave dei selettori")
    print(f"  {len(places)} luoghi ({country.code}) dopo la stessa mappatura di Overpass")
    for place_type, count in Counter(p.place_type for p in places.values()).most_common():
        print(f"    {place_type}: {count}")
    print(f"  elementi salvati in {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
