import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "scripts/setup/supabase_schema.sql"
TABLE = "public.pet_weight_measurements"


def _statements(sql: str) -> str:
    """The SQL without comments."""
    return "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))


def _policy(sql: str, name: str) -> str:
    match = re.search(rf"create policy {name}\s+on {re.escape(TABLE)}(.*?);", sql, re.DOTALL)
    assert match, name
    return match.group(1)


def test_a_weighing_can_only_be_changed_or_deleted_by_its_owner() -> None:
    # The app writes weighings straight to Supabase (no API route): this is
    # what keeps "user B" away from the weighings of "user A".
    sql = _statements(SCHEMA.read_text(encoding="utf-8"))

    assert f"alter table {TABLE} enable row level security;" in sql
    update = _policy(sql, "pet_weight_measurements_update_own")
    delete = _policy(sql, "pet_weight_measurements_delete_own")
    assert "for update" in update
    assert "using (owner_id = auth.uid()::text)" in update
    assert "with check (owner_id = auth.uid()::text)" in update
    assert "for delete" in delete
    assert "using (owner_id = auth.uid()::text)" in delete


def test_no_policy_opens_the_weighings_to_everyone() -> None:
    sql = _statements(SCHEMA.read_text(encoding="utf-8"))
    block = re.findall(rf"create policy \w+\s+on {re.escape(TABLE)}.*?;", sql, re.DOTALL)

    assert len(block) >= 4
    for policy in block:
        assert "using (true)" not in policy
        assert "auth.uid()" in policy
