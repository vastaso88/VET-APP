"""Imports the hand-curated events into the `events` table.

    uv run --with truststore python scripts/events/import_curated.py --dry-run
    uv run --with truststore python scripts/events/import_curated.py

Reads data/events/curated/*.json (see data/events/README.md), validates every
event against the project rules (packages/infrastructure/events/curated_events.py)
and upserts them by `slug`. Nothing is written if even one event is invalid:
fix the file and run again. To take an event off the app set its "status" to
"rejected" in the file (rows are never deleted by this script).
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "radar"))

from common import (  # type: ignore[import-not-found]  # noqa: E402
    build_client,
    explain_certificate_error,
    now_iso,
)

from packages.infrastructure.events.curated_events import (  # noqa: E402
    SOURCE_KEY,
    curated_event_to_row,
    load_curated_events,
)

DEFAULT_DIRECTORY = Path(__file__).resolve().parents[2] / "data" / "events" / "curated"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dry-run", action="store_true", help="validate and count only, write nothing"
    )
    parser.add_argument(
        "--path", type=Path, default=DEFAULT_DIRECTORY, help="directory of *.json files"
    )
    args = parser.parse_args()

    events, problems = load_curated_events(args.path)
    for problem in problems:
        print(f"ERRORE  {problem}", file=sys.stderr)
    if problems:
        print(
            f"{len(problems)} problema/i: non scrivo nulla finché i file non sono corretti.",
            file=sys.stderr,
        )
        return 1

    by_status = Counter(event.status for event in events)
    print(f"{len(events)} eventi validi in {args.path} ({dict(by_status)}).")
    if args.dry_run:
        print("--dry-run: nessuna scrittura.")
        return 0
    if not events:
        print("Nessun evento da importare: la tabella resta com'è.")
        return 0

    client = build_client()
    imported_at = now_iso()
    rows = [curated_event_to_row(event, now_iso=imported_at) for event in events]
    try:
        client.table("events").upsert(rows, on_conflict="slug").execute()
    except Exception as exc:
        explain_certificate_error(exc)
        raise
    print(f"events: {len(rows)} righe scritte (source '{SOURCE_KEY}').")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
