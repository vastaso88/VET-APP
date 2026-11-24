"""scripts/setup/reminder_title_not_blank.sql, read as text (collaudo F32): the owner runs it
by hand on Supabase, so what it must and must not do is checked here before anyone runs it."""

import re
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / "scripts/setup/reminder_title_not_blank.sql"
SQL = "\n".join(
    line
    for line in PATH.read_text(encoding="utf-8").splitlines()
    if not line.lstrip().startswith("--")
)


def test_a_blank_title_is_refused_when_written_or_changed() -> None:
    assert "create or replace function public.reminder_title_not_blank()" in SQL
    assert "before insert or update on public.reminders" in SQL
    assert "new.title ~ '^\\s*$'" in SQL and "new.title is null" in SQL
    assert "errcode = 'check_violation'" in SQL and "'reminder_title_required'" in SQL
    # An unchanged title is not judged again, and OLD is read only inside an update.
    assert "new.title is not distinct from old.title" in SQL
    assert SQL.index("if tg_op = 'UPDATE' then") < SQL.index("old.title")


def test_the_script_changes_no_data_and_is_idempotent() -> None:
    assert not re.search(r"\b(update public\.|delete from|alter table|insert into)\b", SQL)
    assert SQL.count("create trigger") == SQL.count("drop trigger if exists") == 1
    assert "create function" not in SQL
    assert "revoke all on function public.reminder_title_not_blank() from public, anon" in SQL


def test_it_runs_after_the_plan_and_ricordi_rules_and_on_the_twin() -> None:
    from scripts.collaudo import gemello

    name = "valid_30_reminder_title_not_blank"
    assert f"create trigger {name}" in SQL
    assert "plan_access_10_gate" < name and "ricordi_10_read_only" < name
    assert "scripts/setup/reminder_title_not_blank.sql" in gemello.ORDINE_SCHEMA
