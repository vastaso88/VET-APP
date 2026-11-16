from fastapi import APIRouter, Query

from apps.api.dependencies.container import get_container
from packages.core.application.services.delete_account import DeleteAccountInput
from packages.core.application.services.export_account_data import ExportAccountDataInput
from packages.core.domain.age.models import AgeBand
from packages.infrastructure.auth.age_guarded_auth_provider import (
    AgeGuardedAuthProvider,
    allow_closed_account,
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

    if immediate or container.age_gate_service().status(user.id).band == AgeBand.UNDER_MINIMUM:
        # "Elimina subito" (the owner chose no way back, which also frees the
        # e-mail), or a child's data, which has no ground to be kept: erased at
        # once. A request that was waiting is removed last.
        report = container.delete_account_service().execute(
            DeleteAccountInput(owner_id=user.id, signed_in_at=signed_in_at)
        )
        container.account_deletion_repository.delete(user.id)
        return {"deleted": True, "scheduled": False, "report": report.model_dump()}

    # Everyone else: deactivated now, erased when the period ends (the owner can
    # cancel until then).
    status = container.account_deletion_service().request(user.id, signed_in_at)
    _forget_cached_answer(user.id)
    return {"deleted": True, "scheduled": True, **status.model_dump(mode="json")}


@router.get("/deletion")
def get_deletion_status() -> dict[str, object]:
    """Whether the account is waiting to be erased, and the day. Readable by a
    deactivated account (it is how the app knows to offer the cancellation)."""
    container = get_container()
    with allow_closed_account():
        user = container.auth_provider.get_current_user()
    return container.account_deletion_service().status(user.id).model_dump(mode="json")


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
