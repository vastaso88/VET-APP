"""Every table production REALLY has is known to the account deletion.

The schema test of test_delete_account.py reads the repository; some tables were made by
hand long ago and exist only in production (DB-9, docs/security/02_audit.md). This one
reads scripts/security/production_tables.json, the names the Orchestratore photographs at
each release (docs/security/13_righe_orfane.md says how)."""

import json
import re
from datetime import date
from pathlib import Path

import pytest

from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
    ERASED_WITH_THE_IDENTITY,
    HANDLED_ELSEWHERE,
    LEGACY_NOT_PERSONAL_TABLES,
    LEGACY_OWNER_TABLES,
    NOT_PERSONAL_TABLES,
    OWNER_TABLES,
    RADAR_PSEUDONYM_TABLES,
    RETAINED_AFTER_DELETION,
)

ROOT = Path(__file__).resolve().parents[2]
PHOTO = ROOT / "scripts/security/production_tables.json"
ORPHANS = ROOT / "scripts/maintenance/erase_orphan_rows.sql"

ERASED = {table for table, _ in (*OWNER_TABLES, *LEGACY_OWNER_TABLES, *RADAR_PSEUDONYM_TABLES)}
NOT_PERSONAL = {**NOT_PERSONAL_TABLES, **LEGACY_NOT_PERSONAL_TABLES}
KNOWN = (
    ERASED
    | HANDLED_ELSEWHERE
    | ERASED_WITH_THE_IDENTITY
    | NOT_PERSONAL.keys()
    | RETAINED_AFTER_DELETION.keys()
)
# A column that names a person. A table with one is never "not personal" by oversight.
PERSON = re.compile(r"^(owner_id|user_id|email|phone|.*_email|.*_phone|buyer_id|seller_id)$")
# Not personal in spite of it: the reason is written next to the table in the eraser.
NOT_AN_OWNER = {"scrape_runs"}


# None = the photograph does not say (only the provisional one of 2026-11-22).
Tables = dict[str, list[str] | None]


def unknown(tables: Tables) -> set[str]:
    return set(tables) - KNOWN


def suspicious(tables: Tables) -> set[str]:
    return {
        table
        for table, columns in tables.items()
        if table in NOT_PERSONAL
        and table not in NOT_AN_OWNER
        and any(PERSON.match(column) for column in columns or [])
    }


def _photo() -> Tables:
    data = json.loads(PHOTO.read_text(encoding="utf-8"))
    date.fromisoformat(data["read_on"])
    tables: Tables = data["tables"]
    assert len(tables) > 60, "the photograph looks incomplete"
    return tables


def test_the_deletion_knows_every_table_of_production() -> None:
    assert unknown(_photo()) == set(), (
        "Production has table(s) the account deletion does not know: add them to "
        "LEGACY_OWNER_TABLES or LEGACY_NOT_PERSONAL_TABLES with the reason"
    )


def test_no_table_with_a_person_in_it_is_declared_not_personal() -> None:
    assert suspicious(_photo()) == set()


def test_the_columns_the_deletion_filters_on_exist_in_production() -> None:
    tables = _photo()
    for table, column in (*OWNER_TABLES, *LEGACY_OWNER_TABLES):
        columns = tables.get(table)
        assert columns is None or column in columns, (table, column)


@pytest.mark.parametrize(
    ("tables", "new", "odd"),
    [
        ({"reminders": ["id", "owner_id"]}, set(), set()),
        ({"made_by_hand": ["id", "owner_id"]}, {"made_by_hand"}, set()),
        ({"events": ["id", "title"]}, set(), set()),
        ({"events": ["id", "contact_email"]}, set(), {"events"}),
        ({"system_settings": ["user_id"]}, set(), {"system_settings"}),
        ({"scrape_runs": ["id", "owner_id"]}, set(), set()),
    ],
)
def test_the_net_catches_what_it_should(tables: Tables, new: set[str], odd: set[str]) -> None:
    assert unknown(tables) == new
    assert suspicious(tables) == odd


def test_no_table_is_in_two_lists() -> None:
    assert len(KNOWN) == sum(
        len(group)
        for group in (
            ERASED,
            HANDLED_ELSEWHERE,
            ERASED_WITH_THE_IDENTITY,
            NOT_PERSONAL,
            RETAINED_AFTER_DELETION,
        )
    )


def test_the_orphan_script_covers_the_same_tables_as_the_deletion() -> None:
    sql = ORPHANS.read_text(encoding="utf-8")
    lists = re.findall(r"-- ELENCO-INIZIO(.*?)-- ELENCO-FINE", sql, re.S)
    expected = {
        table
        for table, column in (*OWNER_TABLES, *LEGACY_OWNER_TABLES)
        # The old radar rows belong to the portal's imports: not touched without asking.
        if column == "owner_id" and not table.startswith("radar_")
    }
    assert len(lists) == 2 and lists[0] == lists[1]
    assert set(re.findall(r"'(\w+)'", lists[0])) == expected


def test_the_orphan_script_cannot_start_by_accident() -> None:
    sql = ORPHANS.read_text(encoding="utf-8")
    assert "attesi constant integer := -1;" in sql
    assert sql.index("is distinct from attesi") < sql.index("delete from")
    assert sql.index("(select count(*) from auth.users) = 0") < sql.index("delete from")


def test_the_migration_that_removes_the_old_triggers_touches_no_row_and_no_table() -> None:
    migration = ROOT / "supabase/migrations/20261123200000_remove_legacy_signup_triggers.sql"
    lines = migration.read_text(encoding="utf-8").splitlines()
    sql = "\n".join(line for line in lines if not line.lstrip().startswith("--")).lower()
    for word in ("delete ", "update ", "insert ", "truncate", "drop table", "alter table"):
        assert word not in sql, word
    assert "NON lanciare prima della conferma" in migration.read_text(encoding="utf-8")
    assert sql.index("raise exception") < sql.index("drop function")
    assert "plan_access_20_pet_limit" in sql
