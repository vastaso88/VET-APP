"""Applies the retention rules of "Segnala!" (docs/compliance/07_contributi_utenti.md).

    uv run --system-certs --with truststore python scripts/radar/cleanup_reports.py

- A report nobody confirmed even once within 7 days is deleted (the API
  already stops serving it at that point; RADAR_REPORT_EXPIRY_DAYS changes
  the number for both).
- A report still pending after 90 days is deleted, with its votes.
- 12 months after a report was confirmed or rejected, who reported and who
  voted is forgotten: the votes are deleted and the reporter pseudonym is
  blanked. The report itself and its tallies stay.
"""

from __future__ import annotations

import argparse
import os
from datetime import UTC, datetime, timedelta

from common import build_client  # type: ignore[import-not-found]

PENDING_MAX_AGE = timedelta(days=90)
IDENTITY_RETENTION = timedelta(days=365)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true", help="count only, change nothing")
    args = parser.parse_args()

    client = build_client()
    now = datetime.now(UTC)

    stale = (
        client.table("radar_user_reports")
        .select("id")
        .eq("status", "pending")
        .lt("created_at", (now - PENDING_MAX_AGE).isoformat())
        .execute()
    )
    stale_ids = [str(row["id"]) for row in stale.data or []]

    expiry_days = int(os.environ.get("RADAR_REPORT_EXPIRY_DAYS", "7"))
    unconfirmed = (
        client.table("radar_user_reports")
        .select("id")
        .eq("status", "pending")
        .eq("confirmations", 0)
        .lt("created_at", (now - timedelta(days=expiry_days)).isoformat())
        .execute()
    )
    unconfirmed_ids = [str(row["id"]) for row in unconfirmed.data or []]
    print(f"Segnalazioni mai confermate da oltre {expiry_days} giorni: {len(unconfirmed_ids)}")
    stale_ids = sorted({*stale_ids, *unconfirmed_ids})

    resolved = (
        client.table("radar_user_reports")
        .select("id")
        .neq("status", "pending")
        .neq("reporter_pseudonym", "")
        .lt("resolved_at", (now - IDENTITY_RETENTION).isoformat())
        .execute()
    )
    resolved_ids = [str(row["id"]) for row in resolved.data or []]

    print(f"Segnalazioni da cancellare, comprese quelle ferme da 90 giorni: {len(stale_ids)}")
    print(f"Segnalazioni chiuse da oltre 12 mesi da anonimizzare: {len(resolved_ids)}")
    if args.dry_run:
        print("Dry run: nessuna modifica.")
        return 0

    for report_id in stale_ids:
        # Votes go with the report (on delete cascade).
        client.table("radar_user_reports").delete().eq("id", report_id).execute()
    for report_id in resolved_ids:
        client.table("radar_report_votes").delete().eq("report_id", report_id).execute()
        client.table("radar_user_reports").update({"reporter_pseudonym": ""}).eq(
            "id", report_id
        ).execute()
    print("Fatto.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
