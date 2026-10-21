"""Prints the size/time estimate of importing each radar country, as the
table kept in docs/maps/COUNTRIES.md.

    uv run python scripts/radar/estimate_countries.py

Reads nothing from the network or the database: it only formats the
constants of packages/infrastructure/radar_places/country_estimates.py.
"""

from __future__ import annotations

import sys

from common import ROOT_DIR  # type: ignore[import-not-found]  # noqa: F401

from packages.core.domain.geo.countries import RADAR_COUNTRIES  # noqa: E402
from packages.infrastructure.radar_places.country_estimates import (  # noqa: E402
    FREE_PLAN_DATABASE_MB,
    estimate_for,
    overpass_requests,
    total_database_mb,
)


def main() -> int:
    # The flags are emoji: the Windows console default (cp1252) cannot print them.
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    print(
        "| Paese | Regioni OSM | Luoghi Overture | Luoghi OSM | MB Overture | MB OSM | MB totale "
        "| Tempo Overture (min) | Tempo OSM (min) | Richieste Overpass |"
    )
    print("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |")
    for country in RADAR_COUNTRIES:
        estimate = estimate_for(country)
        low, high = overpass_requests(country)
        note = " (misurato)" if estimate.measured else ""
        print(
            f"| {country.flag} {country.code}{note} | {len(country.regions)} "
            f"| {estimate.overture_places:,} | {estimate.osm_places:,} "
            f"| {estimate.overture_mb:.0f} | {estimate.osm_mb:.0f} | {estimate.total_mb:.0f} "
            f"| {estimate.overture_minutes[0]}-{estimate.overture_minutes[1]} "
            f"| {estimate.osm_minutes[0]}-{estimate.osm_minutes[1]} | {low}-{high} |"
        )
    total = total_database_mb()
    print(
        f"\nTotale sei paesi + Italia: {total:.0f} MB su {FREE_PLAN_DATABASE_MB} MB del piano free."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
