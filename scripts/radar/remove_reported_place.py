"""Takes a place off the radar at once, on request of an owner or a user.

    uv run --with truststore python scripts/radar/remove_reported_place.py \\
        --report-id <id> --reason-code not_public --reason "richiesta del proprietario"
    uv run --with truststore python scripts/radar/remove_reported_place.py \\
        --source overture --source-id <id> --reason-code closed

The id is the one in the email the app prepares ("Identificativo: ...").

- A place users reported through "Segnala!" (--report-id): the report is
  marked rejected and disappears from the radar on the next request.
  The decision is also recorded in `radar_place_overrides` (source
  `vetapp_users`, the report id, reason code and text), which serves as
  the register of removals and of why each was made.
- A place from an open-data source (--source/--source-id): a row is added
  to `radar_place_overrides`, so the API stops serving it and the next
  import does not bring it back.

Use --dry-run to see what would change, and --restore with --report-id to
undo a removal that turned out to be unfounded.
"""

from __future__ import annotations

import argparse
import sys

from common import build_client, now_iso  # type: ignore[import-not-found]

REASON_CODES = {
    "not_public": "non è un luogo pubblico o aperto al pubblico",
    "closed": "ha chiuso o non esiste",
    "duplicate": "doppione di un altro luogo",
    "wrong_data": "dati errati",
    "owner_request": "richiesta del titolare",
    "other": "altro",
}
USER_SOURCE_NAME = "vetapp_users"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--report-id", help="id of a user report (place reported as missing)")
    parser.add_argument("--source", help="source of an imported place, e.g. overture")
    parser.add_argument("--source-id", help="the source's own id of that place")
    parser.add_argument(
        "--reason-code",
        choices=sorted(REASON_CODES),
        default="other",
        help="why the place is removed: "
        + "; ".join(f"{k} = {v}" for k, v in REASON_CODES.items()),
    )
    parser.add_argument("--reason", default="", help="free text added to the reason code")
    parser.add_argument(
        "--restore",
        action="store_true",
        help="with --report-id: put the report back to pending (request unfounded)",
    )
    parser.add_argument("--dry-run", action="store_true", help="show only, change nothing")
    args = parser.parse_args()

    by_report = bool(args.report_id)
    by_source = bool(args.source and args.source_id)
    if by_report == by_source:
        parser.error("indica --report-id oppure --source insieme a --source-id")

    reason = f"{args.reason_code}: {args.reason}".rstrip(": ")
    client = build_client()
    if by_report:
        found = (
            client.table("radar_user_reports")
            .select("id,kind,status,place_type,name")
            .eq("id", args.report_id)
            .limit(1)
            .execute()
        )
        if not found.data:
            print("Nessuna segnalazione con questo id.", file=sys.stderr)
            return 1
        report = found.data[0]
        print(
            f"Segnalazione {report['id']}: {report['place_type']} '{report['name']}', "
            f"stato {report['status']}"
        )
        if args.dry_run:
            print("Dry run: nessuna modifica.")
            return 0
        if args.restore:
            client.table("radar_user_reports").update(
                {"status": "pending", "resolved_at": None}
            ).eq("id", args.report_id).execute()
            client.table("radar_place_overrides").delete().eq("source", USER_SOURCE_NAME).eq(
                "source_id", args.report_id
            ).execute()
            print("Fatto: la segnalazione è di nuovo in attesa di conferma.")
            return 0
        client.table("radar_user_reports").update(
            {"status": "rejected", "resolved_at": now_iso()}
        ).eq("id", args.report_id).execute()
        # The register entry: what was removed, when and why.
        client.table("radar_place_overrides").upsert(
            {
                "source": USER_SOURCE_NAME,
                "source_id": args.report_id,
                "action": "exclude",
                "reason": reason,
            }
        ).execute()
        print("Fatto: la segnalazione è respinta e il luogo non compare più.")
        return 0

    row = {
        "source": args.source,
        "source_id": args.source_id,
        "action": "exclude",
        "reason": reason,
    }
    print(f"Esclusione: {row}")
    if args.dry_run:
        print("Dry run: nessuna modifica.")
        return 0
    client.table("radar_place_overrides").upsert(row).execute()
    print("Fatto: il luogo non viene più servito né reimportato.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
