"""Imports events from the public iCalendar feeds listed in sources.json.

    uv run --with truststore python scripts/events/import_feeds.py --dry-run
    uv run --with truststore python scripts/events/import_feeds.py

Each source of `scripts/events/sources.json` (see
docs/features/news_and_events_sources.md for the fields and the rules for
adding one) is downloaded, filtered by its keywords, validated with the same
rules as the hand-curated events and upserted by `slug`. A source that does
not answer is reported and skipped; one invalid event never blocks the others
but is listed. Rows are never deleted (an event that disappears from a feed
simply ends). Needs the Supabase service-role key, like the other imports.
"""

from __future__ import annotations

import argparse
import sys
import urllib.request
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "radar"))

from common import (  # type: ignore[import-not-found]  # noqa: E402
    build_client,
    explain_certificate_error,
    now_iso,
)

from packages.infrastructure.events.curated_events import (  # noqa: E402
    CuratedEvent,
    CuratedEventError,
    curated_event_to_row,
    validate_curated_event,
)
from packages.infrastructure.events.ical_source import (  # noqa: E402
    FeedSource,
    ical_event_to_raw,
    is_current,
    load_sources,
    matches_keywords,
    parse_ical,
)

SOURCES_FILE = Path(__file__).resolve().parent / "sources.json"
USER_AGENT = "VetApp-EventsImport/1.0 (public calendar feeds; https://vet-app.vercel.app)"
MAX_BYTES = 5_000_000


def fetch(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})  # noqa: S310
    with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310
        body: bytes = response.read(MAX_BYTES + 1)
    if len(body) > MAX_BYTES:
        raise ValueError("calendario troppo grande")
    return body.decode("utf-8", errors="replace")


def read_source(source: FeedSource, *, today: date) -> tuple[list[CuratedEvent], list[str]]:
    events: list[CuratedEvent] = []
    problems: list[str] = []
    for ical_event in parse_ical(fetch(source.url)):
        if not is_current(ical_event, today=today) or not matches_keywords(
            ical_event, source.keywords
        ):
            continue
        try:
            events.append(
                validate_curated_event(
                    ical_event_to_raw(ical_event, source, today=today), today=today
                )
            )
        except CuratedEventError as exc:
            problems.append(f"{source.key} / {ical_event.summary!r}: {exc}")
    return events, problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="read and validate, write nothing")
    parser.add_argument("--source", action="append", help="only this source key (repeatable)")
    args = parser.parse_args()

    sources = [
        s
        for s in load_sources(SOURCES_FILE)
        if s.enabled and (not args.source or s.key in args.source)
    ]
    if not sources:
        print("Nessuna fonte attiva in scripts/events/sources.json: niente da importare.")
        return 0

    today = datetime.now(UTC).date()
    rows: list[dict[str, Any]] = []
    imported_at = now_iso()
    failed_sources = 0
    for source in sources:
        try:
            events, problems = read_source(source, today=today)
        except Exception as exc:  # noqa: BLE001 - one dead feed must not stop the others
            failed_sources += 1
            print(f"ERRORE  {source.key}: fonte non leggibile ({exc})", file=sys.stderr)
            continue
        for problem in problems:
            print(f"SALTATO {problem}", file=sys.stderr)
        print(f"{source.key}: {len(events)} eventi validi, {len(problems)} scartati.")
        rows.extend(
            curated_event_to_row(
                event, now_iso=imported_at, source=source.key, license_text=source.license
            )
            for event in events
        )

    if args.dry_run or not rows:
        print("--dry-run: nessuna scrittura." if args.dry_run else "Nessun evento da scrivere.")
        return 1 if failed_sources == len(sources) else 0
    client = build_client()
    try:
        client.table("events").upsert(rows, on_conflict="slug").execute()
    except Exception as exc:
        explain_certificate_error(exc)
        raise
    print(f"events: {len(rows)} righe scritte.")
    return 1 if failed_sources == len(sources) else 0


if __name__ == "__main__":
    raise SystemExit(main())
