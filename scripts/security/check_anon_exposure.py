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
setup scripts and from supabase/migrations, so a table added to either is
checked automatically; ``--tables a b`` checks only those.

Requests to an external site (CLAUDE.md, docs/compliance/20 §22): the script
names itself ``QuokkaSecurityCheck``, waits 10 seconds between requests to the
same host and appends one metadata-only line per request (date, name, URL,
status) to ``.local/security/richieste.log``, never the key nor any row.
"""

from __future__ import annotations

import argparse
import base64
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

USER_AGENT = "QuokkaSecurityCheck/0.1 (controllo passivo di esposizione, sola chiave pubblica)"
DELAY_SECONDS = 10.0
REQUEST_LOG = Path(__file__).resolve().parents[2] / ".local" / "security" / "richieste.log"

# Tables whose rows are public on purpose (published events, plan catalog,
# public venues). Anything else returning rows to ``anon`` is a finding.
ALLOWED_PUBLIC: frozenset[str] = frozenset({"events", "billing_plans", "local_activities"})

_TABLE_RE = re.compile(r"create\s+table\s+if\s+not\s+exists\s+public\.([a-z_0-9]+)", re.IGNORECASE)


def tables_from_sql(sql_dir: Path, *extra_dirs: Path) -> list[str]:
    names: set[str] = set()
    for folder in (sql_dir, *extra_dirs):
        for path in sorted(folder.glob("*.sql")):
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
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Prefer": "count=exact",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
            result = response.status, response.headers.get("Content-Range", "")
    except urllib.error.HTTPError as error:
        result = error.code, error.headers.get("Content-Range", "") if error.headers else ""
    except (urllib.error.URLError, TimeoutError, OSError):
        # No answer (DNS, network, timeout): status 0, still logged, no retry.
        result = 0, ""
    _log_request(url, result[0])
    return result


def _log_request(url: str, status: int) -> None:
    """One metadata-only line per request (CLAUDE.md, requests to external sites)."""
    try:
        REQUEST_LOG.parent.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(UTC).isoformat(timespec="seconds")
        with REQUEST_LOG.open("a", encoding="utf-8") as log:
            log.write(f"{stamp}\t{USER_AGENT.split(' ')[0]}\tHEAD {url}\t{status}\n")
    except OSError:
        print("warning: could not write the request log", file=sys.stderr)


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
    parser.add_argument("--tables", nargs="*", help="check only these tables")
    parser.add_argument(
        "--delay", type=float, default=DELAY_SECONDS, help="seconds between requests"
    )
    args = parser.parse_args()

    if not args.url or not args.key:
        print("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required", file=sys.stderr)
        return 2
    _reject_secret_key(args.key)

    migrations = Path(__file__).resolve().parents[2] / "supabase" / "migrations"
    tables = args.tables or tables_from_sql(
        Path(args.sql_dir), *([migrations] if migrations.is_dir() else [])
    )
    if not tables:
        print("no tables found in", args.sql_dir, file=sys.stderr)
        return 2

    findings: list[str] = []
    print(f"{'table':40} status  rows visible to anon")
    for index, table in enumerate(tables):
        if index:
            time.sleep(max(args.delay, 0.0))
        status, content_range = probe(args.url, args.key, table, args.timeout)
        rows = visible_rows(content_range)
        label = {0: "unreachable", 401: "no grant", 404: "missing"}.get(status, str(rows))
        print(f"{table:40} {status:>6}  {label}")
        if status == 0:
            print("host unreachable: stopping, no retry", file=sys.stderr)
            return 2
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
