from fastapi import APIRouter

from packages.core.domain.consent.account_consent_text import build_consent_catalog

router = APIRouter(prefix="/legal", tags=["legal"])


@router.get("/consents")
def get_consent_texts() -> dict[str, object]:
    """Public catalog of consent texts. Carries no owner data, so it works
    before an account exists (signup screen)."""
    return {"catalog": {key: entry.model_dump() for key, entry in build_consent_catalog().items()}}
