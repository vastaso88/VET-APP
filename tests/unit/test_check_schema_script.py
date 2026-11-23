import importlib.util
import sys
from pathlib import Path
from types import ModuleType

ROOT_DIR = Path(__file__).resolve().parents[2]


def _load_script() -> ModuleType:
    path = ROOT_DIR / "scripts" / "setup" / "check_schema.py"
    spec = importlib.util.spec_from_file_location("check_schema", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_schema"] = module
    spec.loader.exec_module(module)
    return module


check_schema = _load_script()

DECLARED_SQL = """
-- a comment with a ; and the words create table public.ghost (
create table if not exists public.clinical_events (
    id text primary key,
    pet_id text references public.pet_profiles(id) on delete cascade,
    title text not null,
    price numeric(10, 2) not null default 0,
    created_at timestamptz not null default now(),
    constraint title_not_empty check (title <> '')
);
alter table public.clinical_events add column if not exists subtitle text;
alter table public.clinical_events add column if not exists owner_id text;
alter table public.clinical_events alter column owner_id set default auth.uid()::text;

create trigger on_event_insert after insert on public.clinical_events
for each row execute function public.handle_event();
"""

# The shape PostgREST returns: `required` = NOT NULL columns, `default`
# present on a column that has one.
LIVE_DESCRIPTION = {
    "definitions": {
        "clinical_events": {
            "required": ["id", "owner_id", "pet_id", "event_type", "title", "event_date"],
            "properties": {
                "id": {"format": "text", "type": "string"},
                "owner_id": {"format": "text", "type": "string"},
                "pet_id": {"format": "text", "type": "string"},
                "event_type": {"format": "text", "type": "string"},
                "title": {"format": "text", "type": "string"},
                "event_date": {"format": "date", "type": "string"},
                "summary": {"format": "text", "type": "string"},
                "price": {"format": "numeric", "type": "number", "default": 0},
                "created_at": {
                    "format": "timestamp with time zone",
                    "type": "string",
                    "default": "now()",
                },
            },
        },
        "billing_plans": {"properties": {"id": {"format": "uuid", "type": "string"}}},
    }
}


def test_the_declared_schema_is_read_from_create_and_alter_statements() -> None:
    declared = check_schema.parse_declared_schema(DECLARED_SQL)

    columns = declared.tables["clinical_events"]
    assert set(columns) == {"id", "pet_id", "title", "price", "created_at", "subtitle", "owner_id"}
    assert "ghost" not in declared.tables
    assert columns["title"].must_be_supplied
    assert not columns["price"].must_be_supplied
    assert columns["price"].type == "numeric"
    assert columns["created_at"].type == "timestamp with time zone"
    assert columns["owner_id"].has_default
    assert declared.triggers == {"on_event_insert"}


def test_differences_that_break_writes_are_separated_from_the_rest() -> None:
    declared = check_schema.parse_declared_schema(DECLARED_SQL)
    live = check_schema.parse_live_schema(LIVE_DESCRIPTION)

    report = check_schema.compare(declared, live)

    blocking = "\n".join(report.blocking)
    # Declared by us, missing live.
    assert "clinical_events.subtitle" in blocking
    # NOT NULL without default live, unknown to our schema.
    assert "clinical_events.event_type" in blocking
    assert "clinical_events.event_date" in blocking
    # NOT NULL without default live, optional (or defaulted) in ours.
    assert "clinical_events.owner_id" in blocking
    assert "clinical_events.pet_id" in blocking
    # Agreeing columns are not reported.
    assert "clinical_events.title" not in blocking
    assert "clinical_events.created_at" not in blocking

    informational = "\n".join(report.informational)
    assert "clinical_events.summary" in informational
    assert "billing_plans" in informational
    assert "summary" not in blocking


def test_a_matching_database_reports_nothing() -> None:
    declared = check_schema.parse_declared_schema(
        "create table public.t (id text primary key, n integer not null default 0);"
    )
    live = check_schema.parse_live_schema(
        {
            "definitions": {
                "t": {
                    "required": ["id", "n"],
                    "properties": {
                        "id": {"format": "text"},
                        "n": {"format": "integer", "default": 0},
                    },
                }
            }
        }
    )

    report = check_schema.compare(declared, live)

    assert report.blocking == []
    assert report.informational == []


def test_a_json_or_array_column_is_never_reported_as_lacking_a_default() -> None:
    # PostgREST hides the default of these columns: "unknown" must not be
    # read as "missing" (it produced 12 false alarms on the live project).
    declared = check_schema.parse_declared_schema(
        "create table public.t (id text primary key, messages jsonb not null default '[]');"
    )
    live = check_schema.parse_live_schema(
        {
            "definitions": {
                "t": {
                    "required": ["id", "messages", "tags", "extra"],
                    "properties": {
                        "id": {"format": "text"},
                        "messages": {"format": "jsonb"},
                        "tags": {"format": "text[]", "type": "array"},
                        "extra": {"format": "json"},
                    },
                }
            }
        }
    )

    report = check_schema.compare(declared, live)

    assert report.blocking == []


def test_the_trigger_query_excludes_our_own_triggers() -> None:
    query = check_schema.trigger_query({"on_event_insert"})

    assert "information_schema.triggers" in query
    assert "not in ('on_event_insert')" in query


def test_the_repository_schema_file_parses_and_declares_the_clinical_event_columns() -> None:
    declared = check_schema.parse_declared_schema(
        check_schema.SCHEMA_FILE.read_text(encoding="utf-8")
    )

    columns = declared.tables["clinical_events"]
    for name in (
        "pet_name",
        "subtitle",
        "meta",
        "badge",
        "detail_source",
        "attachment_id",
        "owner_id",
        "event_type",
        "event_date",
    ):
        assert name in columns, name
    for name in ("owner_id", "event_type", "event_date"):
        assert columns[name].has_default, name
    assert not columns["pet_name"].not_null
    assert "pet_profiles" in declared.tables and "reminders" in declared.tables


# -- type, default and NOT NULL (2026-11-23): the names alone let production and the twin drift --


def _columns_rows(*rows: tuple[str, str, str, str, str | None]) -> list[dict[str, object]]:
    """Rows shaped like `columns_query()`: table, column, data_type, is_nullable, default."""
    return [
        {
            "table_name": table,
            "column_name": column,
            "data_type": data_type,
            "is_nullable": nullable,
            "column_default": default,
            "is_identity": "NO",
            "is_generated": "NEVER",
        }
        for table, column, data_type, nullable, default in rows
    ]


def test_an_alter_column_type_is_read_by_the_declared_schema() -> None:
    declared = check_schema.parse_declared_schema(
        "create table public.t (id text primary key, at text not null default now()::text);\n"
        "alter table public.t alter column at drop default;\n"
        "alter table public.t alter column at type timestamptz using at::timestamptz;\n"
        "alter table public.t alter column at set default now();\n"
        "alter table public.t add column n integer;\n"
        "alter table public.t alter column n set data type bigint;\n"
    )

    columns = declared.tables["t"]
    assert columns["at"].type == "timestamp with time zone"
    assert columns["at"].has_default and columns["at"].not_null
    assert columns["n"].type == "bigint"


def test_the_exact_shape_reports_type_default_and_not_null_separately() -> None:
    declared = check_schema.parse_declared_schema(
        "create table public.t (\n"
        "  id text primary key,\n"
        "  a text,\n"
        "  b text not null,\n"
        "  c text not null default 'x',\n"
        "  d text,\n"
        "  tags text[],\n"
        "  v extensions.vector(3)\n"
        ");"
    )
    live = check_schema.parse_live_columns(
        _columns_rows(
            ("t", "id", "text", "NO", None),
            ("t", "a", "text", "NO", None),  # NOT NULL there, optional here
            ("t", "b", "text", "NO", None),  # same
            ("t", "c", "text", "NO", None),  # no default there
            ("t", "d", "timestamp with time zone", "YES", "now()"),  # type and default
            ("t", "tags", "ARRAY", "YES", None),  # arrays and extension types: family only
            ("t", "v", "USER-DEFINED", "YES", None),
        )
    )

    report = check_schema.compare(declared, live)
    shape = "\n".join(report.shape)

    assert "t.a: NOT NULL sì nel database, no nel nostro schema" in shape
    assert "t.c: predefinito no nel database, sì nel nostro schema" in shape
    assert "t.d: tipo 'timestamp with time zone' nel database, 'text' nel nostro schema" in shape
    assert "t.d: predefinito sì nel database, no nel nostro schema" in shape
    for agreeing in ("t.id", "t.b", "t.tags", "t.v"):
        assert agreeing not in shape, agreeing


def test_identity_and_generated_columns_count_as_having_a_default() -> None:
    declared = check_schema.parse_declared_schema(
        "create table public.t (id bigint generated always as identity primary key);"
    )
    rows = _columns_rows(("t", "id", "bigint", "NO", None))
    rows[0]["is_identity"] = "YES"

    assert check_schema.compare(declared, check_schema.parse_live_columns(rows)).shape == []


def test_the_rest_description_only_judges_what_it_can_see() -> None:
    # A NOT NULL column that has a default is not in `required`: the REST description cannot
    # tell it from an optional one, so no NOT NULL difference is reported for it.
    declared = check_schema.parse_declared_schema(
        "create table public.t (id text primary key, k text not null default 'x', o text);"
    )
    live = check_schema.parse_live_schema(
        {
            "definitions": {
                "t": {
                    "required": ["id"],
                    "properties": {
                        "id": {"format": "text"},
                        "k": {"format": "text", "default": "x"},
                        "o": {"format": "text"},
                    },
                }
            }
        }
    )

    assert check_schema.compare(declared, live).shape == []


# The six columns that production had and the scripts did not (read by the Orchestrator from
# information_schema.columns of the live project, 2026-11-23).
PRODUCTION_SIX = _columns_rows(
    ("clinical_events", "owner_id", "text", "NO", "(auth.uid())::text"),
    ("clinical_events", "pet_id", "text", "NO", None),
    ("clinical_events", "event_type", "text", "NO", "'document'::text"),
    ("clinical_events", "event_date", "date", "NO", "CURRENT_DATE"),
    ("clinical_events", "created_at", "timestamp with time zone", "NO", "now()"),
    ("reminders", "kind", "text", "NO", "'custom'::text"),
)


def _repository_shape_of_the_six(sql: str) -> list[str]:
    declared = check_schema.parse_declared_schema(sql)
    live = check_schema.parse_live_columns(PRODUCTION_SIX)
    found: list[str] = []
    for table, columns in live.tables.items():
        for name, column in columns.items():
            ours = declared.tables[table][name]
            found += check_schema._shape_differences(table, name, ours, column)
    return found


def test_the_repository_scripts_have_the_shape_production_has_for_the_six_columns() -> None:
    sql = check_schema.SCHEMA_FILE.read_text(encoding="utf-8")

    assert _repository_shape_of_the_six(sql) == []


def test_the_check_notices_when_one_of_the_six_goes_back_to_the_old_shape() -> None:
    sql = check_schema.SCHEMA_FILE.read_text(encoding="utf-8")
    kind_declared = "add column if not exists kind text not null default 'custom';"
    kind_old = "add column if not exists kind text;"
    for statement, fragment in (
        ("alter table public.clinical_events alter column event_date set not null;", "event_date"),
        ("alter table public.clinical_events alter column owner_id set not null;", "owner_id"),
        ("alter table public.reminders alter column kind set not null;", "kind"),
    ):
        assert statement in sql, statement
        broken_sql = sql.replace(statement, "")
        if fragment == "kind":  # the add-column line says it too: back to the old line
            assert kind_declared in sql
            broken_sql = broken_sql.replace(kind_declared, kind_old)
        broken = _repository_shape_of_the_six(broken_sql)
        assert any(fragment in line and "NOT NULL" in line for line in broken), statement
    old_created_at = sql.replace(
        "alter table public.clinical_events alter column created_at type timestamptz",
        "alter table public.clinical_events alter column created_at type text",
    )
    assert old_created_at != sql
    assert any("created_at: tipo" in line for line in _repository_shape_of_the_six(old_created_at))
