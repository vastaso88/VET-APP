"""Collaudo F33: a weighing of 1900 was accepted. The server ignores what is before 1970 when it
reads; two weighings of a day stay two (as with kittens) and the chat reads the last."""

from datetime import date
from typing import Any

from packages.core.domain.pet_profile.weight_measurement import (
    EARLIEST_WEIGHT_DATE,
    WeightMeasurement,
    weight_history_for_prompt,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseWeightMeasurementRepository,
)

OWNER = "owner-a"


def _weighing(day: date, kg: float = 10.0) -> WeightMeasurement:
    return WeightMeasurement(pet_id="pet-1", measured_at=day, weight_kg=kg)


# --- reading ---------------------------------------------------------------------------------


def test_a_weighing_before_1970_is_not_read() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add(OWNER, _weighing(date(1900, 1, 1), 99.0))
    repository.add(OWNER, _weighing(date(2026, 11, 20), 10.0))

    assert repository.latest_for_pet(OWNER, "pet-1") == _weighing(date(2026, 11, 20), 10.0)
    assert [m.weight_kg for m in repository.recent_for_pet(OWNER, "pet-1", 10)] == [10.0]


def test_a_pet_with_only_a_1900_weighing_has_no_latest_weight() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add(OWNER, _weighing(date(1900, 1, 1)))

    assert repository.latest_for_pet(OWNER, "pet-1") is None


def test_the_earliest_date_is_the_first_of_january_1970() -> None:
    assert EARLIEST_WEIGHT_DATE == date(1970, 1, 1)


class _Query:
    def __init__(self, calls: list[tuple[str, tuple[Any, ...]]]) -> None:
        self.calls = calls

    def __getattr__(self, name: str) -> Any:
        def record(*args: Any, **_: Any) -> _Query:
            self.calls.append((name, args))
            return self

        return record

    def execute(self) -> Any:
        return type("Response", (), {"data": []})()


def test_the_supabase_reads_ask_only_for_weighings_from_1970() -> None:
    calls: list[tuple[str, tuple[Any, ...]]] = []

    class _Client:
        def table(self, _name: str) -> _Query:
            return _Query(calls)

    client: Any = _Client()
    repository = SupabaseWeightMeasurementRepository(client)
    repository.latest_for_pet(OWNER, "pet-1")
    repository.recent_for_pet(OWNER, "pet-1", 5)

    asked = [call for call in calls if call == ("gte", ("measured_at", "1970-01-01"))]
    assert len(asked) == 2


def test_two_weighings_of_a_day_count_once_in_the_history_the_chat_reads() -> None:
    earlier = _weighing(date(2026, 11, 1), 9.0)
    day = date(2026, 11, 20)
    history = weight_history_for_prompt(
        [earlier, _weighing(day, 10.0), _weighing(day, 12.0)], date(2026, 11, 25)
    )

    assert history is not None and "12 kg" in history and "10 kg" not in history


# --- the database script ---------------------------------------------------------------------
