"""Collaudo K09 and PESO.

K09: confirming the age again used to answer 409 `age_already_declared`. The SAME date again is
now answered like the first time; a DIFFERENT date is still refused (a minor must not simply type
another one), and the stored date never changes.

PESO: a weighing dated after tomorrow is refused when it is written (database trigger) and, in any
case, ignored by the server when it looks for "the latest" (so the chat never reads a weight of
2099 as the current one). One day of tolerance, for time zones."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.application.services.age_gate import AgeGateService
from packages.core.domain.age.models import AgeBand
from packages.core.domain.pet_profile.weight_measurement import (
    WeightMeasurement,
    latest_allowed_date,
)
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseWeightMeasurementRepository,
)
from packages.shared.errors.base import AgeRestrictedError

OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"
NOW = datetime(2026, 11, 23, 12, 0, tzinfo=UTC)


def _adult_date() -> date:
    return date(1985, 5, 17)


def _service() -> AgeGateService:
    return AgeGateService(InMemoryAccountAgeRepository())


# --- K09 --------------------------------------------------------------------------------


def test_the_same_confirmation_again_is_answered_like_the_first_time() -> None:
    service = _service()

    first = service.declare(OWNER, _adult_date(), NOW)
    again = service.declare(OWNER, _adult_date(), NOW + timedelta(hours=1))

    assert again == first
    assert again.band == AgeBand.ADULT


def test_a_different_date_is_refused_as_before_and_the_stored_one_is_kept() -> None:
    service = _service()
    service.declare(OWNER, _adult_date(), NOW)

    with pytest.raises(AgeRestrictedError) as refused:
        service.declare(OWNER, date(2012, 5, 17), NOW)

    assert refused.value.code == "age_already_declared"
    assert service.status(OWNER, NOW.date()).band == AgeBand.ADULT


def test_a_minor_repeating_the_same_date_stays_closed_and_cannot_change_it() -> None:
    service = _service()
    minor = date(2016, 3, 3)
    service.declare(OWNER, minor, NOW)

    assert service.declare(OWNER, minor, NOW).band == AgeBand.UNDER_MINIMUM
    with pytest.raises(AgeRestrictedError):
        service.declare(OWNER, date(1990, 3, 3), NOW)


def test_one_owners_confirmation_never_answers_for_another() -> None:
    service = _service()
    service.declare(OWNER, _adult_date(), NOW)

    # "Utente B" declares a different date: B has nothing declared yet, so it is a first time.
    assert service.declare(OTHER, date(2000, 1, 1), NOW).band == AgeBand.ADULT
    with pytest.raises(AgeRestrictedError):
        service.declare(OTHER, _adult_date(), NOW)


def test_the_route_answers_200_twice_for_the_same_date_and_409_for_another(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    client = TestClient(app, raise_server_exceptions=False)
    inner = get_container().auth_provider._inner  # type: ignore[attr-defined]
    monkeypatch.setattr(
        inner, "get_current_user", lambda: AuthenticatedUser(id=OWNER, email="a@example.com")
    )
    body = {"birth_date": "1985-05-17"}

    first = client.post("/account/age", json=body)
    again = client.post("/account/age", json=body)
    different = client.post("/account/age", json={"birth_date": "2010-05-17"})

    assert first.status_code == again.status_code == 200
    assert again.json() == first.json()
    assert different.status_code == 409
    assert different.json()["code"] == "age_already_declared"
    assert client.get("/account/age").json()["band"] == "adult"  # still the first date


# --- PESO -------------------------------------------------------------------------------


def _weighing(measured_at: date, kg: float = 23.0, **extra: Any) -> WeightMeasurement:
    return WeightMeasurement(pet_id="pet-1", measured_at=measured_at, weight_kg=kg, **extra)


def test_tomorrow_is_the_last_date_a_weighing_may_carry() -> None:
    assert latest_allowed_date(NOW) == date(2026, 11, 24)


def test_the_latest_weighing_never_comes_from_the_future() -> None:
    repository = InMemoryWeightMeasurementRepository()
    today = datetime.now(UTC).date()
    repository.add(OWNER, _weighing(today - timedelta(days=3), 23.0))
    repository.add(OWNER, _weighing(today + timedelta(days=400), 99.0))  # 2099-like
    repository.add(OWNER, _weighing(today + timedelta(days=30), 98.0))

    latest = repository.latest_for_pet(OWNER, "pet-1")

    assert latest is not None and latest.weight_kg == 23.0


def test_one_day_of_tolerance_for_time_zones_is_kept() -> None:
    repository = InMemoryWeightMeasurementRepository()
    tomorrow = datetime.now(UTC).date() + timedelta(days=1)
    repository.add(OWNER, _weighing(tomorrow, 24.5, body_condition=3))

    assert repository.latest_for_pet(OWNER, "pet-1") is not None
    assert repository.latest_with_body_condition_for_pet(OWNER, "pet-1") is not None


def test_a_pet_with_only_future_weighings_has_no_latest_weight() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add(OWNER, _weighing(datetime.now(UTC).date() + timedelta(days=10)))

    assert repository.latest_for_pet(OWNER, "pet-1") is None


class _Query:
    def __init__(self, calls: list[tuple[str, tuple[Any, ...]]]) -> None:
        self.calls = calls

    def __getattr__(self, name: str) -> Any:
        def record(*args: Any) -> _Query:
            self.calls.append((name, args))
            return self

        return record

    def execute(self) -> Any:
        return type("Response", (), {"data": []})()


def test_the_supabase_read_asks_only_for_weighings_up_to_tomorrow() -> None:
    calls: list[tuple[str, tuple[Any, ...]]] = []

    class _Client:
        def table(self, _name: str) -> _Query:
            return _Query(calls)

    client: Any = _Client()
    SupabaseWeightMeasurementRepository(client).latest_for_pet(OWNER, "pet-1")

    assert ("lte", ("measured_at", latest_allowed_date().isoformat())) in calls


def test_the_database_script_refuses_future_weighings_with_a_day_of_tolerance() -> None:
    sql = Path("scripts/setup/weight_no_future_dates.sql").read_text(encoding="utf-8").lower()

    assert "create or replace function public.weight_measurement_not_in_future" in sql
    assert "drop trigger if exists weight_dates_30_not_future" in sql
    assert "create trigger weight_dates_30_not_future" in sql
    assert "before insert or update on public.pet_weight_measurements" in sql
    assert "(now() at time zone 'utc')::date + 1" in sql  # tomorrow, UTC
    assert "tg_op = 'insert' or new.measured_at is distinct from old.measured_at" in sql
    assert "check_violation" in sql
    # Old rows are left alone: nothing is updated or deleted by the script itself.
    assert "update public." not in sql and "delete from" not in sql


def test_the_collaudo_twin_runs_the_new_script() -> None:
    from scripts.collaudo import gemello

    assert "scripts/setup/weight_no_future_dates.sql" in gemello.ORDINE_SCHEMA
