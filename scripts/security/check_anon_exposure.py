"""Passive check: which Supabase tables return rows to an anonymous client?

Runs ONLY read-only HEAD requests with the *publishable* (anon) key, the same
key every installed copy of the app already contains, so it reveals exactly
what an attacker with no login could read. It never uses a secret key (and
refuses one), never writes, never lists row contents: only HTTP status and
the row count PostgREST reports in ``Content-Range``.

Usage (PowerShell):
    $env:SUPABASE_URL = "https://<ref>.supabase.co"
    $env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_..."
    uv run python scripts/security/check_anon_exposure.py

Exit code 1 when a table outside the allowlist exposes rows, so it can gate a
release (see docs/security/05_checklist.md). Table names come from the SQL
setup scripts, so a table added to the schema is checked automatically.
"""

from __future__ import annotations

import argparse
import base64
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Tables whose rows are public on purpose (published events, plan catalog,
# public venues). Anything else returning rows to ``anon`` is a finding.
ALLOWED_PUBLIC: frozenset[str] = frozenset({"events", "billing_plans", "local_activities"})

_TABLE_RE = re.compile(r"create\s+table\s+if\s+not\s+exists\s+public\.([a-z_0-9]+)", re.IGNORECASE)


def tables_from_sql(sql_dir: Path) -> list[str]:
    names: set[str] = set()
    for path in sorted(sql_dir.glob("*.sql")):
        names.update(_TABLE_RE.findall(path.read_text(encoding="utf-8")))
    return sorted(names)


def _reject_secret_key(key: str) -> None:
    if key.lower().startswith("sb_secret_"):
        raise SystemExit("Refusing to run with a secret key: use the publishable key.")
    if key.startswith("eyJ"):
        # Legacy JWT keys: the role is in the (unsigned) payload segment.
        try:
            payload = key.split(".")[1]
            decoded = base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)).decode()
        except (IndexError, ValueError, UnicodeDecodeError):
            decoded = ""
        if '"service_role"' in decoded:
            raise SystemExit("Refusing to run with a service_role key: use the anon key.")


def probe(base_url: str, key: str, table: str, timeout: float) -> tuple[int, str]:
    url = f"{base_url.rstrip('/')}/rest/v1/{table}?select=*&limit=1"
    request = urllib.request.Request(
        url,
        method="HEAD",
        headers={"apikey": key, "Authorization": f"Bearer {key}", "Prefer": "count=exact"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
            return response.status, response.headers.get("Content-Range", "")
    except urllib.error.HTTPError as error:
        return error.code, error.headers.get("Content-Range", "") if error.headers else ""


def visible_rows(content_range: str) -> int | None:
    # PostgREST formats the header as "0-0/12" or "*/0".
    if "/" not in content_range:
        return None
    total = content_range.rsplit("/", 1)[1]
    return int(total) if total.isdigit() else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=os.environ.get("SUPABASE_URL", ""))
    parser.add_argument(
        "--key",
        default=os.environ.get("SUPABASE_PUBLISHABLE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY", ""),
    )
    parser.add_argument(
        "--sql-dir",
        default=str(Path(__file__).resolve().parents[1] / "setup"),
        help="folder with the schema scripts (table names are parsed from them)",
    )
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()

    if not args.url or not args.key:
        print("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required", file=sys.stderr)
        return 2
    _reject_secret_key(args.key)

    tables = tables_from_sql(Path(args.sql_dir))
    if not tables:
        print("no tables found in", args.sql_dir, file=sys.stderr)
        return 2

    findings: list[str] = []
    print(f"{'table':40} status  rows visible to anon")
    for table in tables:
        status, content_range = probe(args.url, args.key, table, args.timeout)
        rows = visible_rows(content_range)
        label = "missing" if status == 404 else ("no grant" if status == 401 else str(rows))
        print(f"{table:40} {status:>6}  {label}")
        if status == 200 or status == 206:
            if rows and table not in ALLOWED_PUBLIC:
                findings.append(f"{table}: {rows} row(s) readable without login")

    if findings:
        print("\nFINDINGS:")
        for finding in findings:
            print(" -", finding)
        return 1
    print("\nOK: no table outside the public allowlist exposes rows to anonymous clients.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
