from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _require_scheduler_token

router = APIRouter(prefix="/admin/lifecycle", tags=["admin"])


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
