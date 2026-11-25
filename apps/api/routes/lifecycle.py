from typing import Annotated

from fastapi import APIRouter, Header, Query, Response
from fastapi.responses import JSONResponse

from apps.api.dependencies.container import get_container
from apps.api.routes.admin_common import _require_scheduler_token
from packages.core.application.services.prune_chat_message_keys import (
    PruneChatMessageKeysService,
)

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


@router.post("/send-exit-notices")
def send_exit_notices(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Writes the e-mails of the deletion sequence that are due (docs/compliance/18):
    confirmation and reminders, the closing one comes with the erase. Off until
    EMAIL_SENDING_ENABLED is true and the wording is configured: until then it only counts
    and touches nothing. Counts only; scheduler token, no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    return get_container().exit_notice_service().run().model_dump()


@router.post("/prune-deletion-log")
def prune_deletion_log(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Removes the register-of-deletions rows (and their copies outside the
    database) older than the retention: the longer of the re-application window
    and the proof period. Counts only; scheduler token, no user session."""
    _require_scheduler_token(x_vetapp_scheduler)
    return get_container().deletion_log_service.prune().model_dump()


@router.post("/prune-chat-message-keys")
def prune_chat_message_keys(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
) -> dict[str, object]:
    """Removes the reservations of chat messages older than 30 days (QK-03b). Counts only;
    scheduler token, no user session. Answers 200 with `table_available: false` while the
    table does not exist yet, so the hourly job does not go red before the SQL is applied."""
    _require_scheduler_token(x_vetapp_scheduler)
    keys = get_container().chat_message_key_repository
    return PruneChatMessageKeysService(keys).run().model_dump(mode="json")


@router.post("/prune-removed-listings")
def prune_removed_listings(
    x_vetapp_scheduler: str | None = Header(default=None, alias="X-VetApp-Scheduler"),
    allow_leftovers: Annotated[int, Query(ge=0, le=100_000)] = 0,
) -> Response:
    """Mercatino ads taken down by the team: keeps their photos out of the public bucket,
    deletes ad and photos 6 months after the decision and the register of decisions after
    24; deletes the photos without an ad. Counts only; scheduler token, no user session.
    `table_available: false` until the SQL is applied. 500, with the counts, when the photos
    without an ad are too many to be believed: none is deleted until someone has looked and
    calls again with `allow_leftovers` (docs/features/marketplace_messages.md)."""
    _require_scheduler_token(x_vetapp_scheduler)
    output = get_container().prune_removed_listings_service().run(allow_leftovers=allow_leftovers)
    return JSONResponse(
        status_code=500 if output.leftovers_blocked else 200,
        content=output.model_dump(mode="json"),
    )


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
