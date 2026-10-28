from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from packages.core.application.services.delete_account import DeleteAccountInput
from packages.core.application.services.export_account_data import ExportAccountDataInput

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/export")
def export_account_data() -> dict[str, object]:
    """Right of access and portability (GDPR art. 15 and 20): every row and
    a short-lived link to every file of the signed-in owner, as JSON. Only
    the caller's own id, taken from the token. Throttled to one export per
    ten minutes per caller (apps/api/rate_limit.py). Nothing of the content
    is logged. Contract: docs/security/09_export_dati_contratto.md."""
    container = get_container()
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
def delete_account() -> dict[str, object]:
    """Deletes the signed-in owner's account and every piece of data they
    created. Only ever acts on the caller's own id, taken from the access
    token: there is no way to name another account. Deleting also needs a
    sign-in from the last few minutes, so a stolen but valid token is not
    enough (the app asks for the password right before calling)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    report = container.delete_account_service().execute(
        DeleteAccountInput(owner_id=user.id, signed_in_at=container.auth_provider.last_sign_in_at())
    )
    return {"deleted": True, "report": report.model_dump()}
