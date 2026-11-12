"""Moderation of the events suggested by users ("Segnala un evento").

    uv run --with truststore python scripts/events/moderate_submissions.py list
    ... moderate_submissions.py approve <id> --link-checked
    ... moderate_submissions.py reject <id> --note "motivo"

`list` shows what waits in the queue. Before `approve`, open the link of the
suggestion and check date and place on the organizer's own page: the flag
`--link-checked` is how you say you did. A link to a social network or an
aggregator is refused by the project rules; pass the organizer's page with
`--source-url`. The approved event is written to `events` (source
'user_submission') as a local event; the author is never copied. Needs the
Supabase service-role key, like the other import scripts.
"""

from __future__ import annotations

import argparse
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from supabase import Client

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "radar"))

from common import (  # type: ignore[import-not-found]  # noqa: E402
    build_client,
    explain_certificate_error,
    now_iso,
)

from packages.core.domain.events.submission import EventSubmission  # noqa: E402
from packages.infrastructure.events.curated_events import (  # noqa: E402
    CuratedEventError,
    curated_event_to_row,
)
from packages.infrastructure.events.submission_events import (  # noqa: E402
    SUBMISSION_LICENSE,
    SUBMISSION_SOURCE_KEY,
    submission_to_curated,
)
from packages.infrastructure.persistence.supabase.supabase_event_submissions import (  # noqa: E402
    SupabaseEventSubmissionRepository,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="pending suggestions")
    approve = commands.add_parser("approve", help="publish a suggestion as an event")
    approve.add_argument("id")
    approve.add_argument(
        "--link-checked",
        action="store_true",
        help="confirm you checked date and place on the organizer's own page",
    )
    approve.add_argument(
        "--source-url", help="the organizer's page, if the link sent is not usable"
    )
    approve.add_argument("--slug", help="override the generated slug")
    reject = commands.add_parser("reject", help="turn a suggestion down")
    reject.add_argument("id")
    reject.add_argument("--note", default="", help="reason, for the team's own records")
    args = parser.parse_args()

    client = build_client()
    repository = SupabaseEventSubmissionRepository(client)
    try:
        if args.command == "list":
            return _list(repository)
        submission = repository.get(args.id)
        if submission is None or submission.status != "pending":
            print("Nessuna segnalazione in attesa con questo id.", file=sys.stderr)
            return 1
        if args.command == "reject":
            submission.status = "rejected"
            submission.review_note = args.note or None
            submission.reviewed_at = datetime.now(UTC)
            repository.save(submission)
            print(f"Rifiutata: {submission.title}")
            return 0
        return _approve(client, repository, submission, args)
    except Exception as exc:
        explain_certificate_error(exc)
        raise


def _list(repository: SupabaseEventSubmissionRepository) -> int:
    pending = repository.list_pending()
    if not pending:
        print("Nessuna segnalazione in attesa.")
        return 0
    for item in pending:
        place = f"{item.city} ({item.province_code})" if item.province_code else item.city
        print(
            f"{item.id}\n  {item.title} [{item.event_type}]\n"
            f"  {item.starts_on} -> {item.ends_on}, {place}"
            f"{', ' + item.venue_name if item.venue_name else ''}\n  {item.source_url}"
        )
    print(f"\n{len(pending)} in attesa.")
    return 0


def _approve(
    client: Client,
    repository: SupabaseEventSubmissionRepository,
    submission: EventSubmission,
    args: argparse.Namespace,
) -> int:
    if not args.link_checked:
        print(
            f"Apri {submission.source_url} e controlla data e luogo sul sito "
            "dell'organizzatore, poi rilancia con --link-checked.",
            file=sys.stderr,
        )
        return 1
    try:
        event = submission_to_curated(submission, source_url=args.source_url, slug=args.slug)
    except CuratedEventError as exc:
        print(f"Non pubblicabile così: {exc}", file=sys.stderr)
        return 1

    row = curated_event_to_row(
        event,
        now_iso=now_iso(),
        source=SUBMISSION_SOURCE_KEY,
        license_text=SUBMISSION_LICENSE,
    )
    client.table("events").upsert(row, on_conflict="slug").execute()
    submission.status = "approved"
    submission.event_slug = event.slug
    submission.reviewed_at = datetime.now(UTC)
    repository.save(submission)
    print(f"Pubblicato: {event.title} ({event.slug})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
