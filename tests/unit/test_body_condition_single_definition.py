"""The pet's body condition has ONE definition shared by the profile (codes)
and the weighings (levels 1..5)."""

import re
from pathlib import Path

import pytest

from packages.core.domain.pet_profile.body_condition import (
    BODY_CONDITIONS,
    body_condition_code,
    body_condition_prompt_label,
    body_condition_score,
)
from packages.core.domain.pet_profile.details import describe_for_prompt
from packages.core.domain.pet_profile.models import PetProfile

REPO = Path(__file__).resolve().parents[2]


def test_codes_and_levels_round_trip() -> None:
    assert len(BODY_CONDITIONS) == 5
    for score, code in enumerate(BODY_CONDITIONS, start=1):
        assert body_condition_code(score) == code
        assert body_condition_score(code) == score
        assert body_condition_prompt_label(code)


@pytest.mark.parametrize("score", [None, 0, 6, -1])
def test_levels_outside_one_to_five_have_no_code(score: int | None) -> None:
    assert body_condition_code(score) is None


@pytest.mark.parametrize("code", [None, "", "chubby"])
def test_unknown_codes_have_no_level_or_wording(code: str | None) -> None:
    assert body_condition_score(code) is None
    assert body_condition_prompt_label(code) is None


def test_profile_accepts_exactly_the_shared_codes() -> None:
    for code in BODY_CONDITIONS:
        assert PetProfile(owner_id="o", name="L", species="Cane", body_condition=code)
    with pytest.raises(ValueError):
        PetProfile(owner_id="o", name="L", species="Cane", body_condition="chubby")


def test_prompt_wording_says_where_the_value_comes_from() -> None:
    kwargs = {"neutered": None, "activity_level": None}
    assert describe_for_prompt(body_condition="thin", **kwargs) == [
        "Body condition (owner's estimate): thin"
    ]
    assert describe_for_prompt(
        body_condition="thin", body_condition_as_of="14 ottobre", **kwargs
    ) == ["Body condition (weighed on 14 ottobre): thin"]


def test_sql_check_constraint_lists_the_shared_codes() -> None:
    sql = (REPO / "scripts/setup/supabase_schema.sql").read_text(encoding="utf-8")
    match = re.search(
        r"pet_profiles_body_condition_check\s+check \(body_condition is null"
        r" or body_condition in\s*\(([^)]*)\)",
        sql,
    )
    assert match is not None
    assert tuple(re.findall(r"'([a-z_]+)'", match.group(1))) == BODY_CONDITIONS


def test_dart_enum_lists_the_same_codes_in_the_same_order() -> None:
    dart = (REPO / "apps/mobile_app/lib/features/monitoring/domain/body_condition.dart").read_text(
        encoding="utf-8"
    )
    assert tuple(re.findall(r"^\s+\w+\('([a-z_]+)'\)[,;]", dart, flags=re.M)) == BODY_CONDITIONS
