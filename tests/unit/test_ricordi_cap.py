"""The cap on pets kept in Ricordi (owner decision 2026-11-16: 30, as a setting).

Pets in Ricordi do not take a place of the plan, so something has to bound what an
account can pile up there. The number is a setting (MEMORIAL_PETS_MAX), not a
literal spread over the code: the backend reads it, writes it into the database
rule (plan_access_config.max_memorial_pets, enforced on the app's direct writes
by scripts/setup/plan_access_rules.sql) and reports it on /subscription/status.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any

import pytest

from apps.api.schemas.pets import CreatePetProfileRequest
from packages.bootstrap.container import resolve_memorial_pets_max
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionOutput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.subscription.direct_writes import MEMORIALS_LIMIT_KIND
from packages.core.domain.subscription.limits import DEFAULT_MAX_MEMORIAL_PETS
from packages.infrastructure.persistence.in_memory_plan_access_store import (
    InMemoryPlanAccessStore,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)
from packages.shared.config.settings import Settings

ROOT = Path(__file__).resolve().parents[2]


def _status(
    owner: str = "owner-a",
    *,
    cap: int | None = None,
    store: InMemoryPlanAccessStore | None = None,
    test_plan: str | None = None,
) -> GetOrCreateSubscriptionOutput:
    extra: dict[str, Any] = {} if cap is None else {"max_memorial_pets": cap}
    service = GetOrCreateSubscriptionService(
        InMemorySubscriptionRepository(),
        frozenset(),
        test_plan=test_plan,
        access_sync=PlanAccessSync(store) if store is not None else None,
        **extra,
    )
    return service.execute(
        GetOrCreateSubscriptionInput(owner_id=owner, email=f"{owner}@example.com")
    )


# --- the setting ----------------------------------------------------------------------------


def test_the_default_is_thirty() -> None:
    assert DEFAULT_MAX_MEMORIAL_PETS == 30
    assert resolve_memorial_pets_max("") == 30
    assert resolve_memorial_pets_max("   ") == 30


def test_the_setting_is_read_from_the_environment_and_changes_the_cap() -> None:
    settings = Settings(_env_file=None, MEMORIAL_PETS_MAX="45")  # type: ignore[call-arg]

    assert resolve_memorial_pets_max(settings.memorial_pets_max) == 45
    assert Settings(_env_file=None).memorial_pets_max == ""  # type: ignore[call-arg]


@pytest.mark.parametrize("raw", ["0", "-3", "abc", "2.5", "10 pets"])
def test_a_value_that_is_not_a_whole_number_above_zero_falls_back_to_the_default(
    raw: str, caplog: pytest.LogCaptureFixture
) -> None:
    with caplog.at_level(logging.WARNING):
        assert resolve_memorial_pets_max(raw) == DEFAULT_MAX_MEMORIAL_PETS

    # Said once, without echoing the value.
    assert any("MEMORIAL_PETS_MAX" in record.getMessage() for record in caplog.records)
    assert not any(raw in record.getMessage() for record in caplog.records)


def test_zero_never_means_no_cap_by_accident() -> None:
    assert resolve_memorial_pets_max("0") != 0
    assert resolve_memorial_pets_max("-1") > 0


@pytest.mark.parametrize("raw, expected", [("1", 1), (" 12 ", 12), ("500", 500)])
def test_any_whole_number_above_zero_is_accepted(raw: str, expected: int) -> None:
    assert resolve_memorial_pets_max(raw) == expected


# --- what the backend tells the app ------------------------------------------------------------


def test_the_status_carries_the_cap_so_the_app_keeps_no_copy() -> None:
    assert _status().max_memorial_pets == DEFAULT_MAX_MEMORIAL_PETS
    assert _status(cap=12).max_memorial_pets == 12
    assert _status(cap=12).model_dump()["max_memorial_pets"] == 12


def test_the_cap_is_reported_during_the_public_test_too() -> None:
    assert _status(cap=7, test_plan="pro").max_memorial_pets == 7


def test_user_b_gets_the_same_cap_whatever_user_a_has_in_ricordi() -> None:
    # The cap is a deployment fact, not a per-account one: it reads nothing of the
    # accounts, so what A keeps in Ricordi cannot change what B is told or may do.
    a = _status("owner-a", cap=9)
    b = _status("owner-b", cap=9)
    assert a.max_memorial_pets == b.max_memorial_pets == 9


# --- the database copy ----------------------------------------------------------------------


def test_the_cap_reaches_the_database_at_a_status_check() -> None:
    store = InMemoryPlanAccessStore()

    _status(cap=12, store=store)

    assert store.max_memorial_pets == 12


def test_changing_the_setting_is_written_again_and_the_same_value_only_once() -> None:
    store = InMemoryPlanAccessStore()
    sync = PlanAccessSync(store)

    for _ in range(4):
        sync.sync(owner_id="o", is_developer=False, test_plan=None, max_memorial_pets=30)
    writes_after_same_value = store.writes
    sync.sync(owner_id="o", is_developer=False, test_plan=None, max_memorial_pets=40)

    assert writes_after_same_value == 3  # test plan, the cap, the account's exemption
    assert store.writes == 4
    assert store.max_memorial_pets == 40


def test_a_caller_that_does_not_say_leaves_the_database_cap_alone() -> None:
    store = InMemoryPlanAccessStore()
    store.max_memorial_pets = 55

    PlanAccessSync(store).sync(owner_id="o", is_developer=False, test_plan=None)

    assert store.max_memorial_pets == 55


class _StoreWithoutTheColumn(InMemoryPlanAccessStore):
    """plan_access_rules.sql not run again yet: the cap write fails."""

    def __init__(self) -> None:
        super().__init__()
        self.attempts = 0

    def set_max_memorial_pets(self, cap: int) -> None:
        self.attempts += 1
        raise RuntimeError("column max_memorial_pets does not exist")


def test_a_database_without_the_column_never_changes_the_owners_answer() -> None:
    store = _StoreWithoutTheColumn()

    first = _status(cap=12, store=store)
    second = _status(cap=12, store=store)

    assert first.has_access and second.has_access
    assert first.max_memorial_pets == 12  # the app still gets the number
    assert store.test_plan is None and store.writes >= 1  # the other writes went through


def test_the_failed_cap_write_is_tried_again_at_the_next_check() -> None:
    store = _StoreWithoutTheColumn()
    sync = PlanAccessSync(store)

    for _ in range(3):
        sync.sync(owner_id="o", is_developer=False, test_plan=None, max_memorial_pets=12)

    assert store.attempts == 3


# --- the backend never moves a pet to Ricordi -----------------------------------------------------


def test_the_backend_has_no_way_to_create_or_move_a_pet_into_ricordi() -> None:
    # The app writes `is_memorial` straight to the database, where the rule below
    # applies. The backend only reads it: no request carries it, and saving a
    # profile does not write it, so there is nothing to count on this side.
    assert "is_memorial" not in CreatePetProfileRequest.model_fields
    pet = PetProfile(owner_id="owner-a", name="Moka", species="Cane", is_memorial=True)
    assert "is_memorial" not in pet.model_dump()


# --- the database rule (the app's direct writes) --------------------------------------------------


def _script() -> str:
    return (ROOT / "scripts/setup/plan_access_rules.sql").read_text(encoding="utf-8")


def _code() -> str:
    return "\n".join(line for line in _script().splitlines() if not line.lstrip().startswith("--"))


def _memorial_function() -> str:
    match = re.search(r"function public\.plan_access_memorial_limit\(\).*?\$\$;", _code(), re.S)
    assert match is not None
    return match.group(0)


def test_the_cap_lives_in_the_config_row_the_backend_writes() -> None:
    code = _code()

    assert re.search(
        r"alter table public\.plan_access_config\s+add column if not exists max_memorial_pets "
        rf"integer not null default {DEFAULT_MAX_MEMORIAL_PETS}\s+check \(max_memorial_pets > 0\);",
        code,
    )
    function = _memorial_function()
    assert "from public.plan_access_config c where c.id = 1" in function
    # The comparison is against the configured number, never a literal.
    assert "current_count >= cap" in function
    assert not re.search(r"current_count\s*>=\s*\d", function)
    # The only literal is the fallback for a missing row, taken from the constant.
    assert f"cap := coalesce(cap, {DEFAULT_MAX_MEMORIAL_PETS});" in function


def test_only_a_pet_that_enters_ricordi_is_counted() -> None:
    function = _memorial_function()

    assert "if not coalesce(new.is_memorial, false) then\n        return new;" in function
    assert "if coalesce(old.is_memorial, false) then\n            return new;" in function
    # An upsert of a pet that exists already is decided by the update that follows.
    assert "where p.id = new.id and p.owner_id = new.owner_id" in function


def test_user_b_is_counted_apart_from_user_a() -> None:
    function = _memorial_function()

    # Only the writer's own pets in Ricordi, without the row being written, and
    # the lock is per owner so two accounts never wait for each other.
    assert "where p.owner_id = new.owner_id and p.is_memorial and p.id <> new.id" in function
    assert "hashtextextended('vetapp_memorial_limit:' || new.owner_id, 0)" in function


def test_the_backend_and_the_database_are_not_held_back_by_the_rule() -> None:
    # service_role and the SQL editor (no token) pass, like the other plan rules.
    assert "if coalesce(auth.role(), '') not in ('authenticated', 'anon') then" in (
        _memorial_function()
    )


def test_the_refusal_is_the_one_the_app_already_handles_with_its_own_kind() -> None:
    function = _memorial_function()

    assert "errcode = 'PT403'" in function
    assert "message = 'plan_limit_reached'" in function
    assert f"detail = '{MEMORIALS_LIMIT_KIND}'" in function
    assert "hint = cap::text" in function
    assert MEMORIALS_LIMIT_KIND == "memorials"


def test_the_trigger_runs_on_insert_and_update_between_the_plan_rules_and_ricordi() -> None:
    code = _code()

    assert re.search(
        r"create trigger plan_access_30_memorial_limit\s+before insert or update on "
        r"public\.pet_profiles\s+for each row execute function "
        r"public\.plan_access_memorial_limit\(\);",
        code,
    )
    # Triggers fire in name order: the plan gate, the pets limit, this one, then
    # the Ricordi read-only rule, whose name sorts after "plan_access_".
    names = ["plan_access_10_gate", "plan_access_20_pet_limit", "plan_access_30_memorial_limit"]
    assert names == sorted(names)
    assert names[-1] < "ricordi_10_profile_read_only"


def test_the_function_is_not_callable_by_the_app() -> None:
    assert (
        "revoke all on function public.plan_access_memorial_limit() "
        "from public, anon, authenticated;" in _code()
    )
