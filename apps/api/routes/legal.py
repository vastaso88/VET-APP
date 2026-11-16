from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from packages.core.domain.common.language import language_from_accept_header
from packages.core.domain.consent.account_consent_text import (
    build_consent_catalog,
    served_consent_language,
)
from packages.infrastructure.auth.age_guarded_auth_provider import allow_closed_account

router = APIRouter(prefix="/legal", tags=["legal"])


@router.get("/consents")
def get_consent_texts(
    lang: str | None = None,
    language: str | None = None,
    accept_language: str | None = Header(default=None),
) -> dict[str, object]:
    """Public catalog of consent texts. Carries no owner data, so it works
    before an account exists (signup screen).

    `?lang=xx` (or `?language=xx`) selects the IT/EN/ES/DE/FR draft translation.
    Unknown languages fall back to English. Without either, the language of the
    signed-in account is used, then the Accept-Language header, then Italian. The
    answer's `language` says which was served; this is not legal approval.
    """
    asked = lang if lang is not None else language
    chosen = asked if asked is not None else _account_or_header_language(accept_language)
    return {
        "language": served_consent_language(chosen),
        "catalog": {
            key: entry.model_dump() for key, entry in build_consent_catalog(chosen).items()
        },
    }


def _account_or_header_language(accept_language: str | None) -> str | None:
    """The route is public, so a caller with no (valid) token is simply not
    signed in: no error, the header decides."""
    try:
        with allow_closed_account():
            return get_container().auth_provider.get_current_user().preferred_locale
    except Exception:  # noqa: BLE001 - not signed in is the normal case here
        return language_from_accept_header(accept_language)
