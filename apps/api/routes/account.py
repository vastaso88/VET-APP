from fastapi import APIRouter, Query

from apps.api.dependencies.container import get_container
from packages.core.application.services.delete_account import DeleteAccountInput
from packages.core.application.services.export_account_data import ExportAccountDataInput
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.core.domain.account_deletion.log import DeletionReason
from packages.core.domain.age.models import AgeBand
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
    allow_missing_consent,
)

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/export")
def export_account_data() -> dict[str, object]:
    """Right of access and portability (GDPR art. 15 and 20): every row and
    a short-lived link to every file of the signed-in owner, as JSON. Only
    the caller's own id, taken from the token. Throttled to one export per
    ten minutes per caller (apps/api/rate_limit.py). Nothing of the content
    is logged. Contract: docs/security/09_export_dati_contratto.md."""
    container = get_container()
    # A closed account (under the minimum age) keeps its right of access.
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    export = container.export_account_data_service().execute(
        ExportAccountDataInput(
            owner_id=user.id,
            email=user.email,
            display_name=user.display_name,
            preferred_locale=user.preferred_locale,
        )
    )
    return export.model_dump(mode="json")


@router.delete("")
def delete_account(immediate: bool = Query(default=False)) -> dict[str, object]:
    """Deletes the signed-in owner's account and every piece of data they
    created. Only ever acts on the caller's own id, taken from the access
    token: there is no way to name another account. Deleting also needs a
    sign-in from the last few minutes, so a stolen but valid token is not
    enough (the app asks for the password right before calling)."""
    container = get_container()
    # A closed account (under the minimum age) can still delete itself.
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    signed_in_at = container.auth_provider.last_sign_in_at()

    under_minimum = container.age_gate_service().status(user.id).band == AgeBand.UNDER_MINIMUM
    if immediate or under_minimum:
        # "Elimina subito" (the owner chose no way back, which also frees the
        # e-mail), or a child's data, which has no ground to be kept: erased at
        # once. A request that was waiting is removed last.
        report = container.delete_account_service().execute(
            DeleteAccountInput(
                owner_id=user.id,
                signed_in_at=signed_in_at,
                reason=(
                    DeletionReason.CLOSED_BY_AGE_USER if under_minimum else DeletionReason.USER_NOW
                ),
            )
        )
        container.account_deletion_repository.delete(user.id)
        return {
            "status": "deleted",
            "deleted": True,
            "scheduled": False,
            "report": report.model_dump(),
        }

    # Everyone else: deactivated now, erased when the period ends (the owner can
    # cancel until then).
    status = container.account_deletion_service().request(user.id, signed_in_at)
    _forget_cached_answer(user.id)
    # Deactivated now, erased on [purge_after]: not "deleted" yet, so `deleted` is
    # false (it was true, which read as a contradiction next to `pending`).
    return {
        "status": "scheduled",
        "deleted": False,
        "scheduled": True,
        **status.model_dump(mode="json"),
    }


@router.post("/pause")
def pause_account() -> dict[str, object]:
    """The owner puts the account aside, with nothing deleted: it becomes
    inactive (the session that asked is refused from now on, ads hidden) and the
    data is kept. Signing in again ends the pause. Starting it also clears the
    120-day clock, like choosing a plan. Acts only on the caller's own id."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    service = container.account_pause_service()
    pause = service.start(user.id)
    _forget_cached_answer(user.id)
    return {
        "paused": True,
        "paused_at": pause.paused_at.isoformat(),
        # The latest day the account is erased if the owner never signs in.
        "delete_after": service.delete_after(pause).isoformat(),
        "max_months": service.max_months,
    }


@router.get("/session")
def check_session() -> dict[str, object]:
    """A cheap check the app makes when it opens or comes back to the front. It
    goes through the same guard as every other route, so an account that was
    paused or deactivated from another device answers 403 `account_paused` /
    `account_deactivated` here and the app can sign out and clear its notices."""
    container = get_container()
    with allow_missing_consent():
        container.auth_provider.get_current_user()
    return {"ok": True}


@router.get("/pause/notice")
def get_pause_notice() -> dict[str, object]:
    """Whether the caller's pause ended at the last sign-in and the app has not
    said so yet. If so, whether they have a plan and, if not, the day their data
    would be erased now (the 120-day clock restarts when the pause ends). Only
    ever about the caller's own account."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    pause = container.account_pause_service().ended_pause(user.id)
    if pause is None:
        return {"resumed": False}
    subscription = container.get_or_create_subscription_service().execute(
        GetOrCreateSubscriptionInput(owner_id=user.id, email=user.email or "")
    )
    kept_until = subscription.data_kept_until
    return {
        "resumed": True,
        "resumed_at": pause.resumed_at.isoformat() if pause.resumed_at else None,
        "has_access": subscription.has_access,
        "data_kept_until": kept_until.isoformat() if kept_until else None,
    }


@router.post("/pause/notice/ack")
def acknowledge_pause_notice() -> dict[str, object]:
    """The app showed that the pause is over: the ended row is removed. Only the
    caller's own."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    return {"acknowledged": container.account_pause_service().acknowledge_end(user.id)}


@router.get("/deletion")
def get_deletion_status() -> dict[str, object]:
    """Whether the account is waiting to be erased, and the day. Readable by a
    deactivated account (it is how the app knows to offer the cancellation)."""
    container = get_container()
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    status = container.account_deletion_service().status(user.id).model_dump(mode="json")
    # The pause window's number (a setting) is said by the server, never kept in the app.
    return {**status, "pause_max_months": container.settings.pause_max_months}


@router.post("/deletion/cancel")
def cancel_deletion() -> dict[str, object]:
    """The owner changed their mind within the period. Needs a recent sign-in
    (signing in again, or the e-mail link of a password reset)."""
    container = get_container()
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    status = container.account_deletion_service().cancel(
        user.id, container.auth_provider.last_sign_in_at()
    )
    _forget_cached_answer(user.id)
    return status.model_dump(mode="json")


def _forget_cached_answer(owner_id: str) -> None:
    provider = get_container().auth_provider
    if isinstance(provider, AgeGuardedAuthProvider):
        provider.forget(owner_id)
