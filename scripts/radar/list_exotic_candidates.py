"""Lists the veterinary practices to check by hand for "Dichiarano di trattare animali esotici".

    uv run --system-certs --with truststore python scripts/radar/list_exotic_candidates.py
    uv run --system-certs --with truststore python scripts/radar/list_exotic_candidates.py \\
        --all-with-website --city Milano

Owner's rule (2026-11-08): a practice gets an exotic group only if its
OFFICIAL website says it treats or has experts for that group. No site, or a
site that does not say so: the practice stays as it is.

This script reads only our own tables and never opens any website. It
writes a CSV (default .local/radar/exotic_candidates.csv, outside git) with
one row per practice to check: name, town, the website as the source gives
it, and why it is a candidate. A person then opens each site, fills the
columns `esito` (si / no / nessun_sito), `gruppi` (comma-separated:
reptile_amphibian, bird, small_mammal, fish, other) and `pagina` (the
address of the page that says it), and records the "si" rows with:

    uv run --system-certs --with truststore python scripts/radar/confirm_competence_claim.py \\
        --import-checked .local/radar/exotic_candidates.csv

Candidates by default: practices whose OSM tags or name already suggest
exotic animals (the "Dichiarano di trattare animali esotici" filter shows them now; the check
turns a hint into a verified statement). --all-with-website adds every
practice with a website, optionally limited to some towns (--city), for a
wider manual campaign.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

from common import build_client  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from packages.core.domain.radar_places.competences import (  # noqa: E402
    groups_from_name,
    groups_from_osm_details,
)
from packages.core.domain.radar_places.person_names import is_person_only  # noqa: E402

PAGE = 1000
COLUMNS = (
    "source",
    "source_id",
    "nome",
    "citta",
    "sito",
    "motivo",
    "esito",
    "gruppi",
    "pagina",
)


def candidate_reason(row: dict[str, object]) -> str:
    """Why a practice is worth checking: groups hinted by its OSM tags or
    its name, or "" when nothing hints at exotic animals."""
    details = row.get("details") if isinstance(row.get("details"), dict) else {}
    hints = groups_from_osm_details(details) + groups_from_name(str(row.get("name") or ""))
    return ",".join(dict.fromkeys(hints))


def _rows(client: object, table: str) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    start = 0
    while True:
        page = (
            client.table(table)  # type: ignore[attr-defined]
            .select("*")
            .eq("place_type", "veterinary")
            .order("id")
            .range(start, start + PAGE - 1)
            .execute()
            .data
            or []
        )
        rows.extend(page)
        if len(page) < PAGE:
            return rows
        start += PAGE


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--all-with-website", action="store_true")
    parser.add_argument("--city", action="append", default=[], help="limit to these towns")
    parser.add_argument("--out", default=".local/radar/exotic_candidates.csv")
    args = parser.parse_args()

    client = build_client()
    towns = {town.strip().lower() for town in args.city if town.strip()}
    selected: list[dict[str, str]] = []
    for table, source_of in (
        ("radar_places_osm", lambda row: "openstreetmap_overpass"),
        ("radar_places_open", lambda row: str(row.get("source"))),
    ):
        for row in _rows(client, table):
            name = str(row.get("name") or "")
            if is_person_only(name):
                continue
            city = str(row.get("city") or "")
            if towns and city.strip().lower() not in towns:
                continue
            reason = candidate_reason(row)
            website = str(row.get("website_url") or "")
            if not reason and not (args.all_with_website and website):
                continue
            selected.append(
                {
                    "source": source_of(row),
                    "source_id": str(row.get("source_external_id") or row.get("source_id") or ""),
                    "nome": name,
                    "citta": city,
                    "sito": website,
                    "motivo": reason or "sito da controllare",
                    "esito": "",
                    "gruppi": "",
                    "pagina": "",
                }
            )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(selected)
    with_site = sum(1 for row in selected if row["sito"])
    print(f"Candidate: {len(selected)} (con sito: {with_site}) -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
