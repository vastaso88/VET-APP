"""Builds the town tables of the curated events (scripts/events/gazetteer/<COUNTRY>.tsv).

    uv run --system-certs --with duckdb --with truststore python \\
        scripts/events/build_gazetteer.py --country IT [--release 2026-11-18.0]

Reads the localities of one country from the public Overture Maps release ("divisions" theme)
with DuckDB, exactly as the radar reads Overture places: same host, same name
(QuokkaImport/1.0), no retries, 120 s timeout, every request in `.local/radar/requests.log`
(scripts/radar/import_overture_places.py, scripts/radar/request_log.py). What was downloaded is
kept in `.local/events/gazetteer/` (git-ignored) and reused; `--refresh` downloads again.

The table keeps municipalities (and towns), coordinates to 3 decimals, the region as the app
writes it and, in Italy, the province abbreviation. Licence ODbL 1.0 (data from OpenStreetMap):
the attribution is in the table's header. `import_curated.py` reads the tables to give each
event without coordinates those of its town (packages/infrastructure/events/gazetteer.py).
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

RADAR_DIR = Path(__file__).resolve().parents[1] / "radar"
sys.path.insert(0, str(RADAR_DIR))

import import_overture_places as overture  # type: ignore[import-not-found]  # noqa: E402
from common import ROOT_DIR, now_iso, parse_country  # type: ignore[import-not-found]  # noqa: E402
from request_log import HostStoppedError  # type: ignore[import-not-found]  # noqa: E402

from packages.infrastructure.events.gazetteer import write_table  # noqa: E402
from packages.infrastructure.events.overture_divisions import (  # noqa: E402
    ATTRIBUTION_LINES,
    build_localities_query,
    missing_app_regions,
    rows_to_towns,
)

DEFAULT_RELEASE = "2026-11-18.0"
CACHE_DIR = ROOT_DIR / ".local" / "events" / "gazetteer"
DEFAULT_OUT = Path(__file__).resolve().parent / "gazetteer"
# Above this a table is too big for the public repository.
SIZE_WARNING_BYTES = 1_000_000


def _fetch(release: str, country: Any, refresh: bool) -> list[dict[str, Any]]:
    path = CACHE_DIR / f"overture_{release}_{country.code}.json"
    if path.exists() and not refresh:
        rows: list[dict[str, Any]] = json.loads(path.read_text(encoding="utf-8"))["rows"]
        print(f"{country.code}: {len(rows)} località già scaricate ({path.name})")
        return rows
    print(f"{country.code}: scarico le località di Overture {release}...", flush=True)
    started = time.monotonic()
    columns, found = overture._run_logged(build_localities_query(release, country))
    rows = [dict(zip(columns, row, strict=True)) for row in found]
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"fetched_at": now_iso(), "release": release, "rows": rows}, default=str),
        encoding="utf-8",
    )
    print(f"  {len(rows)} righe in {time.monotonic() - started:.0f} s")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--country", required=True, help="ISO code (IT, GB, US, AU, DE, FR, ES)")
    parser.add_argument("--release", default=DEFAULT_RELEASE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--refresh", action="store_true", help="ignore what was downloaded")
    args = parser.parse_args()

    country = parse_country(args.country)
    missing = missing_app_regions(country)
    if missing:
        print(f"ERRORE  regioni dell'app senza codice ISO: {', '.join(missing)}", file=sys.stderr)
        return 1
    try:
        rows = _fetch(args.release, country, args.refresh)
    except HostStoppedError as exc:
        print(
            f"Host fermato: {exc.host} ({exc.reason}). Non va richiesto di nuovo finché una "
            "persona non decide: avvisare l'Orchestratore.",
            file=sys.stderr,
        )
        return 4

    result = rows_to_towns(rows, country)
    header = [*ATTRIBUTION_LINES, f"Release Overture: {args.release}."]
    header.append(
        "Licenze dei record: "
        + ", ".join(f"{name} {count}" for name, count in result.licenses.most_common())
        + "."
    )
    args.out.mkdir(parents=True, exist_ok=True)
    path = args.out / f"{country.code}.tsv"
    write_table(path, result.towns, header_comments=header)
    size = path.stat().st_size
    seats = sum(1 for town in result.towns if town.seat)
    print(
        f"{country.code}: {len(result.towns)} luoghi ({seats} comuni/municipalità), "
        f"{size / 1024:.0f} KB; senza regione: {result.without_region}"
    )
    if result.unknown_counties:
        print(f"  province non riconosciute ({sum(result.unknown_counties.values())} luoghi):")
        for name, count in result.unknown_counties.most_common():
            print(f"    {name}: {count}")
    if size > SIZE_WARNING_BYTES:
        print("ATTENZIONE  oltre 1 MB: troppo grande per il repository pubblico.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
