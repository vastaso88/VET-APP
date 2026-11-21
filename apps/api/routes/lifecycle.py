from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _require_scheduler_token

router = APIRouter(prefix="/admin/lifecycle", tags=["admin"])


@router.post("/purge-deleted-accounts")
def purge_deleted_accounts(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Erases the accounts whose deletion period has ended, for good, with the
    same eraser as the owner's own deletion. Off until
    ACCOUNT_DELETION_PURGE_ENABLED is true: until then it only counts how many
    are due. Counts only; scheduler token, no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    container = get_container()
    report = container.account_deletion_service().purge_due(
        container.settings.account_deletion_purge_enabled
    )
    return report.model_dump()


@router.post("/purge-expired-pauses")
def purge_expired_pauses(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Erases the paused accounts that ran PAUSE_MAX_MONTHS without a sign-in,
    after their warnings. Off until PAUSE_PURGE_ENABLED is true: until then it only
    counts. Counts only; scheduler token, no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    container = get_container()
    report = container.account_pause_service().purge_expired(container.settings.pause_purge_enabled)
    return report.model_dump()


@router.post("/prune-deletion-log")
def prune_deletion_log(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Removes the register-of-deletions rows (and their copies outside the
    database) older than the retention: the longer of the re-application window
    and the proof period. Counts only; scheduler token, no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    return get_container().deletion_log_service.prune().model_dump()


@router.post("/underage-dry-run")
def underage_review_dry_run(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """How many closed accounts (declared age under 14) are past the 30-day
    grace period. Counts only; there is no erase path yet."""
    _require_scheduler_token(x_vetapp_scheduler)
    return get_container().underage_review_dry_run_service().execute().model_dump()


@router.post("/dry-run")
def retention_dry_run(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """What the data-retention job would do right now: counts and pseudonymous
    references only. It reads; it never sends a message and never erases an
    account (there is no such code path yet). Same scheduler token as
    `/admin/scheduler/tick`, so it has no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    report = get_container().retention_dry_run_service().execute()
    return report.model_dump(mode="json")
