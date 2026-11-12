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
