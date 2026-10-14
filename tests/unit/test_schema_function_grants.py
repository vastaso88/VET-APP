"""Every `security definer` function the schema declares that a client could
call through PostgREST (anything but a trigger function) must be revoked
from public/anon/authenticated and granted to service_role only — found
by the git manager on build 32: without it, anyone with the app's anon key
could add tokens to the shared daily budget or lock another owner out."""

from __future__ import annotations

import re
from pathlib import Path

SCHEMA = Path(__file__).resolve().parents[2] / "scripts/setup/supabase_schema.sql"

_FUNCTION = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\((.*?)\)\s*"
    r"returns\s+(.*?)\s+language\s+\w+\s+(security\s+definer)?",
    re.IGNORECASE | re.DOTALL,
)


def _signature_types(parameters: str) -> str:
    """ "p_day date, p_model text default 'x'" -> "date, text"."""
    types: list[str] = []
    for parameter in [p.strip() for p in parameters.split(",") if p.strip()]:
        words = re.sub(r"\s+default\s+.*$", "", parameter, flags=re.IGNORECASE).split()
        types.append(" ".join(words[1:]) if len(words) > 1 else words[0])
    return ", ".join(types)


def _normalized(sql: str) -> str:
    return re.sub(r"\s+", " ", sql.lower())


def test_every_callable_security_definer_function_is_service_role_only() -> None:
    sql = SCHEMA.read_text(encoding="utf-8")
    normalized = _normalized(sql)
    checked: list[str] = []
    for match in _FUNCTION.finditer(sql):
        name, parameters, returns, definer = match.groups()
        if not definer or returns.strip().lower() == "trigger":
            continue
        signature = f"public.{name}({_signature_types(parameters)})".lower()
        signature = re.sub(r"\s+", " ", signature)
        revoke = f"revoke all on function {signature} from public, anon, authenticated;"
        grant = f"grant execute on function {signature} to service_role;"
        assert revoke in normalized, f"{signature}: missing `{revoke}`"
        assert grant in normalized, f"{signature}: missing `{grant}`"
        checked.append(name)
    # The functions this test exists for are among those checked.
    for expected in ("llm_usage_add", "chat_user_daily_usage_add", "chat_answer_cache_hit"):
        assert expected in checked, expected
