r"""After a database restore: put the register of deletions back and erase again.

A restore brings the database back in time, so an account erased AFTER the
backup is back among the users, and the register table (also in the database)
may have lost the rows that record it. The copy of the register kept in the
private Storage bucket `deletion-log` is outside the database and survives.
Procedure and reasons: docs/security/03_procedura_violazioni.md, section
"Ripristino da backup".

Before the restore:  export the table `account_deletion_log` (Table editor ->
Export), as a second safety net.

After the restore, from the repository root (needs SUPABASE_URL and
SUPABASE_SERVICE_ROLE_KEY in the local .env). Each step is a dry run unless
--apply is given:

    uv run --system-certs --with truststore python \
        scripts/maintenance/reapply_deletions.py            # counts only
    uv run --system-certs --with truststore python \
        scripts/maintenance/reapply_deletions.py --apply    # does it

What it does: (1) reloads into the table the rows the copy holds and the
restored table lacks; (2) lists the accounts that exist now, fingerprints each
id and erases, with the same eraser as the owner's own deletion, those whose
fingerprint is in the register, complete or not. The output carries counts
only, never an id or an e-mail.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterator
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

_PAGE = 200


def _account_ids(client: object) -> Iterator[str]:
    page = 1
    while True:
        users = client.auth.admin.list_users(page=page, per_page=_PAGE)  # type: ignore[attr-defined]
        if not users:
            return
        for user in users:
            yield str(user.id)
        if len(users) < _PAGE:
            return
        page += 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--apply", action="store_true", help="really reload and erase")
    args = parser.parse_args()

    from packages.bootstrap.container import get_container
    from packages.infrastructure.persistence.supabase.client import build_supabase_client

    container = get_container()
    if container.settings.persistence_backend != "supabase":
        print("PERSISTENCE_BACKEND is not supabase: nothing to do.")
        return 1

    log = container.deletion_log_service
    eraser = container.account_eraser()
    client = build_supabase_client(container.settings)

    copy_rows = log._copy.list_all()  # noqa: SLF001 - maintenance tool
    table_rows = log._repository.list_all()  # noqa: SLF001
    missing = {e.owner_hash for e in copy_rows} - {e.owner_hash for e in table_rows}
    print(
        f"register: table={len(table_rows)} copy={len(copy_rows)} missing_in_table={len(missing)}"
    )
    if args.apply:
        print(f"reloaded into the table: {log.reload_from_copy()}")

    report = log.reapply(eraser, _account_ids(client), dry_run=not args.apply)
    print(
        f"accounts checked={report.checked} to_erase={report.to_erase} "
        f"erased={report.erased} failed={report.failed} dry_run={report.dry_run}"
    )
    if not args.apply and report.to_erase:
        print("Dry run: run again with --apply to erase them.")
    return 1 if report.failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
