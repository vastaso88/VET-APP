from datetime import UTC, datetime, timedelta

from packages.core.domain.account_deletion.notices import (
    CONFIRMED,
    TOMORROW,
    WEEK_LEFT,
    due_waiting_notice,
)

REQUESTED = datetime(2026, 12, 1, 10, 0, tzinfo=UTC)
PURGE = REQUESTED + timedelta(days=30)


def _due(days_after: float, last: str | None) -> str | None:
    return due_waiting_notice(REQUESTED, PURGE, REQUESTED + timedelta(days=days_after), last)


def test_the_confirmation_goes_out_at_once_and_only_once() -> None:
    assert _due(0, None) == CONFIRMED
    assert _due(0.5, CONFIRMED) is None


def test_the_week_and_the_day_before_follow_the_real_erasure_date() -> None:
    assert _due(22.9, CONFIRMED) is None
    assert _due(23, CONFIRMED) == WEEK_LEFT
    assert _due(28.9, WEEK_LEFT) is None
    assert _due(29, WEEK_LEFT) == TOMORROW
    assert _due(29.5, TOMORROW) is None


def test_a_late_job_sends_one_message_not_a_burst() -> None:
    assert _due(29.5, CONFIRMED) == TOMORROW
    assert _due(29.5, None) == TOMORROW


def test_a_short_grace_period_skips_notices_that_would_come_before_the_request() -> None:
    purge = REQUESTED + timedelta(days=5)
    assert due_waiting_notice(REQUESTED, purge, REQUESTED, None) == CONFIRMED
    assert (
        due_waiting_notice(REQUESTED, purge, REQUESTED + timedelta(days=4), CONFIRMED) == TOMORROW
    )
    # No "a week left" when the whole period is shorter than a week.
    assert due_waiting_notice(REQUESTED, purge, REQUESTED + timedelta(days=3), CONFIRMED) is None
