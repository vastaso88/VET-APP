from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now


class ConsentRecord(BaseModel):
    """A single granted/declined decision on one consent, pinned to the
    exact text version the owner saw (see `docs/compliance/`) so a later
    wording change never silently reinterprets a past decision."""

    granted: bool
    version: str
    decided_at: datetime = Field(default_factory=utc_now)


class AccountConsentType:
    """Account-level consent keys. MANDATORY ones are contract/disclosure
    acceptance (gating app access is legitimate); OPTIONAL ones are GDPR
    opt-in processing (must stay off by default and revocable at will —
    see docs/compliance/04_termini_e_consensi.md)."""

    TERMS_OF_SERVICE = "terms_of_service"
    PRIVACY_POLICY = "privacy_policy"
    MARKETING_EMAIL = "marketing_email"
    ANALYTICS = "analytics"

    MANDATORY = frozenset({TERMS_OF_SERVICE, PRIVACY_POLICY})
    OPTIONAL = frozenset({MARKETING_EMAIL, ANALYTICS})
    ALL = MANDATORY | OPTIONAL


class AccountConsents(BaseModel):
    owner_id: str
    consents: dict[str, ConsentRecord] = Field(default_factory=dict)


class ConsentCatalogEntry(BaseModel):
    version: str
    text: str
