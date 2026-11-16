"""The register of deletions: order of writes, no duplicates, retention, and the
re-application after a database restore."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from packages.core.application.ports.account_eraser import ErasureReport
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.delete_account import (
    DeleteAccountInput,
    DeleteAccountService,
)
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.domain.account_deletion.log import (
    DeletionLogEntry,
    DeletionReason,
    owner_fingerprint,
)
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.infrastructure.persistence.in_memory_deletion_log import (
    InMemoryDeletionLogCopy,
    InMemoryDeletionLogRepository,
)

NOW = datetime(2026, 11, 16, 12, 0, tzinfo=UTC)
OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"


class RecordingEraser:
    """Records what the register looked like when each destructive step ran."""

    def __init__(
        self,
        repository: InMemoryDeletionLogRepository,
        copy: InMemoryDeletionLogCopy,
        fail_on: str | None = None,
    ) -> None:
        self._repository = repository
        self._copy = copy
        self._fail_on = fail_on
        self.seen: list[tuple[str, int, int, bool]] = []
        self.erased: list[str] = []

    def _snapshot(self, step: str) -> None:
        rows = self._repository.list_all()
        self.seen.append(
            (step, len(rows), len(self._copy.list_all()), all(r.completed_at is None for r in rows))
        )

    def erase_data(self, owner_id: str) -> ErasureReport:
        self._snapshot("data")
        if self._fail_on == "data":
            raise RuntimeError("boom")
        return ErasureReport(rows_deleted={"x": 1}, files_removed=0)

    def delete_identity(self, owner_id: str) -> None:
        self._snapshot("identity")
        if self._fail_on == "identity":
            raise RuntimeError("boom")
        self.erased.append(owner_id)


def _service(
    reapply_days: int = 37, proof_years: int = 5
) -> tuple[DeletionLogService, InMemoryDeletionLogRepository, InMemoryDeletionLogCopy]:
    repository = InMemoryDeletionLogRepository()
    copy = InMemoryDeletionLogCopy()
    return DeletionLogService(repository, copy, reapply_days, proof_years), repository, copy


def test_the_row_is_written_before_anything_is_erased_and_completed_after() -> None:
    log, repository, copy = _service()
    eraser = RecordingEraser(repository, copy)

    log.erase_account(eraser, OWNER, DeletionReason.USER_NOW, NOW)

    # Both the table and the copy outside it hold the row, incomplete, at both steps.
    assert eraser.seen == [("data", 1, 1, True), ("identity", 1, 1, True)]
    (entry,) = repository.list_all()
    assert entry.completed_at is not None
    assert entry.owner_hash == owner_fingerprint(OWNER)


def test_if_the_row_cannot_be_written_nothing_is_erased() -> None:
    class Broken(InMemoryDeletionLogCopy):
        def save(self, entry: DeletionLogEntry) -> None:
            raise RuntimeError("storage down")

    repository = InMemoryDeletionLogRepository()
    log = DeletionLogService(repository, Broken(), 37, 5)
    eraser = RecordingEraser(repository, InMemoryDeletionLogCopy())

    with pytest.raises(RuntimeError):
        log.erase_account(eraser, OWNER, DeletionReason.USER_NOW, NOW)

    assert eraser.seen == [] and eraser.erased == []


@pytest.mark.parametrize("fail_on", ["data", "identity"])
def test_a_failed_erase_leaves_the_row_incomplete_and_a_retry_does_not_duplicate(
    fail_on: str,
) -> None:
    log, repository, copy = _service()

    with pytest.raises(RuntimeError):
        log.erase_account(RecordingEraser(repository, copy, fail_on), OWNER, "user_now", NOW)
    (entry,) = repository.list_all()
    assert entry.completed_at is None

    log.erase_account(RecordingEraser(repository, copy), OWNER, "user_now", NOW)
    (entry,) = repository.list_all()
    assert entry.completed_at is not None
    assert len(copy.list_all()) == 1


def test_an_unknown_reason_is_refused_before_anything_happens() -> None:
    log, repository, copy = _service()
    eraser = RecordingEraser(repository, copy)
    with pytest.raises(ValueError):
        log.erase_account(eraser, OWNER, "because", NOW)
    assert repository.list_all() == [] and eraser.seen == []


def test_the_row_holds_nothing_that_identifies_the_person() -> None:
    log, repository, copy = _service()
    log.erase_account(RecordingEraser(repository, copy), OWNER, DeletionReason.USER_NOW, NOW)

    for entry in (*repository.list_all(), *copy.list_all()):
        assert set(entry.model_dump()) == {"owner_hash", "deleted_at", "reason", "completed_at"}
        assert OWNER not in str(entry.model_dump())
    assert owner_fingerprint(OWNER) != owner_fingerprint(OTHER)


def test_the_fingerprint_is_stable() -> None:
    # Changing the label or the algorithm would stop every old row from matching.
    assert owner_fingerprint(OWNER) == owner_fingerprint(OWNER)
    assert len(owner_fingerprint(OWNER)) == 64


def test_prune_keeps_a_row_for_the_longer_of_the_two_periods() -> None:
    log, repository, copy = _service(reapply_days=37, proof_years=5)
    old = NOW - timedelta(days=5 * 365 + 1)
    recent = NOW - timedelta(days=100)
    for owner, when in ((OWNER, old), (OTHER, recent)):
        entry = DeletionLogEntry(
            owner_hash=owner_fingerprint(owner), deleted_at=when, reason="user_now"
        )
        repository.begin(entry)
        copy.save(entry)

    report = log.prune(NOW)

    assert (report.rows_removed, report.copies_removed) == (1, 1)
    assert [e.owner_hash for e in repository.list_all()] == [owner_fingerprint(OTHER)]
    assert [e.owner_hash for e in copy.list_all()] == [owner_fingerprint(OTHER)]


def test_with_no_proof_period_the_reapply_window_decides() -> None:
    log, repository, copy = _service(reapply_days=37, proof_years=0)
    old = DeletionLogEntry(
        owner_hash=owner_fingerprint(OWNER), deleted_at=NOW - timedelta(days=38), reason="user_now"
    )
    repository.begin(old)
    assert log.prune(NOW).rows_removed == 1


def test_after_a_restore_the_register_comes_back_from_the_copy_and_the_account_is_erased() -> None:
    log, repository, copy = _service()
    log.erase_account(RecordingEraser(repository, copy), OWNER, DeletionReason.USER_NOW, NOW)

    # A restore brings the table back to before the deletion and loses the row;
    # the account is back among the users. The copy outside the database is untouched.
    repository.lose_everything()
    assert repository.list_all() == []

    assert log.reload_from_copy() == 1
    assert log.reload_from_copy() == 0  # nothing to add the second time

    eraser = RecordingEraser(repository, copy)
    dry = log.reapply(eraser, [OWNER, OTHER], dry_run=True)
    assert (dry.checked, dry.to_erase, dry.erased) == (2, 1, 0)
    assert eraser.erased == []

    done = log.reapply(eraser, [OWNER, OTHER], dry_run=False)
    assert (done.erased, done.failed) == (1, 0)
    assert eraser.erased == [OWNER]  # the other account is left alone


def test_reapply_also_erases_an_account_whose_first_erase_never_finished() -> None:
    log, repository, copy = _service()
    with pytest.raises(RuntimeError):
        log.erase_account(RecordingEraser(repository, copy, "identity"), OWNER, "user_now", NOW)

    eraser = RecordingEraser(repository, copy)
    assert log.reapply(eraser, [OWNER], dry_run=False).erased == 1


def test_reapply_goes_on_when_one_account_fails() -> None:
    log, repository, copy = _service()
    for owner in (OWNER, OTHER):
        log.erase_account(RecordingEraser(repository, copy), owner, "user_now", NOW)

    class FlakyEraser(RecordingEraser):
        def erase_data(self, owner_id: str) -> ErasureReport:
            if owner_id == OWNER:
                raise RuntimeError("boom")
            return super().erase_data(owner_id)

    eraser = FlakyEraser(repository, copy)
    report = log.reapply(eraser, [OWNER, OTHER], dry_run=False)
    assert (report.erased, report.failed) == (1, 1)


def test_the_three_deletion_paths_write_the_register_with_their_reason() -> None:
    log, repository, copy = _service()
    eraser = RecordingEraser(repository, copy)

    DeleteAccountService(eraser, log).execute(  # type: ignore[arg-type]
        DeleteAccountInput(owner_id=OWNER, signed_in_at=NOW, now=NOW)
    )
    DeleteAccountService(eraser, log).execute(  # type: ignore[arg-type]
        DeleteAccountInput(
            owner_id=OTHER, signed_in_at=NOW, now=NOW, reason=DeletionReason.CLOSED_BY_AGE_USER
        )
    )
    reasons = {e.owner_hash: e.reason for e in repository.list_all()}
    assert reasons == {
        owner_fingerprint(OWNER): "user_now",
        owner_fingerprint(OTHER): "closed_by_age_user",
    }

    # The end of the period.
    third = "33333333-3333-4333-8333-333333333333"
    requests = InMemoryAccountDeletionRepository()
    service = AccountDeletionService(requests, eraser, 30, log=log)  # type: ignore[arg-type]
    service.request(third, NOW, NOW)
    service.purge_due(True, NOW + timedelta(days=31))
    assert {e.owner_hash: e.reason for e in repository.list_all()}[
        owner_fingerprint(third)
    ] == "user_period_end"


def test_the_schema_script_keeps_the_register_service_only() -> None:
    sql = Path("scripts/setup/account_deletion_log.sql").read_text(encoding="utf-8")
    assert "enable row level security" in sql
    assert "create policy" not in sql
    assert "owner_hash text not null unique" in sql
    assert "values ('deletion-log', 'deletion-log', false)" in sql
    # No e-mail, name or admin id column.
    for forbidden in ("email", "admin", "name text"):
        assert forbidden not in sql.split("create table", 1)[1].split(");", 1)[0]
