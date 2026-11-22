"""QK-07d: the admin panel shows "active", "exotic" and the species group derived from what
is stored (`species`, `is_memorial`), not from three columns nobody writes. Synthetic data
only; the SQL twin of these rules is kept in step by the last two tests."""

import re
from pathlib import Path
from typing import Any

import pytest

from packages.core.domain.pet_profile.directory_traits import (
    is_active,
    is_exotic,
    pet_overview,
    species_group,
    with_directory_fields,
)
from packages.core.domain.pet_profile.species import _LABEL_TO_CANONICAL, normalize_species
from packages.core.domain.radar_places.competences import EXOTIC_GROUPS

MIGRATION = Path("supabase/migrations/20261122100000_admin_directories.sql")
ADMIN = Path("apps/api/routes/admin.py")


@pytest.mark.parametrize(
    ("species", "group", "exotic"),
    [
        ("Cane", "dog", False),
        ("Gatto", "cat", False),
        ("Piccoli mammiferi", "small_mammal", True),
        ("Uccello", "bird", True),
        ("Rettili e anfibi", "reptile_amphibian", True),
        ("Pesce", "fish", True),
        ("Altro", "other", True),
        ("  cane ", "dog", False),  # case and spaces do not matter
        ("dog", "dog", False),  # English values still used by older callers
        ("rabbit", "small_mammal", True),
        ("Drago", "other", True),  # an unplaced free text is "other", as everywhere else
        ("", "unknown", False),  # no species at all
        (None, "unknown", False),
    ],
)
def test_group_and_exotic_come_from_the_species(
    species: str | None, group: str, exotic: bool
) -> None:
    assert species_group(species) == group
    assert is_exotic(species) is exotic


def test_the_group_is_the_projects_own_species_family() -> None:
    for label in _LABEL_TO_CANONICAL:
        assert species_group(label) == normalize_species(label)


def test_exotic_means_the_radars_exotic_groups() -> None:
    for group in EXOTIC_GROUPS:
        assert any(species_group(label) == group for label in _LABEL_TO_CANONICAL)
    assert not any(is_exotic(label) for label in ("dog", "cat", "Cane", "Gatto"))


def test_a_normal_pet_is_active_and_one_in_ricordi_is_not() -> None:
    assert is_active(False) and is_active(None)  # a row with no flag is a normal pet
    assert not is_active(True)
    row = with_directory_fields({"id": "p1", "species": "Cane", "is_memorial": False})
    assert (row["species_group"], row["is_exotic"], row["is_active"]) == ("dog", False, True)
    memorial = with_directory_fields({"id": "p2", "species": "Pesce", "is_memorial": True})
    assert (memorial["species_group"], memorial["is_exotic"], memorial["is_active"]) == (
        "fish",
        True,
        False,
    )
    assert memorial["is_memorial"] is True and memorial["id"] == "p2"  # nothing else is lost


def test_the_overview_counts_are_right() -> None:
    pets: list[dict[str, Any]] = [
        {"species": "Cane", "is_memorial": False},
        {"species": "Cane", "is_memorial": True},
        {"species": "Gatto", "is_memorial": False},
        {"species": "Uccello", "is_memorial": False},
        {"species": "Pesce", "is_memorial": True},
        {"species": "Rettili e anfibi", "is_memorial": None},
        {"species": "", "is_memorial": False},
    ]
    assert pet_overview(pets) == {
        "total": 7,
        "active": 5,  # everyone not in Ricordi
        "exotic": 3,  # bird, fish, reptile (a dog, a cat and "no species" are not)
        "memorial": 2,
        "species": {"dog": 2, "cat": 1, "bird": 1, "fish": 1, "reptile_amphibian": 1, "unknown": 1},
    }
    assert pet_overview([]) == {"total": 0, "active": 0, "exotic": 0, "memorial": 0, "species": {}}


def test_the_overview_reads_only_columns_that_are_written() -> None:
    source = ADMIN.read_text(encoding="utf-8")
    start = source.index('client.table("pet_profiles")')
    select = source[start : source.index(".execute()", start)]
    assert '"id,owner_id,species,is_memorial"' in select
    assert "is_active" not in select and "is_exotic" not in select and "species_group" not in select
    assert '"pet_details": pet_overview(pet_rows)' in source


# ------------------------------------------------- the SQL twin stays in step


def _sql() -> str:
    return " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())


def test_the_sql_species_groups_are_the_python_ones() -> None:
    sql = _sql()
    start = sql.index("create or replace function public.admin_species_bucket(p_species text)")
    body = sql[start : sql.index("$$;", sql.index("$$", start) + 2)]
    pairs = dict(re.findall(r"when '([^']+)' then '([^']+)'", body))
    assert pairs, "the species map was not found in the SQL"
    # every label the SQL knows maps to what Python says, and Python knows no label the SQL lacks
    for label, group in pairs.items():
        assert normalize_species(label) == group, label
    assert set(pairs) == set(_LABEL_TO_CANONICAL) - {"altro", "other"}  # these two fall to `else`
    assert "else 'other'" in body and "then 'unknown'" in body


def test_the_sql_exotic_groups_are_the_radars() -> None:
    sql = _sql()
    lists = re.findall(r"in \(((?:'[a-z_]+',? ?)+)\)", sql)
    exotic_lists = [set(re.findall(r"'([a-z_]+)'", text)) for text in lists if "'bird'" in text]
    assert len(exotic_lists) == 2  # the is_exotic column and the 'exotic' status filter
    assert all(found == set(EXOTIC_GROUPS) for found in exotic_lists)
