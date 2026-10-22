from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.schemas.account_consents import SetAccountConsentRequest
from packages.core.application.services.get_account_consents import GetAccountConsentsInput
from packages.core.application.services.set_account_consent import SetAccountConsentInput
from packages.core.domain.common.language import resolve_language

router = APIRouter(prefix="/account/consents", tags=["account-consents"])


@router.get("")
def get_account_consents(accept_language: str | None = Header(default=None)) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.get_account_consents_service().execute(
        GetAccountConsentsInput(owner_id=user.id, language=resolve_language(None, accept_language))
    )
    return result.model_dump()


@router.post("")
def set_account_consent(
    request: SetAccountConsentRequest, accept_language: str | None = Header(default=None)
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.set_account_consent_service().execute(
        SetAccountConsentInput(
            owner_id=user.id,
            language=resolve_language(None, accept_language),
            **request.model_dump(),
        )
    )
    return result.model_dump()
