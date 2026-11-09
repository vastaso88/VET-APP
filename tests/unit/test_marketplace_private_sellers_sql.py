"""The SQL of the private-seller rule, read as text before anyone runs it."""

import re
from pathlib import Path

SETUP = Path(__file__).resolve().parents[2] / "scripts/setup"


def _statements(sql: str) -> str:
    return "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))


def test_the_column_is_added_idempotently_and_writes_need_the_declaration() -> None:
    sql = _statements((SETUP / "marketplace_private_sellers.sql").read_text(encoding="utf-8"))

    assert "add column if not exists private_seller_declared_at timestamptz" in sql
    assert "add column if not exists private_seller_declaration_version text" in sql
    for action in ("insert", "update"):
        assert f"drop policy if exists marketplace_listings_{action}_private_seller" in sql
        assert re.search(
            rf"create policy marketplace_listings_{action}_private_seller\s+"
            rf"on public\.marketplace_listings\s+as restrictive\s+for {action}\s+"
            rf"to authenticated\s+with check \(private_seller_declared_at is not null\);",
            sql,
        )


def test_the_schema_holds_the_same_script() -> None:
    script = (SETUP / "marketplace_private_sellers.sql").read_text(encoding="utf-8")
    schema = (SETUP / "supabase_schema.sql").read_text(encoding="utf-8").replace("\r\n", "\n")

    assert script.replace("\r\n", "\n").strip() in schema
