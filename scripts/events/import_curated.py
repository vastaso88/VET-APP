"""Imports the hand-curated events into the `events` table.

    uv run --with truststore python scripts/events/import_curated.py --dry-run
    uv run --with truststore python scripts/events/import_curated.py

Reads data/events/curated/*.json and scripts/events/curated/*.json (see
data/events/README.md and docs/features/news_and_events_sources.md), validates every
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

REPO_ROOT = Path(__file__).resolve().parents[2]
# `data/` is git-ignored (private working notes); `scripts/events/curated/` is
# tracked, so a scheduled run on a clean checkout sees the same events.
DEFAULT_DIRECTORIES = [
    REPO_ROOT / "data" / "events" / "curated",
    Path(__file__).resolve().parent / "curated",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dry-run", action="store_true", help="validate and count only, write nothing"
    )
    parser.add_argument(
        "--path",
        type=Path,
        action="append",
        help="directory of *.json files (repeatable; default: data/events/curated and "
        "scripts/events/curated)",
    )
    args = parser.parse_args()

    directories = args.path or DEFAULT_DIRECTORIES
    events, problems = load_curated_events(directories)
    for problem in problems:
        print(f"ERRORE  {problem}", file=sys.stderr)
    if problems:
        print(
            f"{len(problems)} problema/i: non scrivo nulla finché i file non sono corretti.",
            file=sys.stderr,
        )
        return 1

    by_status = Counter(event.status for event in events)
    print(f"{len(events)} eventi validi in {len(directories)} cartelle ({dict(by_status)}).")
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
