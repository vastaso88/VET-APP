"""OpenStreetMap pet places of one country from a Geofabrik extract (.osm.pbf).

Used by import_osm_places.py. Geofabrik's robots.txt and technical page
allow programs (checked 2026-11-26); public Overpass servers are not used.

- `download` fetches the country's `-latest.osm.pbf` once: one request,
  User-Agent `QuokkaImport/1.0`, written to `.local/radar/requests.log`, at
  least 10 s after the last request to the host, and a 403/429 stops the
  host for good, like the other importers (request_log.py).
- `read_elements` reads the file with pyosmium (the `radar-import` optional
  dependencies in pyproject.toml, never installed with the API): the pet
  places among the objects carrying one of the tag keys the old Overpass
  selectors used become Overpass-like elements (nodes with lat/lon; ways
  and relations with the centre of their bounding box, as Overpass
  `out center` gave), so the same `map_osm_element` turns them into places.
  Three sequential passes, no node-location index: memory stays small even
  for Germany or France.
"""

from __future__ import annotations

import threading
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib import error, request

from common import ROOT_DIR, now_iso  # type: ignore[import-not-found]
from request_log import (  # type: ignore[import-not-found]
    LOG_NAME,
    STOP_STATUSES,
    HostStoppedError,
    HostTurns,
    log_request,
)

from packages.core.domain.geo.countries import RadarCountry  # noqa: E402
from packages.core.domain.geo.models import Coordinates  # noqa: E402
from packages.core.domain.radar_places.models import RadarPlace  # noqa: E402
from packages.infrastructure.radar_places.overpass_places_source import (  # noqa: E402
    is_pet_place,
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
# Every tag key a pet place can be recognised by (map_osm_element checks
# the exact values, as it did for Overpass answers).
SELECTOR_KEYS = ("amenity", "shop", "office", "craft", "leisure", "club")
CHUNK_BYTES = 1 << 20


def extract_url(code: str) -> str:
    return f"{GEOFABRIK}/{EXTRACTS[code]}-latest.osm.pbf"


def pbf_path(pbf_dir: Path, code: str) -> Path:
    return pbf_dir / f"{EXTRACTS[code].rsplit('/', 1)[1]}-latest.osm.pbf"


def outside_repository(path: Path) -> bool:
    resolved = path.resolve()
    return resolved != ROOT_DIR and ROOT_DIR not in resolved.parents


def download(code: str, pbf_dir: Path, *, local_dir: Path) -> Path:
    """The country's extract, downloaded once (one logged request); an
    existing file is used as it is."""
    target = pbf_path(pbf_dir, code)
    if target.exists():
        print(f"{target.name}: già scaricato ({target.stat().st_size / 1e6:.0f} MB)")
        return target
    turns = HostTurns(local_dir)
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
        partial.unlink(missing_ok=True)
        turns.record(GEOFABRIK_HOST)
        log_request(
            local_dir / LOG_NAME,
            user_agent=USER_AGENT,
            url=url,
            outcome=f"{outcome} ({size / 1e6:.0f} MB)" if outcome == 200 else outcome,
            started=started,
        )
        if isinstance(outcome, int) and outcome in STOP_STATUSES:
            turns.stop(GEOFABRIK_HOST, f"HTTP {outcome}")
            raise HostStoppedError(GEOFABRIK_HOST, f"HTTP {outcome}")
    print(f"{target.name}: {size / 1e6:.0f} MB in {time.monotonic() - begun:.0f} s", flush=True)
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


def read_elements(path: Path) -> tuple[list[dict[str, Any]], int]:
    """Overpass-like elements of the pet places in the extract, and how many
    objects with a selector key were looked at. Raises if the file cannot
    be read to the end: a partial read never counts.

    No node-location index (it needs several GB for a big country): three
    sequential passes instead. 1) objects with a selector key whose tags
    describe a pet place: nodes are done, ways and relations keep their
    member ids; 2) the member ways of those relations; 3) only the nodes
    those ways and relations need, for the centre of their bounding box."""
    import osmium

    looked_at = 0
    elements: list[dict[str, Any]] = []
    ways: dict[int, tuple[dict[str, str], list[int]]] = {}
    relations: dict[int, tuple[dict[str, str], list[int], list[int]]] = {}
    tagged = osmium.FileProcessor(str(path)).with_filter(osmium.filter.KeyFilter(*SELECTOR_KEYS))
    for obj in tagged:
        looked_at += 1
        tags = _tags(obj)
        if not is_pet_place(tags):
            continue
        if isinstance(obj, osmium.osm.Node):
            if obj.location.valid():
                elements.append(
                    {
                        "type": "node",
                        "id": obj.id,
                        "lat": obj.location.lat,
                        "lon": obj.location.lon,
                        "tags": tags,
                    }
                )
        elif isinstance(obj, osmium.osm.Way):
            ways[obj.id] = (tags, [node.ref for node in obj.nodes])
        elif isinstance(obj, osmium.osm.Relation):
            members = list(obj.members)
            relations[obj.id] = (
                tags,
                [m.ref for m in members if m.type == "w"],
                [m.ref for m in members if m.type == "n"],
            )

    member_ways: dict[int, list[int]] = {}
    wanted_ways = {ref for _, way_refs, _ in relations.values() for ref in way_refs}
    if wanted_ways:
        for way in osmium.FileProcessor(str(path), osmium.osm.osm_entity_bits.WAY).with_filter(
            osmium.filter.IdFilter(wanted_ways)
        ):
            if isinstance(way, osmium.osm.Way):
                member_ways[way.id] = [node.ref for node in way.nodes]

    wanted_nodes = {ref for _, refs in ways.values() for ref in refs}
    for _, way_refs, node_refs in relations.values():
        wanted_nodes.update(node_refs)
        for ref in way_refs:
            wanted_nodes.update(member_ways.get(ref, ()))
    locations: dict[int, tuple[float, float]] = {}
    if wanted_nodes:
        for node in osmium.FileProcessor(str(path), osmium.osm.osm_entity_bits.NODE).with_filter(
            osmium.filter.IdFilter(wanted_nodes)
        ):
            if isinstance(node, osmium.osm.Node) and node.location.valid():
                locations[node.id] = (node.location.lat, node.location.lon)

    for way_id, (tags, refs) in ways.items():
        if center := _center([locations[ref] for ref in refs if ref in locations]):
            elements.append({"type": "way", "id": way_id, "center": center, "tags": tags})
    for relation_id, (tags, way_refs, node_refs) in relations.items():
        refs = [*node_refs, *(ref for way in way_refs for ref in member_ways.get(way, ()))]
        if center := _center([locations[ref] for ref in refs if ref in locations]):
            elements.append({"type": "relation", "id": relation_id, "center": center, "tags": tags})
    return elements, looked_at


def map_elements(
    elements: list[dict[str, Any]], country: RadarCountry
) -> tuple[dict[str, RadarPlace], list[dict[str, Any]]]:
    """Places by OSM id, with the same mapping as Overpass answers, and the
    elements that became a place (the only ones worth keeping on disk: a
    country has about a million objects with an `amenity` or `shop` key).
    A place outside the country's rectangles is dropped: extracts carry
    overseas territories (France) or border spill the radar does not cover."""
    fetched_at = datetime.now(UTC)
    places: dict[str, RadarPlace] = {}
    kept: list[dict[str, Any]] = []
    for element in elements:
        place = map_osm_element(
            element,
            owner_id="",
            coverage_key="catalog",
            fetched_at=fetched_at,
            country_code=country.code,
        )
        if place is None or not country.contains(
            Coordinates(latitude=place.latitude, longitude=place.longitude)
        ):
            continue
        places[place.source_external_id] = place
        kept.append(element)
    return places, kept
