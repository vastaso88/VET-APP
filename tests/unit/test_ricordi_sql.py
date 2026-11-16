"""scripts/setup/ricordi_animali.sql, read as text: the owner runs it by hand on
Supabase, so what must hold for a pet in Ricordi (read, export and delete only)
is checked here before anyone runs it."""

import re
from pathlib import Path

import pytest

from packages.core.domain.subscription.direct_writes import GATED_TABLES

SQL = (Path(__file__).resolve().parents[2] / "scripts/setup/ricordi_animali.sql").read_text(
    encoding="utf-8"
)
CHILD_TABLES = (
    "clinical_events",
    "pet_conditions",
    "reminders",
    "dog_walks",
    "pet_weight_measurements",
    "pet_photos",
)


def _statements() -> str:
    return "\n".join(line for line in SQL.splitlines() if not line.lstrip().startswith("--"))


def _function(name: str) -> str:
    match = re.search(rf"create or replace function public\.{name}\(.*?\$\$;", _statements(), re.S)
    assert match is not None, name
    return match.group(0)


def test_every_table_the_app_writes_about_a_pet_is_covered() -> None:
    # The tables the app writes directly (plan rules) that hold a pet's data.
    pet_tables = {t for t in GATED_TABLES if t not in {"pet_profiles", "local_activities"}}
    assert pet_tables == set(CHILD_TABLES)


@pytest.mark.parametrize("table", CHILD_TABLES)
def test_child_table_refuses_inserts_and_changes_never_deletes(table: str) -> None:
    sql = _statements()
    assert f"drop trigger if exists ricordi_10_read_only on public.{table};" in sql
    trigger = re.search(
        rf"create trigger ricordi_10_read_only\s+before (.*?)\s+on public\.{table}\s+"
        r"for each row execute function public\.ricordi_child_read_only\(\);",
        sql,
    )
    assert trigger is not None
    assert trigger.group(1) == "insert or update", "deleting stays allowed"


def test_profile_keeps_only_the_memorial_fields_while_in_memories() -> None:
    sql = _statements()
    assert "drop trigger if exists ricordi_10_profile_read_only on public.pet_profiles;" in sql
    assert re.search(
        r"create trigger ricordi_10_profile_read_only\s+before update on public\.pet_profiles",
        sql,
    )
    body = _function("ricordi_profile_read_only")
    # Moving in and bringing back are free; only "still in Ricordi" is frozen.
    assert "if not (old.is_memorial and new.is_memorial) then" in body
    assert "jsonb_populate_record(\n        old," in body
    kept = set(re.findall(r"'(\w+)', new\.\1", body))
    assert kept == {
        "memorial_date_label",
        "memorial_birthday_reminder",
        "memorial_walks_reminder",
        "memorial_photos_reminder",
    }


def test_only_app_writes_are_checked_and_the_code_matches_the_backend() -> None:
    for name in ("ricordi_profile_read_only", "ricordi_child_read_only"):
        body = _function(name)
        assert "security definer" in body and "set search_path = public" in body
        assert "if coalesce(auth.role(), '') not in ('authenticated', 'anon') then" in body
    child = _function("ricordi_child_read_only")
    assert "errcode = 'PT409'" in child and "message = 'pet_in_memories'" in child
    # A row can't be moved away from a memory either.
    assert "memorial := public.ricordi_pet_is_memorial(old.pet_id);" in child


def test_old_routes_can_still_be_pruned() -> None:
    child = _function("ricordi_child_read_only")
    assert "tg_table_name = 'dog_walks'" in child
    assert "(to_jsonb(new) - 'route') = (to_jsonb(old) - 'route')" in child


def test_old_is_read_only_in_an_update() -> None:
    # OLD is null in an insert: it is only read inside "if tg_op = 'UPDATE'".
    child = _function("ricordi_child_read_only")
    before_update_branch = child.split("if tg_op = 'UPDATE' then", 1)[0]
    assert "old." not in before_update_branch and "to_jsonb(old)" not in before_update_branch


def test_helper_functions_are_not_callable_from_the_app() -> None:
    sql = _statements()
    for signature in (
        "ricordi_pet_is_memorial(text)",
        "ricordi_profile_read_only()",
        "ricordi_child_read_only()",
    ):
        assert f"revoke all on function public.{signature} from public, anon, authenticated;" in sql


def test_idempotent() -> None:
    sql = _statements()
    assert "create trigger" in sql
    assert sql.count("create trigger") == sql.count("drop trigger if exists")
    assert "create function" not in sql
