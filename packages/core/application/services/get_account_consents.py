from pydantic import BaseModel

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.domain.consent.account_consent_text import build_consent_catalog
from packages.core.domain.consent.models import AccountConsents, ConsentCatalogEntry


class GetAccountConsentsInput(BaseModel):
    owner_id: str


class GetAccountConsentsOutput(BaseModel):
    account_consents: AccountConsents
    catalog: dict[str, ConsentCatalogEntry]


class GetAccountConsentsService:
    def __init__(self, repository: AccountConsentsRepository) -> None:
        self._repository = repository

    def execute(self, data: GetAccountConsentsInput) -> GetAccountConsentsOutput:
        account_consents = self._repository.get(data.owner_id) or AccountConsents(
            owner_id=data.owner_id
        )
        return GetAccountConsentsOutput(
            account_consents=account_consents, catalog=build_consent_catalog()
        )
