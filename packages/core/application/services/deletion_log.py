"""Writing, keeping and re-applying the register of deletions."""

from __future__ import annotations

import logging
from collections.abc import Iterable
from datetime import datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_eraser import AccountEraser, ErasureReport
from packages.core.application.ports.deletion_log import DeletionLogCopy, DeletionLogRepository
from packages.core.domain.account_deletion.log import (
    DeletionLogEntry,
    DeletionReason,
    owner_fingerprint,
)
from packages.core.domain.common.entity import utc_now

logger = logging.getLogger(__name__)


class PruneReport(BaseModel):
    rows_removed: int
    copies_removed: int


class ReapplyReport(BaseModel):
    """Counts only."""

    dry_run: bool
    checked: int
    to_erase: int
    erased: int = 0
    failed: int = 0


class DeletionLogService:
    """[reapply_days]: how long a row is needed to apply the erasure again,
    which is as long as a backup that may still hold the account exists, plus 30
    days. [proof_years]: how long it is kept as proof that the erasure was done.
    A row is kept for the longer of the two."""

    def __init__(
        self,
        repository: DeletionLogRepository,
        copy: DeletionLogCopy,
        reapply_days: int,
        proof_years: int,
    ) -> None:
        self._repository = repository
        self._copy = copy
        self._reapply_days = reapply_days
        self._proof_years = proof_years

    @property
    def retention(self) -> timedelta:
        return timedelta(days=max(self._reapply_days, self._proof_years * 365))

    # -- writing --------------------------------------------------------------------

    def erase_account(
        self,
        eraser: AccountEraser,
        owner_id: str,
        reason: str,
        now: datetime | None = None,
    ) -> ErasureReport:
        """Erases an account and writes the register around it: the row first,
        incomplete, in the database and in the copy outside it; then the data and
        the identity; then the row is completed. If the row cannot be written the
        erase does not start (the caller can try again); if the erase fails midway
        the row stays incomplete and a re-application still erases the account."""
        if reason not in DeletionReason.ALL:
            raise ValueError("unknown deletion reason")
        now = now or utc_now()
        entry = DeletionLogEntry(
            owner_hash=owner_fingerprint(owner_id), deleted_at=now, reason=reason
        )
        self._repository.begin(entry)
        self._copy.save(entry)

        report = eraser.erase_data(owner_id)
        eraser.delete_identity(owner_id)
        self._repository.complete(entry.owner_hash, utc_now())
        return report

    # -- keeping --------------------------------------------------------------------

    def prune(self, now: datetime | None = None) -> PruneReport:
        """Removes what is older than [retention], from the table and the copy."""
        cutoff = (now or utc_now()) - self.retention
        report = PruneReport(
            rows_removed=self._repository.delete_older_than(cutoff),
            copies_removed=self._copy.delete_older_than(cutoff),
        )
        logger.info(
            "deletion register pruned: rows=%d copies=%d",
            report.rows_removed,
            report.copies_removed,
        )
        return report

    # -- after a database restore ---------------------------------------------------

    def reload_from_copy(self) -> int:
        """Puts back in the table the entries the copy holds and the restored
        table lacks. The first step after a restore."""
        return self._repository.add_missing(self._copy.list_all())

    def reapply(
        self,
        eraser: AccountEraser,
        owner_ids: Iterable[str],
        dry_run: bool = True,
    ) -> ReapplyReport:
        """Erases again every account in [owner_ids] (the accounts present after
        a restore) whose fingerprint is in the register, complete or not. With
        [dry_run] it only counts."""
        known = {entry.owner_hash for entry in self._repository.list_all()}
        known |= {entry.owner_hash for entry in self._copy.list_all()}
        checked = 0
        due: list[str] = []
        for owner_id in owner_ids:
            checked += 1
            if owner_fingerprint(owner_id) in known:
                due.append(owner_id)
        report = ReapplyReport(dry_run=dry_run, checked=checked, to_erase=len(due))
        if dry_run:
            return report
        for owner_id in due:
            try:
                eraser.erase_data(owner_id)
                eraser.delete_identity(owner_id)
                report.erased += 1
            except Exception:  # noqa: BLE001 - go on with the others
                logger.warning("could not apply a recorded erasure again", exc_info=False)
                report.failed += 1
        return report
