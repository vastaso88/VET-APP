import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETUP = ROOT / "scripts/setup"


def _statements(sql: str) -> str:
    """The SQL without comments, so a commented-out undo does not count."""
    return "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))


def test_the_read_protection_replaces_select_all_with_own_ads_only() -> None:
    sql = _statements((SETUP / "marketplace_read_protection.sql").read_text(encoding="utf-8"))

    assert "drop policy if exists marketplace_listings_select_all" in sql
    assert re.search(
        r"create policy marketplace_listings_select_own\s+on public\.marketplace_listings\s+"
        r"for select\s+using \(owner_id = auth\.uid\(\)::text\);",
        sql,
    )
    assert "create policy marketplace_listings_select_all" not in sql
    assert "using (true)" not in sql


def test_the_schema_no_longer_creates_an_open_read_policy() -> None:
    sql = _statements((SETUP / "supabase_schema.sql").read_text(encoding="utf-8"))

    assert "create policy marketplace_listings_select_all" not in sql
    assert "create policy marketplace_listings_select_own" in sql
    # A re-run of the schema also drops the old open policy from an existing database.
    assert "drop policy if exists marketplace_listings_select_all" in sql


def test_a_hidden_ad_cannot_be_reactivated_by_its_author() -> None:
    schema = (SETUP / "supabase_schema.sql").read_text(encoding="utf-8")
    hide = (SETUP / "marketplace_no_animals.sql").read_text(encoding="utf-8")

    for sql in (schema, hide):
        assert "old.status in ('removed', 'removed_policy')" in sql


def test_the_optional_write_lock_only_drops_insert_and_update_policies() -> None:
    sql = _statements((SETUP / "marketplace_lock_writes.sql").read_text(encoding="utf-8"))

    assert "drop policy if exists marketplace_listings_insert_own" in sql
    assert "drop policy if exists marketplace_listings_update_own" in sql
    assert "delete_own" not in sql
