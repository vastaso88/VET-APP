"""Moving a pet to Ricordi stays possible WITHOUT a plan (owner decision 2026-11-16).

Someone who loses an animal after the trial must not meet a paywall to stop its
reminders, medicines and birthday wishes. The database (the app writes
`pet_profiles` directly) lets through only that one change; everything else is
refused as before, bringing the pet back among the animals included. The SQL is run
by hand on Supabase, so what must be true of it is checked here as text, and the
alignment with what the app writes in the Flutter test
(apps/mobile_app/test/pets/memorial_move_without_plan_test.dart).
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from packages.core.domain.subscription.direct_writes import (
    GATED_TABLES,
    MEMORIAL_MOVE_TABLE,
    SUBSCRIPTION_REQUIRED_CODE,
    SUBSCRIPTION_REQUIRED_SQLSTATE,
)

ROOT = Path(__file__).resolve().parents[2]


def _code() -> str:
    text = (ROOT / "scripts/setup/plan_access_rules.sql").read_text(encoding="utf-8")
    return "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))


def _move_gate() -> str:
    match = re.search(r"function public\.plan_access_move_gate\(\).*?\$\$;", _code(), re.S)
    assert match is not None
    return match.group(0)


def test_the_exception_is_for_the_pet_profile_table_only() -> None:
    assert MEMORIAL_MOVE_TABLE == "pet_profiles"
    assert MEMORIAL_MOVE_TABLE in GATED_TABLES  # still gated: the exception is inside the gate
    code = _code()
    for table in GATED_TABLES:
        function = "plan_access_move_gate" if table == MEMORIAL_MOVE_TABLE else "plan_access_gate"
        assert re.search(
            rf"create trigger plan_access_10_gate\s+before insert or update on public\.{table}\s+"
            rf"for each row execute function public\.{function}\(\);",
            code,
        ), table


def test_someone_with_a_plan_or_the_backend_is_never_held_back_by_it() -> None:
    gate = _move_gate()

    assert "if coalesce(auth.role(), '') not in ('authenticated', 'anon') then" in gate
    assert "if public.caller_can_write() then\n        return new;" in gate


def test_without_a_plan_only_the_move_into_ricordi_passes() -> None:
    gate = _move_gate()

    # The new row is in Ricordi and carries the date of the loss...
    assert (
        "if coalesce(new.is_memorial, false) and coalesce(new.memorial_date_label, '') <> ''"
        in (gate)
    )
    # ...and the row was not in Ricordi before: only false -> true.
    assert "if tg_op = 'UPDATE' then\n            if not coalesce(old.is_memorial, false) then" in (
        gate
    )
    # Everything else ends in the refusal, the last statement of the function.
    assert re.search(r"raise exception using\s.*?;\s*end;\s*\$\$;$", gate, re.S)


def test_bringing_a_pet_back_stays_refused_without_a_plan() -> None:
    gate = _move_gate()
    move_branch = gate.index("if coalesce(new.is_memorial, false) and")
    refusal = gate.index("raise exception")

    # Four ways out with "return new": the backend/editor guard and "has a plan" come
    # first; the two that let a row through without a plan are both INSIDE the branch
    # that needs the new row to be in Ricordi. The return among the animals
    # (is_memorial true -> false) has a new row that is not in Ricordi, so it never
    # enters the branch and ends in the refusal.
    assert gate[:move_branch].count("return new;") == 2
    assert gate[move_branch:refusal].count("return new;") == 2
    assert gate.count("return new;") == 4


def test_a_move_without_the_date_of_the_loss_is_refused() -> None:
    assert "coalesce(new.memorial_date_label, '') <> ''" in _move_gate()


def test_a_new_pet_cannot_be_born_in_ricordi_without_a_plan() -> None:
    gate = _move_gate()

    # An insert passes only when it is an upsert of a profile that exists already, of
    # this owner and not yet in Ricordi (the update that follows decides). A row that
    # does not exist yet falls through to the refusal.
    assert (
        "elsif exists (\n            select 1\n            from public.pet_profiles p\n"
        "            where p.id = new.id and p.owner_id = new.owner_id and not p.is_memorial\n"
        "        ) then\n            return new;"
    ) in gate


def test_it_answers_with_the_same_refusal_as_every_other_write() -> None:
    gate = _move_gate()

    assert f"errcode = '{SUBSCRIPTION_REQUIRED_SQLSTATE}'" in gate
    assert f"message = '{SUBSCRIPTION_REQUIRED_CODE}'" in gate


def test_the_update_policy_lets_a_pet_in_ricordi_pass_and_nothing_else_changes() -> None:
    code = _code()

    # The restrictive policy sees only the new row: the pet profile may be in Ricordi
    # after the write, the trigger decides whether it just moved.
    assert re.search(
        r"create policy plan_access_update\s+on public\.pet_profiles\s+as restrictive\s+"
        r"for update\s+to authenticated\s+using \(true\)\s+"
        r"with check \(public\.caller_can_write\(\) or is_memorial\);",
        code,
    )
    # Inserting a pet stays strict (a pet cannot be born without a plan), and so does
    # every other table.
    assert re.search(
        r"create policy plan_access_insert\s+on public\.pet_profiles\s+as restrictive\s+"
        r"for insert\s+to authenticated\s+with check \(public\.caller_can_write\(\)\);",
        code,
    )
    for table in GATED_TABLES:
        if table == MEMORIAL_MOVE_TABLE:
            continue
        assert re.search(
            rf"create policy plan_access_update\s+on public\.{table}\s+as restrictive\s+"
            rf"for update\s+to authenticated\s+using \(true\)\s+"
            rf"with check \(public\.caller_can_write\(\)\);",
            code,
        ), table


@pytest.mark.parametrize("table", [t for t in GATED_TABLES if t != MEMORIAL_MOVE_TABLE])
def test_nothing_else_the_app_writes_has_an_exception(table: str) -> None:
    code = _code()

    assert re.search(
        rf"create trigger plan_access_10_gate\s+before insert or update on public\.{table}\s+"
        rf"for each row execute function public\.plan_access_gate\(\);",
        code,
    )
    assert "is_memorial" not in re.search(
        r"function public\.plan_access_gate\(\).*?\$\$;", code, re.S
    ).group(0)  # type: ignore[union-attr]


def test_the_cap_and_the_plan_limit_still_apply_to_a_move_without_a_plan() -> None:
    code = _code()

    # The move takes no place of the plan (the pets limit returns for a pet in
    # Ricordi), but Ricordi itself has its cap, which the plan does not change.
    assert "create trigger plan_access_30_memorial_limit" in code
    assert "if not coalesce(new.is_memorial, false) then\n        return new;" in code
    # The plan gate (10) runs before the pets limit (20) and the cap (30).
    names = ["plan_access_10_gate", "plan_access_20_pet_limit", "plan_access_30_memorial_limit"]
    assert names == sorted(names)
