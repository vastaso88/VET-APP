from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.account_consents import SetAccountConsentRequest
from packages.core.application.services.get_account_consents import GetAccountConsentsInput
from packages.core.application.services.set_account_consent import SetAccountConsentInput

router = APIRouter(prefix="/account/consents", tags=["account-consents"])


@router.get("")
def get_account_consents() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.get_account_consents_service().execute(
        GetAccountConsentsInput(owner_id=user.id)
    )
    return result.model_dump()


@router.post("")
def set_account_consent(request: SetAccountConsentRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.set_account_consent_service().execute(
        SetAccountConsentInput(owner_id=user.id, **request.model_dump())
    )
    return result.model_dump()
