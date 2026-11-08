"""The plan rules on the app's direct writes (scripts/setup/plan_access_rules.sql),
read as text: the SQL is run by hand on Supabase, so what must be true of it is
checked here, together with its alignment with the backend and with the app."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

from packages.core.domain.subscription.direct_writes import (
    EXEMPT_TABLES,
    GATED_BUCKET,
    GATED_TABLES,
    PLAN_LIMIT_CODE,
    PLAN_LIMIT_SQLSTATE,
    SUBSCRIPTION_REQUIRED_CODE,
    SUBSCRIPTION_REQUIRED_SQLSTATE,
)
from packages.core.domain.subscription.limits import LIMITS_BY_PLAN, TRIAL_LIMITS

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/setup/plan_access_rules.sql"
APP_LIB = ROOT / "apps/mobile_app/lib"


def _sql() -> str:
    text = SCRIPT.read_text(encoding="utf-8")
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))


def test_the_script_is_generated_from_the_backend_numbers() -> None:
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts/maintenance/gen_plan_access_sql.py"), "--check"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_every_plan_limit_and_the_trial_are_the_backend_ones() -> None:
    sql = _sql()
    for plan, limits in LIMITS_BY_PLAN.items():
        assert f"when '{plan}' then {limits.max_pets}" in sql
    assert f"return {TRIAL_LIMITS.max_pets};" in sql
    assert "interval '14 days'" in sql


@pytest.mark.parametrize("table", GATED_TABLES)
def test_every_gated_table_has_the_gate_and_both_restrictive_policies(table: str) -> None:
    sql = _sql()
    assert re.search(
        rf"drop trigger if exists plan_access_10_gate on public\.{table};\s*"
        rf"create trigger plan_access_10_gate\s+before insert or update on public\.{table}",
        sql,
    )
    for command in ("insert", "update"):
        assert re.search(
            rf"drop policy if exists plan_access_{command} on public\.{table};\s*"
            rf"create policy plan_access_{command}\s+on public\.{table}\s+as restrictive\s+"
            rf"for {command}\s+to authenticated",
            sql,
        ), (table, command)


def test_deletes_and_exempt_tables_are_never_touched() -> None:
    sql = _sql()
    assert "for delete" not in sql
    for table in EXEMPT_TABLES:
        assert f"public.{table}" not in sql


def test_the_update_policy_refuses_instead_of_silently_skipping() -> None:
    """A restrictive USING would make an update hit 0 rows with no error (the
    app would believe it saved): the refusal must come from WITH CHECK."""
    sql = _sql()
    for match in re.finditer(r"for update\s+to authenticated\s+using \(([^)]*)\)", sql):
        assert match.group(1) == "true"


def test_the_codes_are_the_backends_and_carry_an_http_status() -> None:
    sql = _sql()
    assert f"errcode = '{SUBSCRIPTION_REQUIRED_SQLSTATE}'" in sql
    assert f"message = '{SUBSCRIPTION_REQUIRED_CODE}'" in sql
    assert f"errcode = '{PLAN_LIMIT_SQLSTATE}'" in sql
    assert f"message = '{PLAN_LIMIT_CODE}'" in sql
    main = (ROOT / "apps/api/main.py").read_text(encoding="utf-8")
    assert f'"code": "{SUBSCRIPTION_REQUIRED_CODE}"' in main
    assert f'"code": "{PLAN_LIMIT_CODE}"' in main
    # PostgREST maps SQLSTATE PTxyz to HTTP xyz: same statuses as the backend.
    assert SUBSCRIPTION_REQUIRED_SQLSTATE == "PT402" and PLAN_LIMIT_SQLSTATE == "PT403"


def test_the_backend_and_the_sql_editor_are_not_gated() -> None:
    sql = _sql()
    assert sql.count("if coalesce(auth.role(), '') not in ('authenticated', 'anon') then") == 2


def test_the_pet_limit_counts_only_new_pets_and_is_race_free() -> None:
    sql = _sql()
    body = re.search(r"function public\.plan_access_pet_limit\(\).*?\$\$;", sql, re.S)
    assert body is not None
    text = body.group(0)
    assert "p.id = new.id and p.owner_id = new.owner_id" in text, "an upsert of an existing pet"
    assert "pg_advisory_xact_lock" in text
    assert re.search(
        r"create trigger plan_access_20_pet_limit\s+before insert on public\.pet_profiles", sql
    )


def test_functions_are_locked_down() -> None:
    sql = _sql()
    for name in (
        "caller_max_pets",
        "caller_can_write",
        "plan_access_gate",
        "plan_access_pet_limit",
    ):
        body = re.search(rf"create or replace function public\.{name}\(\).*?\$\$;", sql, re.S)
        assert body is not None, name
        assert "security definer" in body.group(0)
        assert "set search_path = public" in body.group(0)
        assert re.search(rf"revoke all on function public\.{name}\(\) from public, anon", sql)
    for trigger_function in ("plan_access_gate", "plan_access_pet_limit"):
        assert re.search(
            rf"revoke all on function public\.{trigger_function}\(\) "
            r"from public, anon, authenticated;",
            sql,
        )


def test_support_tables_are_backend_only_and_the_test_period_starts_open() -> None:
    sql = _sql()
    for table in ("plan_access_config", "plan_access_unlimited"):
        assert f"create table if not exists public.{table}" in sql
        assert f"alter table public.{table} enable row level security;" in sql
        assert f"revoke all on table public.{table} from anon, authenticated;" in sql
    assert re.search(
        r"insert into public\.plan_access_config \(id, test_plan\)\s+values \(1, 'pro'\)\s+"
        r"on conflict \(id\) do nothing;",
        sql,
    )
    assert "references auth.users(id) on delete cascade" in sql


def test_storage_is_gated_only_for_the_pet_photos_bucket() -> None:
    sql = _sql()
    assert (
        sql.count(f"with check (bucket_id <> '{GATED_BUCKET}' or public.caller_can_write())") == 2
    )


def test_the_script_is_idempotent_and_atomic() -> None:
    sql = _sql()
    assert sql.count("create policy") == sql.count("drop policy if exists")
    assert sql.count("create trigger") == sql.count("drop trigger if exists")
    assert "begin;" in sql and "commit;" in sql


def _app_direct_writes() -> set[str]:
    """Tables the Flutter app inserts into or updates with the Supabase client."""
    writes: set[str] = set()
    for path in APP_LIB.rglob("*.dart"):
        source = path.read_text(encoding="utf-8")
        constants = dict(re.findall(r"static const (_\w+) = '([a-z_]+)';", source))
        for match in re.finditer(r"\.from\((?:'([a-z_]+)'|(_\w+))\)", source):
            table = match.group(1) or constants.get(match.group(2) or "")
            if not table:
                continue
            following = source[match.end() : match.end() + 260]
            operation = re.search(r"\.(insert|upsert|update|delete|select)\(", following)
            if operation and operation.group(1) in ("insert", "upsert", "update"):
                writes.add(table)
    return writes


def test_every_table_the_app_writes_directly_is_gated_or_declared_exempt() -> None:
    """A new direct write from the app must take a side: under the plan rule,
    or listed as exempt with a reason (direct_writes.py)."""
    writes = _app_direct_writes()
    assert "pet_profiles" in writes, "the scan found the app's own writes"
    assert writes <= set(GATED_TABLES) | set(EXEMPT_TABLES), writes - set(GATED_TABLES)


def test_every_gated_table_exists_in_the_schema() -> None:
    schema = (ROOT / "scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    for table in GATED_TABLES:
        assert f"create table if not exists public.{table}" in schema, table
