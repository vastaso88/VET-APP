"""Compares the live Supabase schema with the one this repository declares.

Read-only: it issues a single GET for the PostgREST schema description and
writes nothing. Run it after editing scripts/setup/supabase_schema.sql, or
whenever the app fails to save something:

    uv run python scripts/setup/check_schema.py

(with an antivirus that intercepts HTTPS:
 uv run --with truststore python scripts/setup/check_schema.py)

Why it exists: tables that were already in the live project when our
script first ran kept their own shape (`create table if not exists` is a
no-op on them), and every such mismatch so far was discovered from a phone
(pet_profiles/conversations 2026-09-28, reminders 2026-09-29,
clinical_events 2026-10-04).

What it reports, per table of the `public` schema:
- declared columns that are missing live (the app/backend writes them:
  inserts fail);
- live NOT NULL columns without a default that our schema does not
  declare, or declares as optional (nobody fills them: inserts fail);
- live columns and tables our schema does not know (informational);
- the shape of the columns both have: type, default (yes/no) and NOT NULL
  (QK-schema 2026-11-23: until then only the names were compared, and a
  database built from these scripts, the collaudo twin, accepted rows that
  production refuses).

How exact the shape is depends on the source. The REST description of the API
shows the type exactly, a default only when it is not json/array, and NOT NULL
only for columns without a default. For an exact answer on every column run
`columns_query()` (printed at the end of the report) in the Supabase SQL editor,
save the rows as JSON and pass the file: `--columns-file columns.json`. No
request is made then.

Triggers are not visible through the REST API: the script prints a query
to paste in the Supabase SQL editor that lists the ones that are not ours.

Exit status: 1 when something that breaks writes or a shape difference was
found, 0 otherwise.
SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are read from the environment
or the local .env and never printed.
"""

from __future__ import annotations

import argparse
import importlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[2]
SCHEMA_FILE = ROOT_DIR / "scripts" / "setup" / "supabase_schema.sql"

# Words that open a table-level constraint rather than a column, inside a
# `create table (...)` body.
_CONSTRAINT_WORDS = {"constraint", "primary", "unique", "foreign", "check", "exclude"}

# Postgres spells some types in two ways; the live description uses the
# long one.
_TYPE_ALIASES = {
    "timestamptz": "timestamp with time zone",
    "timestamp": "timestamp without time zone",
    "int": "integer",
    "int4": "integer",
    "int8": "bigint",
    "float8": "double precision",
    "bool": "boolean",
    "varchar": "character varying",
    "serial": "integer",
    "bigserial": "bigint",
}


@dataclass
class Column:
    name: str
    type: str
    not_null: bool = False
    has_default: bool = False
    # False when the source cannot tell whether the column has a default.
    default_is_known: bool = True
    # False when the source cannot tell whether the column is NOT NULL (the REST
    # description lists only the NOT NULL columns that have no default).
    not_null_is_known: bool = True

    @property
    def must_be_supplied(self) -> bool:
        return self.not_null and not self.has_default and self.default_is_known


@dataclass
class Schema:
    tables: dict[str, dict[str, Column]] = field(default_factory=dict)
    triggers: set[str] = field(default_factory=set)


@dataclass
class Report:
    blocking: list[str] = field(default_factory=list)
    informational: list[str] = field(default_factory=list)
    # type / default / NOT NULL of a column that both sides have, and that differ.
    shape: list[str] = field(default_factory=list)


def _strip_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    return "\n".join(line.split("--", 1)[0] for line in sql.splitlines())


def _split_top_level(body: str) -> list[str]:
    """Splits a `create table` body on the commas that separate its items,
    not on those inside parentheses (`numeric(10, 2)`, `check (a in (1, 2))`)."""
    parts, depth, current = [], 0, ""
    for char in body:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    parts.append(current)
    return [part.strip() for part in parts if part.strip()]


def _normalize_type(raw: str) -> str:
    cleaned = re.sub(r"\(.*?\)", "", raw.lower()).strip()
    return _TYPE_ALIASES.get(cleaned, cleaned)


def _parse_column(definition: str) -> Column | None:
    words = definition.split()
    if len(words) < 2 or words[0].lower() in _CONSTRAINT_WORDS:
        return None
    lowered = definition.lower()
    # The type is everything between the name and the first constraint
    # keyword ("double precision", "timestamp with time zone").
    type_match = re.match(
        r"\S+\s+(.*?)(?=\s+(?:not\s+null|null|default|primary|references|unique|check|"
        r"generated|constraint)\b|$)",
        definition,
        flags=re.IGNORECASE | re.DOTALL,
    )
    column_type = _normalize_type(type_match.group(1) if type_match else words[1])
    serial = words[1].lower() in {"serial", "bigserial"}
    return Column(
        name=words[0].strip('"').lower(),
        type=column_type,
        not_null="not null" in lowered or "primary key" in lowered,
        has_default=" default " in f" {lowered} " or serial or "generated" in lowered,
    )


def parse_declared_schema(sql: str) -> Schema:
    """The `public` tables, columns and triggers our SQL script declares:
    `create table`, then every later `alter table ... add column` /
    `alter column ... set default | drop not null | set not null`."""
    sql = _strip_comments(sql)
    schema = Schema()

    for match in re.finditer(
        r"create\s+table\s+(?:if\s+not\s+exists\s+)?public\.(\w+)\s*\((.*?)\)\s*;",
        sql,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        columns = schema.tables.setdefault(match.group(1).lower(), {})
        for definition in _split_top_level(match.group(2)):
            column = _parse_column(definition)
            if column is not None:
                columns[column.name] = column

    for match in re.finditer(
        r"alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?public\.(\w+)\s+(.*?);",
        sql,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        columns = schema.tables.setdefault(match.group(1).lower(), {})
        action = " ".join(match.group(2).split())
        added = re.match(r"add\s+column\s+(?:if\s+not\s+exists\s+)?(.*)", action, re.IGNORECASE)
        if added:
            column = _parse_column(added.group(1))
            if column is not None:
                columns.setdefault(column.name, column)
            continue
        altered = re.match(r"alter\s+column\s+(\w+)\s+(.*)", action, re.IGNORECASE)
        if altered and altered.group(1).lower() in columns:
            target, change = columns[altered.group(1).lower()], altered.group(2).lower()
            if change.startswith("set default"):
                target.has_default = True
            elif change.startswith("drop default"):
                target.has_default = False
            elif change.startswith("drop not null"):
                target.not_null = False
            elif change.startswith("set not null"):
                target.not_null = True
            elif change.startswith(("type ", "set data type ")):
                words = change.split()
                start = 1 if words[0] == "type" else 3
                target.type = _normalize_type(
                    re.split(r"\s+using\s+", " ".join(words[start:]), maxsplit=1)[0]
                )

    schema.triggers = {
        name.lower()
        for name in re.findall(
            r"create\s+(?:or\s+replace\s+)?trigger\s+(\w+)", sql, flags=re.IGNORECASE
        )
    }
    return schema


def parse_live_schema(openapi: dict[str, Any]) -> Schema:
    """Tables and columns from the PostgREST description of the API.

    A column is taken as "must be supplied" only when PostgREST lists it as
    required AND shows no default for it — the stricter reading, so a
    column is never reported as a problem on the strength of one signal.

    PostgREST does not show the default of json/jsonb and array columns at
    all (checked against the live project 2026-10-04: `messages jsonb not
    null default '[]'` comes back with no `default`), so for those the
    answer is "unknown", never "missing": `not_null_query` gives the exact
    list when it matters.
    """
    schema = Schema()
    for table, definition in (openapi.get("definitions") or {}).items():
        required = set(definition.get("required") or [])
        columns: dict[str, Column] = {}
        for name, spec in (definition.get("properties") or {}).items():
            has_default = "default" in spec
            default_is_known = not _hides_default(spec)
            columns[name.lower()] = Column(
                name=name.lower(),
                type=_normalize_type(str(spec.get("format") or spec.get("type") or "")),
                not_null=name in required,
                has_default=has_default,
                default_is_known=default_is_known,
                # Listed as required: NOT NULL. Not listed and no (visible) default: nullable.
                # Not listed with a default: it can be either.
                not_null_is_known=name in required or (default_is_known and not has_default),
            )
        schema.tables[table.lower()] = columns
    return schema


def parse_live_columns(rows: list[dict[str, Any]]) -> Schema:
    """The exact shape, from the rows of `columns_query()` (information_schema.columns)."""
    schema = Schema()
    for row in rows:
        table = str(row["table_name"]).lower()
        name = str(row["column_name"]).lower()
        has_default = (
            row.get("column_default") is not None
            or str(row.get("is_identity") or "").upper() == "YES"
            or str(row.get("is_generated") or "").upper() == "ALWAYS"
        )
        schema.tables.setdefault(table, {})[name] = Column(
            name=name,
            type=_normalize_type(str(row.get("data_type") or "")),
            not_null=str(row.get("is_nullable") or "").upper() == "NO",
            has_default=has_default,
        )
    return schema


def _hides_default(spec: dict[str, Any]) -> bool:
    column_format = str(spec.get("format") or "").lower()
    return (
        column_format in {"json", "jsonb"}
        or column_format.endswith("[]")
        or (spec.get("type") == "array")
    )


def compare(declared: Schema, live: Schema) -> Report:
    report = Report()
    for table in sorted(declared.tables):
        ours = declared.tables[table]
        if table not in live.tables:
            report.blocking.append(f"{table}: la tabella non esiste nel database")
            continue
        theirs = live.tables[table]
        for name in sorted(ours.keys() - theirs.keys()):
            report.blocking.append(
                f"{table}.{name}: colonna dichiarata nel nostro schema ma assente nel database"
            )
        for name in sorted(theirs):
            column = theirs[name]
            if name not in ours:
                if column.must_be_supplied:
                    report.blocking.append(
                        f"{table}.{name}: nel database è NOT NULL senza default e il nostro "
                        "schema non la conosce (nessuno la valorizza: gli inserimenti falliscono)"
                    )
                else:
                    report.informational.append(
                        f"{table}.{name}: colonna presente nel database, non nel nostro schema"
                    )
                continue
            if column.must_be_supplied and not ours[name].must_be_supplied:
                report.blocking.append(
                    f"{table}.{name}: nel database è NOT NULL senza default, nel nostro schema è "
                    "facoltativa o ha un default (se il codice non la valorizza, "
                    "l'inserimento fallisce)"
                )
            report.shape.extend(_shape_differences(table, name, ours[name], column))
    for table in sorted(live.tables.keys() - declared.tables.keys()):
        report.informational.append(
            f"{table}: tabella presente nel database, non nel nostro schema"
        )
    return report


def _same_type(live: str, ours: str) -> bool:
    if not live or not ours or live == ours:
        return True
    # information_schema names an array "ARRAY" and an extension or enum type
    # "USER-DEFINED": the exact name is not there, so only the family is compared.
    if live == "array":
        return ours.endswith("[]")
    return live == "user-defined"


def _shape_differences(table: str, name: str, ours: Column, live: Column) -> list[str]:
    """Type, default and NOT NULL of a column both sides have."""
    found: list[str] = []
    where = f"{table}.{name}"
    if not _same_type(live.type, ours.type):
        found.append(f"{where}: tipo '{live.type}' nel database, '{ours.type}' nel nostro schema")
    if live.not_null_is_known and live.not_null != ours.not_null:
        found.append(
            f"{where}: NOT NULL {'sì' if live.not_null else 'no'} nel database, "
            f"{'sì' if ours.not_null else 'no'} nel nostro schema"
        )
    if live.default_is_known and ours.default_is_known and live.has_default != ours.has_default:
        found.append(
            f"{where}: predefinito {'sì' if live.has_default else 'no'} nel database, "
            f"{'sì' if ours.has_default else 'no'} nel nostro schema"
        )
    return found


def columns_query() -> str:
    """Type, default and NOT NULL of every column, exactly (the REST description hides some)."""
    return (
        "select table_name, column_name, data_type, is_nullable, column_default,\n"
        "       is_identity, is_generated\n"
        "from information_schema.columns\n"
        "where table_schema = 'public'\n"
        "order by 1, 2;"
    )


def not_null_query() -> str:
    """The exact list of columns an insert must supply — including the
    json/array ones whose default the REST description hides."""
    return (
        "select table_name as tabella, column_name as colonna, data_type as tipo\n"
        "from information_schema.columns\n"
        "where table_schema = 'public' and is_nullable = 'NO' and column_default is null\n"
        "  and is_identity = 'NO'\n"
        "order by 1, 2;"
    )


def trigger_query(our_triggers: set[str]) -> str:
    ours = ", ".join(f"'{name}'" for name in sorted(our_triggers)) or "''"
    return (
        "select event_object_table as tabella, trigger_name, action_timing, "
        "event_manipulation, action_statement\n"
        "from information_schema.triggers\n"
        "where trigger_schema = 'public'\n"
        f"  and trigger_name not in ({ours})\n"
        "order by 1, 2;"
    )


def _use_system_certificates() -> None:
    # Optional, as in scripts/radar/common.py: needed where an antivirus
    # re-signs HTTPS with a root only the operating system trusts.
    try:
        truststore = importlib.import_module("truststore")
    except ModuleNotFoundError:
        return
    truststore.inject_into_ssl()


def _load_dotenv() -> None:
    env_file = ROOT_DIR / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text(encoding="utf-8").splitlines():
        name, separator, value = line.partition("=")
        if separator and name.strip() and not name.lstrip().startswith("#"):
            os.environ.setdefault(name.strip(), value.strip().strip('"').strip("'"))


def fetch_live_description() -> dict[str, Any]:
    _load_dotenv()
    url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        sys.exit(
            "Mancano SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY: impostale nel file .env "
            "(o come variabili d'ambiente) e rilancia."
        )
    request = urllib.request.Request(
        f"{url}/rest/v1/",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/openapi+json",
        },
    )
    # Errors are reported without the exception text: it can carry the
    # request URL.
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            description: dict[str, Any] = json.load(response)
    except urllib.error.HTTPError as exc:
        sys.exit(f"Il database ha risposto con errore HTTP {exc.code}: controlla la chiave.")
    except urllib.error.URLError as exc:
        if "CERTIFICATE_VERIFY_FAILED" in repr(exc.reason):
            sys.exit(
                "Errore di certificato HTTPS: rilancia con\n"
                "  uv run --with truststore python scripts/setup/check_schema.py"
            )
        sys.exit("Impossibile raggiungere il database: controlla connessione e SUPABASE_URL.")
    return description


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").splitlines()[0])
    parser.add_argument(
        "--table", action="append", default=[], help="limita il controllo a questa tabella"
    )
    parser.add_argument(
        "--columns-file",
        help="JSON con le righe di columns_query(): tipo, predefinito e NOT NULL esatti, "
        "senza interrogare il database",
    )
    arguments = parser.parse_args()

    # The messages are Italian: a Windows console would garble the accents.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    _use_system_certificates()
    declared = parse_declared_schema(SCHEMA_FILE.read_text(encoding="utf-8"))
    if arguments.columns_file:
        rows = json.loads(Path(arguments.columns_file).read_text(encoding="utf-8"))
        live = parse_live_columns(rows)
    else:
        live = parse_live_schema(fetch_live_description())
    if arguments.table:
        wanted = {name.lower() for name in arguments.table}
        declared.tables = {k: v for k, v in declared.tables.items() if k in wanted}
        live.tables = {k: v for k, v in live.tables.items() if k in wanted}

    report = compare(declared, live)
    print(f"Tabelle dichiarate: {len(declared.tables)} - tabelle nel database: {len(live.tables)}")
    print(f"\nDA CORREGGERE ({len(report.blocking)})")
    for line in report.blocking or ["  nessuna differenza che blocchi i salvataggi"]:
        print(f"  {line.strip()}")
    print(f"\nFORMA: TIPO, PREDEFINITO, NOT NULL ({len(report.shape)})")
    for line in report.shape or ["  nessuna differenza"]:
        print(f"  {line.strip()}")
    print(f"\nPER INFORMAZIONE ({len(report.informational)})")
    for line in report.informational or ["  niente da segnalare"]:
        print(f"  {line.strip()}")
    print(
        "\nTRIGGER: non sono leggibili da qui. Per vedere quelli non nostri, incolla questa "
        "query nell'editor SQL di Supabase (un risultato vuoto significa che non ce ne sono):\n"
    )
    print(trigger_query(declared.triggers))
    print(
        "\nCOLONNE OBBLIGATORIE: per le colonne json e array il default non è leggibile da qui "
        "(non vengono mai segnalate sopra). L'elenco esatto di ciò che un inserimento deve "
        "valorizzare si ottiene con:\n"
    )
    print(not_null_query())
    print(
        "\nFORMA ESATTA: per tipo, predefinito e NOT NULL di ogni colonna (anche quelle che la "
        "descrizione REST nasconde) incolla questa query, salva il risultato come JSON e "
        "rilancia con --columns-file:\n"
    )
    print(columns_query())
    return 1 if report.blocking or report.shape else 0


if __name__ == "__main__":
    sys.exit(main())
