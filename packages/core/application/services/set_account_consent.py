from pydantic import BaseModel

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.services.age_gate import AgeGateService
from packages.core.domain.age.models import AgeBand
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
from packages.shared.errors.base import AgeRestrictedError, ValidationError


class SetAccountConsentInput(BaseModel):
    owner_id: str
    consent_key: str
    granted: bool
    language: str = "it"


class SetAccountConsentOutput(BaseModel):
    account_consents: AccountConsents
    catalog: dict[str, ConsentCatalogEntry]


# Consents that a declared minor (under 18) cannot give. The other optional ones
# (error reports, contribution rules, medical record reading) are open from 14.
NOT_FOR_MINORS = frozenset({AccountConsentType.MARKETING_EMAIL, AccountConsentType.ANALYTICS})


class SetAccountConsentService:
    """Grants or revokes one account-level consent (docs/compliance/04_termini_e_consensi.md).

    Mandatory keys (terms_of_service, privacy_policy) are a contract record,
    not a revocable preference: this is enforced here, not only in the UI,
    so the "not revocable via toggle" rule holds regardless of client.
    """

    def __init__(
        self,
        repository: AccountConsentsRepository,
        age_gate: AgeGateService | None = None,
    ) -> None:
        self._repository = repository
        self._age_gate = age_gate

    def execute(self, data: SetAccountConsentInput) -> SetAccountConsentOutput:
        if data.consent_key not in AccountConsentType.ALL:
            raise ValidationError(f"unknown consent_key: {data.consent_key}")
        if data.consent_key in AccountConsentType.MANDATORY and not data.granted:
            raise ValidationError(
                "i termini di servizio e l'informativa privacy non sono revocabili da qui"
            )

        if (
            data.granted
            and data.consent_key in NOT_FOR_MINORS
            and self._age_gate is not None
            and self._age_gate.status(data.owner_id).band in (AgeBand.MINOR, AgeBand.UNDER_MINIMUM)
        ):
            # Marketing and usage statistics are not offered to anyone under 18
            # (docs/compliance/10 §3): the server refuses even if a client sends
            # it. Declining or revoking is always allowed.
            raise AgeRestrictedError("consent_not_for_minors")

        saved = self._repository.record(
            data.owner_id,
            data.consent_key,
            ConsentRecord(granted=data.granted, version=CURRENT_VERSIONS[data.consent_key]),
        )
        return SetAccountConsentOutput(
            account_consents=saved, catalog=build_consent_catalog(data.language)
        )
