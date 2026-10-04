"""Shared plumbing of the offline radar importers.

The importers run on a developer machine or in a scheduled GitHub Action,
never inside the API: they hold the service-role key and take minutes.
"""

from __future__ import annotations

import os
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

if TYPE_CHECKING:
    from supabase import Client


def _use_system_certificates() -> None:
    """Makes HTTPS trust the operating system's certificate store.

    Where an antivirus intercepts HTTPS (it re-signs every connection with
    its own root certificate, installed in the Windows store), the Supabase
    client fails with CERTIFICATE_VERIFY_FAILED: it trusts only the bundle
    shipped with `certifi`, which does not know that root. `truststore`
    fixes it; it is optional, so the scripts run it only when present:

        uv run --with truststore python scripts/radar/<script>.py
    """
    try:
        import truststore
    except ModuleNotFoundError:
        return
    truststore.inject_into_ssl()


_use_system_certificates()

BATCH_SIZE = 500

# Bounding box of Italy, islands included. Stored with a completed
# country-wide import so the API knows it can answer from the database.
ITALY_BOUNDS = {
    "min_latitude": 35.2,
    "max_latitude": 47.2,
    "min_longitude": 6.5,
    "max_longitude": 18.8,
}


def now_iso() -> str:
    return datetime.now(UTC).isoformat()


def build_client() -> Client:
    """Service-role client from SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
    (environment or the local .env). Exits with a plain message when they
    are missing rather than failing deep inside the first request."""
    _load_dotenv()
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        sys.exit(
            "Mancano SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY: impostale nel file .env "
            "(o come variabili d'ambiente) e rilancia. In alternativa usa --dry-run."
        )
    from supabase import create_client

    return create_client(url, key)


CERTIFICATE_HINT = (
    "Errore di certificato HTTPS: su questo computer un antivirus intercetta le connessioni. "
    "Rilancia con: uv run --with truststore python scripts/radar/<script>.py"
)


def explain_certificate_error(exc: BaseException) -> None:
    """Prints what to do when a write failed because of the certificate
    problem described in `_use_system_certificates`."""
    if "CERTIFICATE_VERIFY_FAILED" in repr(exc):
        print(CERTIFICATE_HINT, file=sys.stderr)


def _load_dotenv() -> None:
    env_file = ROOT_DIR / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text(encoding="utf-8").splitlines():
        name, separator, value = line.partition("=")
        if separator and name.strip() and not name.lstrip().startswith("#"):
            os.environ.setdefault(name.strip(), value.strip().strip('"').strip("'"))


def upsert_rows(client: Client, table: str, rows: list[dict[str, Any]]) -> None:
    for start in range(0, len(rows), BATCH_SIZE):
        try:
            client.table(table).upsert(rows[start : start + BATCH_SIZE]).execute()
        except Exception as exc:
            explain_certificate_error(exc)
            raise
        print(f"  {table}: {min(start + BATCH_SIZE, len(rows))}/{len(rows)}", flush=True)


def delete_rows_not_imported_at(
    client: Client, table: str, imported_at: str, *, source: str | None = None
) -> None:
    """Drops what a previous run wrote and this one did not: every row of
    this run carries the same `imported_at`. With `source`, only that
    source's rows are touched (several sources share `radar_places_open`)."""
    query = client.table(table).delete().neq("imported_at", imported_at)
    if source is not None:
        query = query.eq("source", source)
    query.execute()


def load_excluded_ids(client: Client, source: str) -> frozenset[str]:
    """Places removed by hand (radar_place_overrides, action "exclude"):
    an import must not bring them back."""
    response = (
        client.table("radar_place_overrides")
        .select("source_id")
        .eq("source", source)
        .eq("action", "exclude")
        .execute()
    )
    return frozenset(str(row["source_id"]) for row in response.data or [])


def save_source(client: Client, row: dict[str, Any]) -> None:
    client.table("data_sources").upsert(row).execute()
