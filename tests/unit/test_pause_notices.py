"""The pause's calendar, its cap and the purge of expired pauses."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.domain.account_deletion.log import DeletionReason, owner_fingerprint
from packages.core.domain.account_pause import notices
from packages.core.domain.account_pause.models import AccountPause
from packages.infrastructure.persistence.in_memory_account_pause_repository import (
    InMemoryAccountPauseRepository,
)
from packages.infrastructure.persistence.in_memory_deletion_log import (
    InMemoryDeletionLogCopy,
    InMemoryDeletionLogRepository,
)
from packages.shared.config.settings import Settings

OWNER = "11111111-1111-4111-8111-111111111111"
START = datetime(2026, 12, 15, 10, 0, tzinfo=UTC)
END = datetime(2028, 12, 15, 10, 0, tzinfo=UTC)  # 24 months


def test_the_end_is_the_same_day_n_months_later_and_clamps_short_months() -> None:
    assert notices.delete_after(START, 24) == END
    assert notices.delete_after(datetime(2026, 1, 31, tzinfo=UTC), 25) == datetime(
        2028, 2, 29, tzinfo=UTC
    )


def test_the_schedule_has_start_a_yearly_reminder_and_three_warnings() -> None:
    names = [name for name, _ in notices.schedule(START, 24)]
    # P3 after one year; the second would fall in the last 30 days, so it is dropped.
    assert names == ["P1", "P3-1", "P4", "P5", "P6"]
    moments = dict(notices.schedule(START, 24))
    assert moments["P4"] == END - timedelta(days=30)
    assert moments["P5"] == END - timedelta(days=7)
    assert moments["P6"] == END - timedelta(days=1)


def test_a_longer_cap_gets_a_reminder_every_year() -> None:
    names = [name for name, _ in notices.schedule(START, 36)]
    assert names == ["P1", "P3-1", "P3-2", "P4", "P5", "P6"]


def test_only_the_latest_due_notice_goes_out_never_a_burst() -> None:
    assert notices.due_notice(START, 24, START, None) == "P1"
    assert notices.due_notice(START, 24, START + timedelta(days=100), "P1") is None
    assert notices.due_notice(START, 24, START + timedelta(days=366), "P1") == "P3-1"
    # A job that was off for a long time sends the most recent one only.
    assert notices.due_notice(START, 24, END - timedelta(days=2), "P1") == "P5"
    assert notices.due_notice(START, 24, END - timedelta(hours=5), "P5") == "P6"
    assert notices.due_notice(START, 24, END + timedelta(days=1), "P6") is None


def test_a_pause_that_was_never_warned_is_never_erased() -> None:
    late = END + timedelta(days=400)
    assert not notices.erasure_allowed(START, 24, late, last_notice=None, last_notice_at=None)
    assert not notices.erasure_allowed(
        START, 24, late, last_notice="P5", last_notice_at=late - timedelta(days=30)
    )


def test_the_tomorrow_notice_must_be_at_least_20_hours_old() -> None:
    sent = END - timedelta(days=1)
    kwargs = {"last_notice": "P6", "last_notice_at": sent}
    assert not notices.erasure_allowed(START, 24, END - timedelta(hours=1), **kwargs)  # type: ignore[arg-type]
    assert not notices.erasure_allowed(START, 24, sent + timedelta(hours=19), **kwargs)  # type: ignore[arg-type]
    assert notices.erasure_allowed(START, 24, END, **kwargs)  # type: ignore[arg-type]


@pytest.mark.parametrize("value", [0, 6, 11, 37, 120])
def test_the_cap_is_a_setting_that_can_never_be_empty_or_out_of_range(value: int) -> None:
    with pytest.raises(ValueError):
        Settings(_env_file=None, PAUSE_MAX_MONTHS=value)  # type: ignore[call-arg]


def test_the_default_cap_is_24_months() -> None:
    assert Settings(_env_file=None).pause_max_months == 24  # type: ignore[call-arg]


class _Eraser:
    def __init__(self) -> None:
        self.erased: list[str] = []

    def erase_data(self, owner_id: str) -> ErasureReport:
        return ErasureReport(rows_deleted={}, files_removed=0)

    def delete_identity(self, owner_id: str) -> None:
        self.erased.append(owner_id)


class _Subs:
    def set_access_lost_at(self, owner_id: str, value: datetime | None) -> None:
        pass


_Setup = tuple[
    AccountPauseService, InMemoryAccountPauseRepository, InMemoryDeletionLogRepository, _Eraser
]


def _setup(paused_at: datetime = START) -> _Setup:
    repository = InMemoryAccountPauseRepository()
    repository.create(AccountPause(owner_id=OWNER, paused_at=paused_at))
    log_rows = InMemoryDeletionLogRepository()
    log = DeletionLogService(log_rows, InMemoryDeletionLogCopy(), 37, 5)
    eraser = _Eraser()
    service = AccountPauseService(repository, _Subs(), 24, eraser, log)  # type: ignore[arg-type]
    return service, repository, log_rows, eraser


def test_off_it_only_counts() -> None:
    service, repository, _, eraser = _setup()
    repository.record_notice(OWNER, "P6", END - timedelta(days=1))
    report = service.purge_expired(False, END + timedelta(days=1))
    assert (report.enabled, report.due, report.erased) == (False, 1, 0)
    assert eraser.erased == [] and repository.is_paused(OWNER)


def test_an_unwarned_pause_waits_even_when_enabled() -> None:
    service, repository, _, eraser = _setup()
    report = service.purge_expired(True, END + timedelta(days=400))
    assert (report.due, report.waiting_for_notice, report.erased) == (1, 1, 0)
    assert eraser.erased == [] and repository.is_paused(OWNER)


def test_a_warned_expired_pause_is_erased_with_a_register_row_and_removed() -> None:
    service, repository, log_rows, eraser = _setup()
    repository.record_notice(OWNER, "P6", END - timedelta(days=1))

    report = service.purge_expired(True, END + timedelta(hours=1))

    assert (report.erased, report.failed) == (1, 0)
    assert eraser.erased == [OWNER] and not repository.is_paused(OWNER)
    (row,) = log_rows.list_all()
    assert row.owner_hash == owner_fingerprint(OWNER)
    assert row.reason == DeletionReason.PAUSE_EXPIRED


def test_a_pause_still_inside_its_period_is_left_alone() -> None:
    service, repository, _, eraser = _setup()
    repository.record_notice(OWNER, "P6", END - timedelta(days=1))
    report = service.purge_expired(True, END - timedelta(days=100))
    assert (report.due, report.erased) == (0, 0)
    assert eraser.erased == [] and repository.is_paused(OWNER)
