"""The SQL of the confirmations and checks of Mercatino ads, read as text before anyone
runs it (docs/compliance/24, owner decisions of 2026-11-23)."""

import re
from pathlib import Path

import pytest

from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
    OWNER_TABLES,
    RETAINED_AFTER_DELETION,
)

ROOT = Path(__file__).resolve().parents[2]
SETUP = ROOT / "scripts/setup"
SCRIPT = SETUP / "marketplace_content_review.sql"
TABLES = ("marketplace_listing_reviews", "marketplace_listing_decision_log")


def _sql() -> str:
    text = SCRIPT.read_text(encoding="utf-8")
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))


@pytest.mark.parametrize("table", TABLES)
def test_the_tables_are_idempotent_and_closed_to_clients(table: str) -> None:
    sql = _sql()

    assert f"create table if not exists public.{table} (" in sql
    assert f"alter table public.{table} enable row level security;" in sql
    assert f"revoke all on table public.{table} from anon, authenticated;" in sql
    assert "grant select" not in sql


def test_the_reviews_have_their_own_policy_and_go_with_the_ad() -> None:
    sql = _sql()

    assert "drop policy if exists marketplace_listing_reviews_select_own" in sql
    assert re.search(
        r"create policy marketplace_listing_reviews_select_own\s+"
        r"on public\.marketplace_listing_reviews\s+for select\s+"
        r"using \(owner_id = auth\.uid\(\)::text\);",
        sql,
    )
    assert "references public.marketplace_listings(id) on delete cascade" in sql


def test_the_register_has_no_column_for_the_seller_or_the_text() -> None:
    body = _sql().split("create table if not exists public.marketplace_listing_decision_log (")[1]
    columns = re.findall(r"^    (\w+) ", body.split(");")[0], flags=re.M)

    assert columns == ["id", "listing_id", "outcome", "reason", "admin_id", "decided_at"]


def test_account_deletion_erases_the_reviews_and_keeps_the_register() -> None:
    assert ("marketplace_listing_reviews", "owner_id") in OWNER_TABLES
    assert "24 mesi" in RETAINED_AFTER_DELETION["marketplace_listing_decision_log"]


def test_the_photos_of_removed_ads_wait_in_a_private_bucket() -> None:
    sql = _sql()

    assert "'marketplace-photos-held', 'marketplace-photos-held', false" in sql
    assert "set public = false" in sql
    assert "on storage.objects" not in sql, "no policy: only the service role reaches it"


def test_the_schema_and_the_twin_install_the_same_script() -> None:
    script = SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n").strip()
    schema = (SETUP / "supabase_schema.sql").read_text(encoding="utf-8").replace("\r\n", "\n")
    assert script in schema

    source = (ROOT / "scripts/collaudo/gemello.py").read_text(encoding="utf-8")
    assert '"scripts/setup/marketplace_content_review.sql"' in source
