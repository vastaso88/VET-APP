"""scripts/setup/health_cards.sql, read as text (run by hand on Supabase):
the project's rules for a new table (CLAUDE.md, security section)."""

import re
from pathlib import Path

from scripts.security.check_anon_exposure import ALLOWED_PUBLIC

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/setup/health_cards.sql"


def _sql() -> str:
    text = SCRIPT.read_text(encoding="utf-8")
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))


def test_backend_only_table_rls_on_no_policy_no_app_privileges() -> None:
    sql = _sql()
    assert "create table if not exists public.health_cards" in sql
    assert "alter table public.health_cards enable row level security;" in sql
    assert "create policy" not in sql, "service role only: no policy at all"
    assert "revoke all on table public.health_cards from anon, authenticated;" in sql


def test_not_public_by_choice_so_not_in_the_exposure_allowlist() -> None:
    assert "health_cards" not in ALLOWED_PUBLIC


def test_the_search_function_is_locked_down_and_bounded() -> None:
    sql = _sql()
    body = re.search(r"create or replace function public\.search_health_cards\(.*?\$\$;", sql, re.S)
    assert body is not None
    text = body.group(0)
    assert "set search_path = public" in text
    assert "plainto_tsquery" in text, "the question is never parsed as query syntax"
    assert "c.status = 'approved'" in text
    assert "least(greatest(coalesce(p_limit, 10), 1), 20)" in text
    assert re.search(
        r"revoke all on function public\.search_health_cards\(text, text, integer\) "
        r"from public, anon, authenticated;",
        sql,
    )
    assert re.search(
        r"grant execute on function public\.search_health_cards\(text, text, integer\) "
        r"to service_role;",
        sql,
    )
