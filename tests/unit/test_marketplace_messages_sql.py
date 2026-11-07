"""The script of the Mercatino messages, read as text: the SQL is run by hand on
Supabase, so what must be true of it is checked here before anyone runs it."""

import re
from pathlib import Path

import pytest

from scripts.security.check_anon_exposure import ALLOWED_PUBLIC

SETUP = Path(__file__).resolve().parents[2] / "scripts/setup"
TABLES = (
    "marketplace_conversations",
    "marketplace_messages",
    "marketplace_user_blocks",
    "marketplace_conversation_reports",
    "marketplace_user_restrictions",
)


def _script() -> str:
    return (SETUP / "marketplace_messages.sql").read_text(encoding="utf-8")


def _statements(sql: str) -> str:
    return "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))


@pytest.mark.parametrize("table", TABLES)
def test_every_table_is_protected_and_idempotent(table: str) -> None:
    sql = _statements(_script())

    assert f"create table if not exists public.{table}" in sql
    assert f"alter table public.{table} enable row level security" in sql
    assert f"revoke all on table public.{table} from anon, authenticated" in sql
    assert re.search(rf"drop policy if exists {table}_select_own\s+on public\.{table};", sql)
    assert re.search(rf"create policy {table}_select_own\s+on public\.{table}\s+for select", sql)
    assert table not in ALLOWED_PUBLIC


def test_nobody_can_write_or_read_everything_from_outside_the_backend() -> None:
    sql = _statements(_script())

    # The only write policies are the restrictive ones on the ads, which can
    # only take a right away, never give one.
    for policy in re.findall(r"create policy \w+\s+on public\.\w+\s+(?:as \w+\s+)?for \w+", sql):
        if re.search(r"for (insert|update|delete|all)$", policy):
            assert "marketplace_listings" in policy and "as restrictive" in policy, policy
    assert "using (true)" not in sql


def test_a_restricted_owner_cannot_write_ads_directly_either() -> None:
    sql = _statements(_script())

    function = re.search(
        r"create or replace function public\.marketplace_caller_is_restricted\(\).*?\$\$;",
        sql,
        re.S,
    )
    assert function is not None
    assert "security definer" in function.group(0)
    assert "set search_path = public" in function.group(0)
    # It answers only about the caller: nobody can ask about someone else.
    assert "r.owner_id = auth.uid()::text" in function.group(0)
    for action in ("insert", "update"):
        assert re.search(
            rf"create policy marketplace_listings_{action}_not_restricted\s+"
            rf"on public\.marketplace_listings\s+as restrictive\s+for {action}",
            sql,
        )


def test_a_block_made_against_me_is_not_readable_by_me() -> None:
    sql = _statements(_script())

    policy = re.search(r"create policy marketplace_user_blocks_select_own.*?;", sql, re.S)
    assert policy is not None
    assert "blocked_id" not in policy.group(0)


def test_deleting_an_ad_keeps_the_conversation_and_children_follow_their_conversation() -> None:
    sql = _statements(_script())

    assert "references public.marketplace_listings(id) on delete set null" in sql
    assert sql.count("references public.marketplace_conversations(id) on delete cascade") == 2
    assert re.search(
        r"create unique index if not exists \w+\s+on public\.marketplace_conversations"
        r"\(listing_id, buyer_id\)",
        sql,
    )


def test_the_cleanup_keeps_what_is_under_review_and_runs_by_itself() -> None:
    sql = _statements(_script())

    function = re.search(
        r"create or replace function public\.marketplace_messages_cleanup\(\).*?\$\$;", sql, re.S
    )
    assert function is not None
    body = function.group(0)
    assert "security definer" in body
    assert "set search_path = public" in body
    assert "interval '6 months'" in body
    assert "interval '12 months'" in body
    assert "r.status = 'open'" in body
    assert re.search(
        r"revoke all on function public\.marketplace_messages_cleanup\(\)\s+"
        r"from public, anon, authenticated;",
        sql,
    )
    assert "'select public.marketplace_messages_cleanup()'" in sql


def test_the_schema_holds_the_same_block_as_the_script() -> None:
    schema = (SETUP / "supabase_schema.sql").read_text(encoding="utf-8").replace("\r\n", "\n")

    assert _script().replace("\r\n", "\n").strip() in schema
