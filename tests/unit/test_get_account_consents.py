from packages.core.application.services.get_account_consents import (
    GetAccountConsentsInput,
    GetAccountConsentsService,
)
from packages.core.application.services.set_account_consent import (
    SetAccountConsentInput,
    SetAccountConsentService,
)
from packages.core.domain.consent.models import AccountConsentType
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
)


def test_new_owner_gets_empty_consents_and_full_catalog() -> None:
    service = GetAccountConsentsService(InMemoryAccountConsentsRepository())

    result = service.execute(GetAccountConsentsInput(owner_id="user-1"))

    assert result.account_consents.owner_id == "user-1"
    assert result.account_consents.consents == {}
    assert set(result.catalog.keys()) == AccountConsentType.ALL


def test_previously_set_consents_round_trip() -> None:
    repository = InMemoryAccountConsentsRepository()
    SetAccountConsentService(repository).execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.ANALYTICS, granted=True
        )
    )

    result = GetAccountConsentsService(repository).execute(
        GetAccountConsentsInput(owner_id="user-1")
    )

    decision = result.account_consents.consents[AccountConsentType.ANALYTICS]
    assert decision.granted is True
