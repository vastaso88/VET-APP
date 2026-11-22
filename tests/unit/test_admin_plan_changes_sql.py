"""QK-07c: the plan-change audit script and the schema keep `owner_id` as text and leave a
single `admin_change_user_plan` (text, uuid, text). Static checks of the SQL files: the
script itself is run by the owner on the database."""

import re
from pathlib import Path

MIGRATION = Path("supabase/migrations/20261121210000_admin_plan_changes.sql")
SCHEMA = Path("scripts/setup/supabase_schema.sql")
TOTP = Path("supabase/migrations/20261121222500_admin_plan_totp.sql")


def _sql(path: Path) -> str:
    return " ".join(path.read_text(encoding="utf-8").lower().split())


def _table(sql: str) -> str:
    start = sql.index("create table if not exists public.admin_plan_changes (")
    return sql[start : sql.index(");", start)]


# The function exactly as read from production (pg_get_functiondef) on 2026-11-22.
PRODUCTION_FUNCTION = (
    "CREATE OR REPLACE FUNCTION public.admin_change_user_plan(p_owner_id text, p_admin_id uuid, "
    "p_plan text) RETURNS void LANGUAGE plpgsql SET search_path TO 'public' AS $function$ "
    "declare v_old text; begin if current_user <> 'service_role' then raise exception "
    "'Forbidden' using errcode='42501'; end if; if p_plan is not null and p_plan not in "
    "('plus','pro','ultra') then raise exception 'Invalid plan' using errcode='22023'; end if; "
    "select plan into v_old from public.subscriptions where owner_id = p_owner_id for update; "
    "if not found then insert into public.subscriptions (owner_id, trial_ends_at, plan) values "
    "(p_owner_id, now() + interval '14 days', p_plan); else update public.subscriptions set "
    "plan = p_plan where owner_id = p_owner_id; end if; insert into public.admin_plan_changes "
    "(owner_id,admin_id,old_plan,new_plan) values (p_owner_id,p_admin_id,v_old,p_plan); "
    "end $function$"
)


def _tight(text: str) -> str:
    return re.sub(r"\s*([()])\s*", r"\1", text)


def _statement(path: Path, start: str, end: str) -> str:
    text = path.read_text(encoding="utf-8")
    first = text.index(start)
    return " ".join(text[first : text.index(end, first) + len(end)].split())


def test_the_migration_function_is_the_production_one_word_for_word() -> None:
    """Only the layout may differ: same tokens, same search_path, same 14-day trial."""
    in_migration = _statement(MIGRATION, "CREATE OR REPLACE FUNCTION", "end $function$")
    # Line breaks after "(" or before ")" are layout, not content.
    assert _tight(in_migration) == _tight(PRODUCTION_FUNCTION)


def test_the_migration_has_a_single_text_version_of_the_function() -> None:
    sql = _sql(MIGRATION)
    assert sql.count("create or replace function public.admin_change_user_plan(") == 1
    # The uuid overload of the first version of the script is removed, before the create.
    drop = "drop function if exists public.admin_change_user_plan(uuid, uuid, text);"
    assert drop in sql
    assert sql.index(drop) < sql.index("create or replace function public.admin_change_user_plan(")
    # No other mention of the uuid version, and the grants follow the text one.
    assert sql.count("admin_change_user_plan(uuid, uuid, text)") == 1  # only the drop
    assert "revoke all on function public.admin_change_user_plan(text, uuid, text)" in sql
    assert "from public, anon, authenticated;" in sql
    assert "grant execute on function public.admin_change_user_plan(text, uuid, text)" in sql
    assert "to service_role;" in sql
    # The header says the body is production's.
    assert MIGRATION.read_text(encoding="utf-8").startswith("-- corpo = produzione (versione Rob)")


def test_owner_id_is_text_and_the_policy_compares_text_in_both_scripts() -> None:
    for path in (MIGRATION, SCHEMA):
        sql = _sql(path)
        table = _table(sql)
        assert "owner_id text not null" in table and "owner_id uuid" not in table
        assert "using (owner_id = (select auth.uid())::text)" in sql
        assert "using (owner_id = (select auth.uid()))" not in sql
        # a database that already has the uuid column is converted, after the policy is dropped
        convert = "alter column owner_id type text using owner_id::text"
        assert convert in sql
        assert sql.index("drop policy if exists admin_plan_changes_select_own") < sql.index(convert)
        assert sql.index(convert) < sql.index("create policy admin_plan_changes_select_own")


def test_the_totp_wrapper_calls_the_text_signature() -> None:
    sql = _sql(TOTP)
    assert "to_regprocedure('public.admin_change_user_plan(text,uuid,text)')" in sql
    assert "perform public.admin_change_user_plan(p_owner_id,p_admin_id,p_plan);" in sql
