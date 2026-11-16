from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.schemas.account_consents import SetAccountConsentRequest
from packages.core.application.services.get_account_consents import GetAccountConsentsInput
from packages.core.application.services.set_account_consent import SetAccountConsentInput
from packages.core.domain.common.language import resolve_language
from packages.infrastructure.auth.age_guarded_auth_provider import (
    allow_missing_consent,
    forget_gate_cache,
)

router = APIRouter(prefix="/account/consents", tags=["account-consents"])


@router.get("")
def get_account_consents(accept_language: str | None = Header(default=None)) -> dict[str, object]:
    container = get_container()
    # Reachable before the Terms are accepted: it is how the app accepts them.
    with allow_missing_consent():
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
    with allow_missing_consent():
        user = container.auth_provider.get_current_user()
    result = container.set_account_consent_service().execute(
        SetAccountConsentInput(
            owner_id=user.id,
            language=resolve_language(None, accept_language),
            **request.model_dump(),
        )
    )
    # The next request sees the new acceptance, not the cached "missing".
    forget_gate_cache(container.auth_provider, user.id)
    return result.model_dump()
