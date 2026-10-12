from fastapi import APIRouter

from packages.core.domain.consent.account_consent_text import (
    build_consent_catalog,
    served_consent_language,
)

router = APIRouter(prefix="/legal", tags=["legal"])


@router.get("/consents")
def get_consent_texts(lang: str | None = None) -> dict[str, object]:
    """Public catalog of consent texts. Carries no owner data, so it works
    before an account exists (signup screen).

    `?lang=xx` asks for a language; only Italian has a reviewed text today, so
    any other value is answered in Italian. `language` says which was served.
    """
    return {
        "language": served_consent_language(lang),
        "catalog": {key: entry.model_dump() for key, entry in build_consent_catalog(lang).items()},
    }
