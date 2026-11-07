"""Confirms or rejects an "Esperti in esotici" claim made with Segnala!.

    uv run --system-certs --with truststore python scripts/radar/confirm_competence_claim.py --list
    uv run --system-certs --with truststore python scripts/radar/confirm_competence_claim.py \\
        --claim-id <id> --evidence-url https://www.example.com/servizi
    uv run --system-certs --with truststore python scripts/radar/confirm_competence_claim.py \\
        --claim-id <id> --reject --note "il sito non ne parla"

A claim says "this practice treats exotic animals" (with the groups). It
stays pending and is never shown until someone of the team has read the
practice's OWN public statement (its website, its page, its sign) and
confirms the claim with the address of that statement as evidence:
--evidence-url is required, and only http(s) addresses are accepted. The
app then shows the competence as "dichiarata dalla struttura, verificata
il <data>". Pass --groups to confirm only the groups the page actually
names. Who made the claim is never printed.

Use --dry-run to see what would change.
"""

from __future__ import annotations

import argparse
import sys
from urllib.parse import urlsplit

from common import build_client, now_iso  # type: ignore[import-not-found]

GROUPS = ("reptile_amphibian", "bird", "small_mammal", "fish", "other")
EVIDENCE_LABELS = {"website": "sito della struttura", "sign": "insegna", "other": "altro"}


def valid_evidence_url(url: str) -> bool:
    parts = urlsplit(url.strip())
    return parts.scheme in {"http", "https"} and bool(parts.netloc) and len(url) <= 500


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", action="store_true", help="list the pending claims")
    parser.add_argument("--claim-id")
    parser.add_argument("--evidence-url", help="the practice's own page that states it")
    parser.add_argument(
        "--groups",
        help="comma-separated subset of the claimed groups to confirm (default: all claimed)",
    )
    parser.add_argument("--reject", action="store_true")
    parser.add_argument("--note", default="", help="short reason, kept with the decision")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    client = build_client()
    if args.list:
        rows = (
            client.table("radar_competence_claims")
            .select("id,place_name,target_source,target_source_id,groups,evidence_kind,created_at")
            .eq("status", "pending")
            .order("created_at")
            .execute()
            .data
            or []
        )
        print(f"Segnalazioni in attesa: {len(rows)}")
        for row in rows:
            print(
                f"- {row['id']} | {row['place_name']} ({row['target_source']} "
                f"{row['target_source_id']}) | gruppi: {', '.join(row['groups'])} | letto su: "
                f"{EVIDENCE_LABELS.get(row['evidence_kind'], row['evidence_kind'])} | "
                f"{row['created_at'][:10]}"
            )
        return 0

    if not args.claim_id:
        parser.error("serve --claim-id (oppure --list)")
    found = (
        client.table("radar_competence_claims").select("*").eq("id", args.claim_id).execute().data
        or []
    )
    if not found:
        print("Segnalazione non trovata.", file=sys.stderr)
        return 1
    claim = found[0]
    if claim["status"] != "pending":
        print(f"La segnalazione è già {claim['status']}: nessuna modifica.", file=sys.stderr)
        return 1

    note = args.note.strip()[:300] or None
    if args.reject:
        update: dict[str, object] = {
            "status": "rejected",
            "resolved_at": now_iso(),
            "resolution_note": note,
        }
    else:
        if not args.evidence_url or not valid_evidence_url(args.evidence_url):
            parser.error(
                "per confermare serve --evidence-url con l'indirizzo http(s) della pagina "
                "della struttura che dichiara la competenza"
            )
        groups = list(claim["groups"])
        if args.groups:
            wanted = [group.strip() for group in args.groups.split(",") if group.strip()]
            unknown = [group for group in wanted if group not in GROUPS]
            if unknown:
                parser.error(f"gruppi sconosciuti: {', '.join(unknown)}")
            groups = [group for group in groups if group in wanted]
            if not groups:
                parser.error("nessuno dei gruppi indicati è tra quelli segnalati")
        update = {
            "status": "confirmed",
            "resolved_at": now_iso(),
            "evidence_url": args.evidence_url.strip(),
            "groups": groups,
            "resolution_note": note,
        }

    print(f"{claim['place_name']}: {update['status']}")
    if args.dry_run:
        print("Dry run: nessuna modifica.")
        return 0
    client.table("radar_competence_claims").update(update).eq("id", args.claim_id).execute()
    print("Fatto. La scheda si aggiorna alla prossima richiesta dell'app.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
