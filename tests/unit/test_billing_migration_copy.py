"""The billing schema lives in two files that must stay identical.

The migration is the source; `scripts/setup/store_billing.sql` is the copy the
setup instructions ask for. This test fails when they differ (line endings are
ignored) and says which file to copy over which.
"""

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase" / "migrations" / "20261121180000_store_billing.sql"
SETUP_COPY = ROOT / "scripts" / "setup" / "store_billing.sql"


def _normalized(path: Path) -> str:
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")


def check_copy_matches_source(source: Path, copy: Path) -> None:
    """Raises AssertionError, with the fix in the message, if [copy] differs."""
    if _normalized(source) != _normalized(copy):
        raise AssertionError(
            f"{copy.relative_to(ROOT) if copy.is_relative_to(ROOT) else copy} differs from "
            f"{source.relative_to(ROOT) if source.is_relative_to(ROOT) else source}. "
            "The migration is the source: copy "
            "supabase/migrations/20261121180000_store_billing.sql over "
            "scripts/setup/store_billing.sql (never the other way round, and never edit "
            "a migration that was already applied: add a new one instead)."
        )


def test_setup_copy_is_identical_to_the_migration() -> None:
    check_copy_matches_source(MIGRATION, SETUP_COPY)


def test_line_endings_alone_do_not_count_as_a_difference(tmp_path: Path) -> None:
    copy = tmp_path / "store_billing.sql"
    copy.write_bytes(_normalized(MIGRATION).replace("\n", "\r\n").encode("utf-8"))

    check_copy_matches_source(MIGRATION, copy)


def test_an_altered_copy_fails_and_names_the_fix(tmp_path: Path) -> None:
    copy = tmp_path / "store_billing.sql"
    copy.write_text(_normalized(MIGRATION) + "\n-- altered\n", encoding="utf-8")

    with pytest.raises(AssertionError, match="copy supabase/migrations/20261121180000"):
        check_copy_matches_source(MIGRATION, copy)


def test_a_missing_line_in_the_copy_fails(tmp_path: Path) -> None:
    lines = _normalized(MIGRATION).split("\n")
    copy = tmp_path / "store_billing.sql"
    copy.write_text("\n".join(lines[:-3]), encoding="utf-8")

    with pytest.raises(AssertionError):
        check_copy_matches_source(MIGRATION, copy)
