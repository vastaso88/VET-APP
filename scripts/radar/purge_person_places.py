"""Deletes places that are only a person from the radar tables.

    uv run --system-certs --with truststore python scripts/radar/purge_person_places.py --dry-run
    uv run --system-certs --with truststore python scripts/radar/purge_person_places.py

Owner's decision (2026-11-08): the map shows facilities only, never a
person ("Dott. Mario Rossi", a practitioner without a facility, possibly at
a home address). New imports and the live cache already drop them
(packages/core/domain/radar_places/person_names.py) and the API never
serves them; this removes the rows stored before the rule, so they do not
stay in the database either. Counts per table are printed, names never.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from common import build_client  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from packages.core.domain.radar_places.person_names import is_person_only  # noqa: E402

TABLES = ("radar_places_osm", "radar_places_open", "radar_places_cache")
PAGE = 1000


def person_ids(client: object, table: str) -> list[str]:
    ids: list[str] = []
    start = 0
    while True:
        rows = (
            client.table(table)  # type: ignore[attr-defined]
            .select("id,name")
            .order("id")
            .range(start, start + PAGE - 1)
            .execute()
            .data
            or []
        )
        ids.extend(str(row["id"]) for row in rows if is_person_only(row.get("name")))
        if len(rows) < PAGE:
            return ids
        start += PAGE


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="count only, change nothing")
    args = parser.parse_args()

    client = build_client()
    total = 0
    for table in TABLES:
        ids = person_ids(client, table)
        total += len(ids)
        print(f"{table}: {len(ids)} da togliere")
        if args.dry_run:
            continue
        for start in range(0, len(ids), 100):
            client.table(table).delete().in_("id", ids[start : start + 100]).execute()
    print(f"Totale: {total}.", "Dry run: nessuna modifica." if args.dry_run else "Fatto.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
