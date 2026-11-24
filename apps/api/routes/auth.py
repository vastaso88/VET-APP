import logging

from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.schemas.auth import AuthCredentialsRequest, SignUpRequest
from packages.core.application.services.set_account_consent import SetAccountConsentInput
from packages.core.domain.common.language import resolve_language
from packages.core.domain.consent.models import AccountConsentType
from packages.shared.errors.base import AuthenticationError, ValidationError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup")
def sign_up(
    request: SignUpRequest, accept_language: str | None = Header(default=None)
) -> dict[str, object]:
    # No account without the acceptance of the Terms and the Privacy notice
    # (docs/compliance/04): an API client must say so, the app ticks the box.
    if not request.accept_terms:
        raise ValidationError("accept_terms_required")
    container = get_container()
    try:
        result = container.auth_provider.sign_up(request.email, request.password)
    except (AuthenticationError, ValidationError):
        raise
    except Exception as exc:
        # The identity provider's message can name the account state
        # ("already registered", rate limits): keep it server-side.
        raise ValidationError("signup failed") from exc
    if result is None:
        # No session yet (the address must be confirmed first): there is no account id
        # to record against, so the client records the acceptance at its first
        # sign-in (POST /account/consents), as the app does.
        return {
            "detail": "Signup completed. Confirm email if required by Supabase.",
            "consents_recorded": False,
        }
    recorded = _record_acceptance(
        result.user.id,
        resolve_language(None, accept_language),
        emergency_notice=request.accept_emergency_notice,
    )
    return {**result.model_dump(), "consents_recorded": recorded}


def _record_acceptance(owner_id: str, language: str, *, emergency_notice: bool) -> bool:
    """Terms and Privacy (and the emergency notice for a client that shows it here), with the
    current version and the date. The account exists already, so a failure is logged (no
    personal data) and reported in the answer; the client then records them itself."""
    try:
        service = get_container().set_account_consent_service()
        keys = [AccountConsentType.TERMS_OF_SERVICE, AccountConsentType.PRIVACY_POLICY]
        if emergency_notice:
            keys.append(AccountConsentType.EMERGENCY_NOTICE)
        for key in keys:
            service.execute(
                SetAccountConsentInput(
                    owner_id=owner_id, consent_key=key, granted=True, language=language
                )
            )
    except Exception:  # noqa: BLE001 - the account is created, do not lose the session
        logger.warning("could not record the acceptance at signup", exc_info=False)
        return False
    return True


@router.post("/login")
def sign_in(request: AuthCredentialsRequest) -> dict[str, object]:
    try:
        result = get_container().auth_provider.sign_in_with_password(
            request.email, request.password
        )
    except AuthenticationError:
        raise
    except Exception as exc:
        # Wrong password, unknown account and provider hiccups all look the
        # same to the caller (no account enumeration).
        raise AuthenticationError("invalid credentials") from exc
    return result.model_dump()


@router.get("/me")
def get_me() -> dict[str, str]:
    user = get_container().auth_provider.get_current_user()
    # Same body as before the user gained an optional display name.
    return user.model_dump(include={"id", "email"})
