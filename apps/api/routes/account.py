from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from packages.core.application.services.delete_account import DeleteAccountInput

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("")
def delete_account() -> dict[str, object]:
    """Deletes the signed-in owner's account and every piece of data they
    created. Only ever acts on the caller's own id, taken from the access
    token: there is no way to name another account."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    report = container.delete_account_service().execute(DeleteAccountInput(owner_id=user.id))
    return {"deleted": True, "report": report.model_dump()}
