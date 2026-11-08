"""The owner's day: the per-owner daily counters start over at midnight on the
clock of the owner's phone (the offset the app sends), not at midnight UTC.

The model token budgets stay on the provider's day, UTC: only the owner's own
counters (questions, photos, dictations, summaries) move.
"""

from __future__ import annotations

from collections.abc import Callable, Iterator
from datetime import UTC, date, datetime, timedelta

import pytest

from packages.core.application.services.llm_budget import LlmBudget
from packages.core.domain.llm_usage.models import next_owner_day_start, owner_day
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.shared.user_clock import (
    current_utc_offset_minutes,
    parse_utc_offset_minutes,
    reset_utc_offset_minutes,
    set_utc_offset_minutes,
)

MODEL = "main-model"

SetOffset = Callable[[int], None]


def utc(
    year: int, month: int, day: int, hour: int = 0, minute: int = 0, second: int = 0
) -> datetime:
    return datetime(year, month, day, hour, minute, second, tzinfo=UTC)


class Clock:
    def __init__(self, now: datetime) -> None:
        self.now = now

    def __call__(self) -> datetime:
        return self.now


def _budget(clock: Clock, repository: InMemoryLlmUsageRepository | None = None) -> LlmBudget:
    return LlmBudget(
        repository or InMemoryLlmUsageRepository(),
        budgets={MODEL: 1_000_000},
        default_budget=1_000_000,
        clock=clock,
        refresh_seconds=3600.0,
    )


@pytest.fixture
def offset() -> Iterator[SetOffset]:
    """Sets the owner's offset for one test and puts it back."""
    tokens = []

    def set_offset(minutes: int) -> None:
        tokens.append(set_utc_offset_minutes(minutes))

    yield set_offset
    for token in reversed(tokens):
        reset_utc_offset_minutes(token)


# --- the day an instant belongs to -------------------------------------------


@pytest.mark.parametrize(
    ("offset_minutes", "instant", "expected"),
    [
        # Rome in winter, UTC+1: 23:00 UTC is already midnight there.
        (60, utc(2026, 12, 10, 22, 59, 59), date(2026, 12, 10)),
        (60, utc(2026, 12, 10, 23, 0, 0), date(2026, 12, 11)),
        # Rome in summer, UTC+2.
        (120, utc(2026, 7, 10, 21, 59, 59), date(2026, 7, 10)),
        (120, utc(2026, 7, 10, 22, 0, 0), date(2026, 7, 11)),
        # Kiritimati, UTC+14: the first place to see a new day.
        (840, utc(2026, 12, 10, 9, 59, 59), date(2026, 12, 10)),
        (840, utc(2026, 12, 10, 10, 0, 0), date(2026, 12, 11)),
        # Baker Island, UTC-12: the last one.
        (-720, utc(2026, 12, 11, 11, 59, 59), date(2026, 12, 10)),
        (-720, utc(2026, 12, 11, 12, 0, 0), date(2026, 12, 11)),
        # New York in winter, UTC-5: the evening of the 10th is still the 10th.
        (-300, utc(2026, 12, 11, 4, 59, 59), date(2026, 12, 10)),
        (-300, utc(2026, 12, 11, 5, 0, 0), date(2026, 12, 11)),
        # A half-hour and a three-quarter zone (India, Nepal).
        (330, utc(2026, 12, 10, 18, 29, 59), date(2026, 12, 10)),
        (330, utc(2026, 12, 10, 18, 30, 0), date(2026, 12, 11)),
        (345, utc(2026, 12, 10, 18, 14, 59), date(2026, 12, 10)),
        (345, utc(2026, 12, 10, 18, 15, 0), date(2026, 12, 11)),
        # No offset: UTC, as before.
        (0, utc(2026, 12, 10, 23, 59, 59), date(2026, 12, 10)),
        (0, utc(2026, 12, 11, 0, 0, 0), date(2026, 12, 11)),
    ],
)
def test_the_day_changes_at_midnight_on_the_owners_clock(
    offset_minutes: int, instant: datetime, expected: date
) -> None:
    assert owner_day(instant, offset_minutes) == expected


def test_the_day_crosses_the_end_of_the_year_and_of_february() -> None:
    assert owner_day(utc(2026, 12, 31, 23, 30), 60) == date(2027, 1, 1)
    assert owner_day(utc(2027, 2, 28, 23, 30), 60) == date(2027, 3, 1)
    assert owner_day(utc(2028, 2, 28, 23, 30), 60) == date(2028, 2, 29)  # leap year


@pytest.mark.parametrize("offset_minutes", [-720, -300, 0, 60, 120, 330, 345, 840])
def test_the_next_reset_is_a_local_midnight_after_the_instant(offset_minutes: int) -> None:
    instant = utc(2026, 12, 10, 13, 7, 41)

    reset = next_owner_day_start(instant, offset_minutes)

    assert reset > instant
    assert reset - instant <= timedelta(days=1)
    local_reset = reset + timedelta(minutes=offset_minutes)
    assert (local_reset.hour, local_reset.minute, local_reset.second) == (0, 0, 0)
    assert owner_day(reset, offset_minutes) == owner_day(instant, offset_minutes) + timedelta(
        days=1
    )
    assert owner_day(reset - timedelta(seconds=1), offset_minutes) == owner_day(
        instant, offset_minutes
    )


def test_the_reset_with_no_offset_is_midnight_utc() -> None:
    assert next_owner_day_start(utc(2026, 12, 10, 13), 0) == utc(2026, 12, 11)


# --- what the app may send ---------------------------------------------------


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("60", 60),
        ("+60", 60),
        ("-300", -300),
        ("0", 0),
        ("-0", 0),
        (" 120 ", 120),
        ("840", 840),
        ("-720", -720),
        ("345", 345),
        ("330", 330),
    ],
)
def test_a_believable_offset_is_taken(raw: str, expected: int) -> None:
    assert parse_utc_offset_minutes(raw) == expected


@pytest.mark.parametrize(
    "raw",
    [
        None,
        "",
        " ",
        "abc",
        "60.5",
        "1e2",
        "+-60",
        "60 minutes",
        "845",  # beyond UTC+14:00
        "-735",  # beyond UTC-12:00
        "9999",
        "-9999",
        "10000",
        "61",  # not a multiple of 15
        "7",
        "٦٠",  # not ASCII digits
        "60\n60",
    ],
)
def test_anything_not_believable_means_utc(raw: str | None) -> None:
    assert parse_utc_offset_minutes(raw) == 0


def test_outside_a_request_the_offset_is_utc() -> None:
    assert current_utc_offset_minutes() == 0


# --- the counters ------------------------------------------------------------


def test_the_questions_start_over_at_the_owners_midnight_not_at_utc_midnight(
    offset: SetOffset,
) -> None:
    offset(60)  # Rome in winter
    clock = Clock(utc(2026, 12, 10, 22, 30))  # 23:30 on the 10th in Rome
    budget = _budget(clock)

    first = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=2)
    second = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=2)
    third = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=2)
    assert (first, second) == (None, None)
    assert third is not None and third.reason == "user_limit"

    clock.now = utc(2026, 12, 10, 23, 0)  # midnight in Rome: UTC is still the 10th
    fresh = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=2)

    assert fresh is None, "a new day started in Rome, even if it is still the 10th in UTC"


def test_with_no_offset_the_day_still_changes_at_utc_midnight(offset: SetOffset) -> None:
    offset(0)
    clock = Clock(utc(2026, 12, 10, 23, 59, 59))
    budget = _budget(clock)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is not None

    clock.now = utc(2026, 12, 11, 0, 0, 0)

    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is None


def test_the_wait_is_the_time_to_the_owners_own_midnight(offset: SetOffset) -> None:
    offset(60)
    clock = Clock(utc(2026, 12, 10, 20, 0, 0))  # 21:00 in Rome: three hours to midnight
    budget = _budget(clock)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    denial = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    assert denial is not None
    assert denial.retry_after_seconds == 3 * 3600


def test_the_wait_is_never_under_a_minute(offset: SetOffset) -> None:
    offset(60)
    clock = Clock(utc(2026, 12, 10, 22, 59, 50))  # ten seconds to midnight in Rome
    budget = _budget(clock)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    denial = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    assert denial is not None
    assert denial.retry_after_seconds == 60


def test_just_after_midnight_the_wait_is_almost_a_whole_day(offset: SetOffset) -> None:
    offset(-300)  # New York
    clock = Clock(utc(2026, 12, 11, 5, 0, 1))  # one second past midnight there
    budget = _budget(clock)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    denial = budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)

    assert denial is not None
    assert denial.retry_after_seconds == 24 * 3600 - 1


def test_the_photo_dictation_and_summary_counters_follow_the_owners_day_too(
    offset: SetOffset,
) -> None:
    offset(120)
    clock = Clock(utc(2026, 7, 10, 21, 0))  # 23:00 on the 10th in Rome in summer
    budget = _budget(clock)

    for kind in ("vision", "dictation", "summary"):
        assert budget.admit_feature(owner_id="anna", kind=kind, limit=1) is None
        denied = budget.admit_feature(owner_id="anna", kind=kind, limit=1)
        assert denied is not None and denied.reason == f"{kind}_limit"
        assert denied.retry_after_seconds == 3600

    clock.now = utc(2026, 7, 10, 22, 0)  # midnight in Rome
    for kind in ("vision", "dictation", "summary"):
        assert budget.admit_feature(owner_id="anna", kind=kind, limit=1) is None


def test_the_count_is_stored_under_the_owners_local_date(offset: SetOffset) -> None:
    repository = InMemoryLlmUsageRepository()
    clock = Clock(utc(2026, 12, 10, 23, 30))  # the 11th in Rome
    offset(60)

    _budget(clock, repository).admit(owner_id="anna", models=[MODEL], user_daily_limit=5)

    assert ("anna", date(2026, 12, 11)) in repository._user_usage  # noqa: SLF001
    assert ("anna", date(2026, 12, 10)) not in repository._user_usage  # noqa: SLF001


def test_two_owners_on_different_clocks_never_share_a_counter(offset: SetOffset) -> None:
    repository = InMemoryLlmUsageRepository()
    clock = Clock(utc(2026, 12, 10, 23, 30))
    budget = _budget(clock, repository)

    offset(60)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is not None

    assert budget.admit(owner_id="bruno", models=[MODEL], user_daily_limit=1) is None


def test_the_models_token_budget_stays_on_the_providers_utc_day(offset: SetOffset) -> None:
    offset(840)  # Kiritimati: already the 11th there, still the 10th in UTC
    clock = Clock(utc(2026, 12, 10, 12, 0))
    budget = _budget(clock)

    assert budget.retry_after_seconds([MODEL]) == 12 * 3600, "the provider's quota resets at UTC"


def test_a_summer_time_change_follows_the_phone_on_its_next_request(offset: SetOffset) -> None:
    # Europe/Rome changes on the night of 2027-03-28: UTC+1 until 01:00 UTC,
    # UTC+2 after. The phone reports the offset that holds now, and the day
    # follows it on the next request.
    clock = Clock(utc(2027, 3, 27, 22, 30))
    budget = _budget(clock)
    offset(60)
    budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1)
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is not None  # 27th

    clock.now = utc(2027, 3, 27, 23, 0)  # midnight in Rome, still winter time
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is None  # 28th
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is not None

    clock.now = utc(2027, 3, 28, 21, 59)  # 23:59 on the 28th in summer time (UTC+2)
    offset(120)
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is not None  # 28th

    clock.now = utc(2027, 3, 28, 22, 0)  # midnight in summer time
    assert budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=1) is None  # 29th


def test_a_forged_offset_can_only_pick_among_a_few_dates_never_unlimited(offset: SetOffset) -> None:
    # The honest residual risk: choosing an offset picks one of the (at most
    # three) calendar dates alive anywhere on Earth at that instant, so the
    # day's allowance can be drawn from at most three counters, never more.
    clock = Clock(utc(2026, 12, 10, 10, 0))
    budget = _budget(clock)
    admitted = 0
    for minutes in range(-720, 841, 15):
        offset(minutes)
        for _ in range(3):
            if budget.admit(owner_id="anna", models=[MODEL], user_daily_limit=2) is None:
                admitted += 1

    assert admitted == 2 * 3
