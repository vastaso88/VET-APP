"""QK-30: on an empty database, every trigger function must exist before the trigger that
calls it. 2026-11-22 (defect M001 of the collaudo): supabase_schema.sql created a trigger on
public.set_updated_at(), which only supabase_llm_sources_schema.sql (run later) created, so a
restore from zero stopped there.

Static check of the SQL text, in the documented install order: the scripts of
`scripts/setup/` listed in `scripts.collaudo.gemello.ORDINE_SCHEMA` (the order of the
runbook: base schema, literature layer, increments, generated plan rules), then the
migrations in timestamp order, then the remaining increments of `scripts/setup/`. The
PGlite twin of this test (tests/sql/schema_from_scratch.mjs) actually runs the scripts."""

import re
from pathlib import Path

from scripts.collaudo import gemello

SETUP = Path("scripts/setup")
MIGRATIONS = Path("supabase/migrations")
# Functions Postgres itself or its standard extensions provide: nobody creates them here.
PROVIDED = frozenset(
    {
        "tsvector_update_trigger",
        "tsvector_update_trigger_column",
        "suppress_redundant_updates_trigger",
        "moddatetime",
    }
)

_DEFINITION = re.compile(r"create\s+(?:or\s+replace\s+)?function\s+(?:(\w+)\.)?(\w+)\s*\(")
_USE = re.compile(r"execute\s+(?:function|procedure)\s+(?:(\w+)\.)?(\w+)\s*\(")


def _clean(sql: str) -> str:
    """Lower case, without comments (a commented-out trigger is not a use)."""
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    return "\n".join(re.sub(r"--.*", "", line) for line in sql.lower().splitlines())


def functions_used_before_created(scripts: list[tuple[str, str]]) -> list[str]:
    """[(name, sql)] in install order -> "script: schema.function" for every
    `execute function X()` whose X is not created earlier in the same script or in one before."""
    created: set[str] = set()
    problems: list[str] = []
    for name, sql in scripts:
        text = _clean(sql)
        events = [
            (match.start(), "def", match.group(1) or "public", match.group(2))
            for match in _DEFINITION.finditer(text)
        ] + [
            (match.start(), "use", match.group(1) or "public", match.group(2))
            for match in _USE.finditer(text)
        ]
        for _, kind, schema, function in sorted(events):
            qualified = f"{schema}.{function}"
            if kind == "def":
                created.add(qualified)
            elif qualified not in created and function not in PROVIDED:
                problems.append(f"{name}: {qualified}")
    return problems


def _install_order() -> list[tuple[str, str]]:
    ordered = [Path(name) for name in gemello.ORDINE_SCHEMA]
    ordered += sorted(MIGRATIONS.glob("*.sql"))
    rest = sorted(
        path
        for path in SETUP.glob("*.sql")
        if path not in ordered and path.name != "supabase_security_hardening.sql"
    )
    return [(path.as_posix(), path.read_text(encoding="utf-8")) for path in ordered + rest]


def test_every_trigger_function_exists_before_its_first_use_in_install_order() -> None:
    scripts = _install_order()
    assert len(scripts) > 20  # the order was really read
    assert functions_used_before_created(scripts) == []


def test_the_base_schema_installs_alone_from_zero() -> None:
    """supabase_schema.sql is the first script of the order and must stand on its own."""
    text = Path("scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    assert functions_used_before_created([("scripts/setup/supabase_schema.sql", text)]) == []


def test_set_updated_at_is_defined_in_both_places_with_the_same_body() -> None:
    def body(path: str) -> str:
        sql = " ".join(_clean(Path(path).read_text(encoding="utf-8")).split())
        start = sql.index("create or replace function public.set_updated_at()")
        return sql[start : sql.index("$$;", sql.index("$$", start) + 2) + 3]

    assert body("scripts/setup/supabase_schema.sql") == body(
        "scripts/setup/supabase_llm_sources_schema.sql"
    )


def test_the_check_itself_catches_a_function_used_too_early() -> None:
    late = [
        ("a.sql", "create trigger t before update on public.x execute function public.touch();"),
        ("b.sql", "create or replace function public.touch() returns trigger as $$ $$;"),
    ]
    assert functions_used_before_created(late) == ["a.sql: public.touch"]
    ok = [("a.sql", late[1][1] + "\n" + late[0][1])]
    assert functions_used_before_created(ok) == []
    # a schema-qualified function in another schema is another function
    other = [
        ("a.sql", "create function private.f() returns trigger as $$ $$;"),
        ("b.sql", "create trigger t after insert on x for each row execute function public.f();"),
    ]
    assert functions_used_before_created(other) == ["b.sql: public.f"]
    # a commented-out trigger is not a use
    assert functions_used_before_created([("a.sql", "-- execute function public.nope();")]) == []
