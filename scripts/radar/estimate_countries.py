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
    total_database_mb,
)


def _span(minutes: tuple[int, int]) -> str:
    """A measured time as one number (6), an estimate as a range (10-18)."""
    low, high = minutes
    return str(low) if low == high else f"{low}-{high}"


def main() -> int:
    # The flags are emoji: the Windows console default (cp1252) cannot print them.
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    print(
        "| Paese | Regioni OSM | Luoghi Overture | Luoghi OSM | MB Overture | MB OSM | MB totale "
        "| Tempo Overture (min) | Tempo OSM (min) | Estratto Geofabrik (MB) |"
    )
    print("| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |")
    for country in RADAR_COUNTRIES:
        estimate = estimate_for(country)
        note = " (misurato)" if estimate.measured else " (stima)"
        extract = f"{estimate.extract_mb:,}" if estimate.extract_mb else "?"
        print(
            f"| {country.flag} {country.code}{note} | {len(country.regions)} "
            f"| {estimate.overture_places:,} | {estimate.osm_places:,} "
            f"| {estimate.overture_mb:.0f} | {estimate.osm_mb:.0f} | {estimate.total_mb:.0f} "
            f"| {_span(estimate.overture_minutes)} "
            f"| {_span(estimate.osm_minutes)} | {extract} |"
        )
    total = total_database_mb()
    print(
        f"\nTotale sei paesi + Italia: {total:.0f} MB su {FREE_PLAN_DATABASE_MB} MB del piano free."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
