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
    assert "set search_path = ''" in function.group(0)
    # It answers only about the caller: nobody can ask about someone else.
    assert "r.owner_id = auth.uid()::text" in function.group(0)
    for action in ("insert", "update"):
        assert re.search(
            rf"create policy marketplace_listings_{action}_not_restricted\s+"
            rf"on public\.marketplace_listings\s+as restrictive\s+for {action}",
            sql,
        )


_RESTRICTED = re.compile(
    r"create or replace function public\.marketplace_caller_is_restricted\(\).*?\$\$;", re.S
)
_EXPIRY_COLUMN = re.compile(
    r"alter table public\.marketplace_user_restrictions\s+"
    r"add column if not exists expires_at timestamptz;"
)


def test_no_script_can_bring_back_a_restriction_that_ignores_its_expiry() -> None:
    """Every file that defines the function holds the text of the 2026-11-21 migration:
    run again, by mistake or on purpose, none of them makes an expired block count."""
    migrations = SETUP.parents[1] / "supabase/migrations"
    source = (migrations / "20261121165154_admin_user_operations.sql").read_text(encoding="utf-8")
    expected = " ".join(_RESTRICTED.findall(source)[0].split())
    assert "(r.expires_at is null or r.expires_at > now())" in expected

    found: dict[str, int] = {}
    for path in [*SETUP.glob("*.sql"), *migrations.glob("*.sql")]:
        sql = _statements(path.read_text(encoding="utf-8"))
        definitions = list(_RESTRICTED.finditer(sql))
        found[path.name] = len(definitions)
        for match in definitions:
            assert " ".join(match.group(0).split()) == expected, path.name
            # A sql function is checked when created: the column must be there already.
            column = _EXPIRY_COLUMN.search(sql)
            assert column is not None and column.start() < match.start(), path.name
        # No definition written in a way the pattern above would miss.
        anyhow = re.findall(
            r"function\s+public\.marketplace_caller_is_restricted\s*\(\s*\)\s+returns", sql, re.I
        )
        assert len(anyhow) == len(definitions), path.name
    assert found["marketplace_messages.sql"] == 1
    assert found["supabase_schema.sql"] == 2


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
    # 6 months from the LAST MESSAGE when the ad is closed, as the privacy notice and
    # the Terms promise (owner, 2026-11-23): no closing date counts, and neither does
    # the team closing the conversation. tests/sql runs the cases.
    assert "l.updated_at" not in body
    assert "moderation_closed_at" not in body
    # An ad taken down can be restored: only a sold or a deleted one is closed.
    assert "l.status = 'sold'" in body and "c.listing_id is null" in body
    assert "removed" not in body and "'active'" not in body
    # A decided report keeps the conversation this long (owner, decision B).
    assert body.count("review_months constant integer := 6;") == 1
    assert "r.resolved_at > now() - make_interval(months => review_months)" in body
    # A team block goes 12 months after it ended, lifted or expired (decision C).
    assert "where least(lifted_at, expires_at) < now() - interval '12 months';" in body
    # Kept after an account deletion: the same months, only if upheld (texts, doc 24).
    assert body.count("r.resolved_at > now() - make_interval(months => review_months)") == 2
    # What an account deletion kept for review still has its own rule.
    assert "c.erased_participant_at is null" in body
    assert "c.erased_participant_at is not null" in body
    assert re.search(
        r"revoke all on function public\.marketplace_messages_cleanup\(\)\s+"
        r"from public, anon, authenticated;",
        sql,
    )
    assert "'select public.marketplace_messages_cleanup()'" in sql


def test_the_unreported_conversations_of_an_ad_the_team_removed_go_with_the_ad() -> None:
    sql = _statements(_script())

    function = re.search(
        r"create or replace function public\.marketplace_drop_conversations_of_removed_ad\(\)"
        r".*?\$\$;",
        sql,
        re.S,
    )
    assert function is not None
    body = function.group(0)
    assert "security definer" in body and "set search_path = ''" in body
    # Only the team's removal: an ad hidden by reports alone keeps the ordinary times.
    assert "if old.status = 'removed_policy' then" in body
    assert "c.erased_participant_at is null" in body and "not exists" in body
    assert re.search(
        r"revoke all on function public\.marketplace_drop_conversations_of_removed_ad\(\)\s+"
        r"from public, anon, authenticated;",
        sql,
    )
    assert re.search(
        r"drop trigger if exists marketplace_listing_10_drop_conversations.*?;\s+"
        r"create trigger marketplace_listing_10_drop_conversations\s+"
        r"before delete on public\.marketplace_listings",
        sql,
        re.S,
    )


def test_the_schema_holds_the_same_block_as_the_script() -> None:
    schema = (SETUP / "supabase_schema.sql").read_text(encoding="utf-8").replace("\r\n", "\n")

    assert _script().replace("\r\n", "\n").strip() in schema


def test_the_retention_migration_is_the_same_text_as_the_script() -> None:
    migration = (
        SETUP.parents[1] / "supabase/migrations/20261123100000_marketplace_messages_retention.sql"
    ).read_text(encoding="utf-8")
    block = migration[migration.index("-- Conservazione. Decisioni") :].strip()

    assert block in _script()
    # Two functions and a trigger: no table is created or deleted and no job is touched.
    statements = _statements(migration)
    assert "create table" not in statements
    assert "cron" not in statements
