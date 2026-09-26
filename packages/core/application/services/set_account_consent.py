from pydantic import BaseModel

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.domain.consent.account_consent_text import (
    CURRENT_VERSIONS,
    build_consent_catalog,
)
from packages.core.domain.consent.models import (
    AccountConsents,
    AccountConsentType,
    ConsentCatalogEntry,
    ConsentRecord,
)
from packages.shared.errors.base import ValidationError


class SetAccountConsentInput(BaseModel):
    owner_id: str
    consent_key: str
    granted: bool


class SetAccountConsentOutput(BaseModel):
    account_consents: AccountConsents
    catalog: dict[str, ConsentCatalogEntry]


class SetAccountConsentService:
    """Grants or revokes one account-level consent (docs/compliance/04_termini_e_consensi.md).

    Mandatory keys (terms_of_service, privacy_policy) are a contract record,
    not a revocable preference: this is enforced here, not only in the UI,
    so the "not revocable via toggle" rule holds regardless of client.
    """

    def __init__(self, repository: AccountConsentsRepository) -> None:
        self._repository = repository

    def execute(self, data: SetAccountConsentInput) -> SetAccountConsentOutput:
        if data.consent_key not in AccountConsentType.ALL:
            raise ValidationError(f"unknown consent_key: {data.consent_key}")
        if data.consent_key in AccountConsentType.MANDATORY and not data.granted:
            raise ValidationError(
                "i termini di servizio e l'informativa privacy non sono revocabili da qui"
            )

        existing = self._repository.get(data.owner_id) or AccountConsents(owner_id=data.owner_id)
        updated = existing.model_copy(
            update={
                "consents": {
                    **existing.consents,
                    data.consent_key: ConsentRecord(
                        granted=data.granted, version=CURRENT_VERSIONS[data.consent_key]
                    ),
                }
            }
        )
        saved = self._repository.save(updated)
        return SetAccountConsentOutput(account_consents=saved, catalog=build_consent_catalog())
