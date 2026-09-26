import pytest

from packages.core.application.services.set_account_consent import (
    SetAccountConsentInput,
    SetAccountConsentService,
)
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
)
from packages.shared.errors.base import ValidationError


def _service() -> SetAccountConsentService:
    return SetAccountConsentService(InMemoryAccountConsentsRepository())


def test_granting_an_optional_consent_stamps_current_version_and_timestamp() -> None:
    service = _service()

    result = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.MARKETING_EMAIL, granted=True
        )
    )

    decision = result.account_consents.consents[AccountConsentType.MARKETING_EMAIL]
    assert decision.granted is True
    assert decision.version == CURRENT_VERSIONS[AccountConsentType.MARKETING_EMAIL]
    assert decision.decided_at is not None


def test_toggling_an_optional_consent_off_after_on_updates_the_record() -> None:
    service = _service()
    service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.ANALYTICS, granted=True
        )
    )

    result = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.ANALYTICS, granted=False
        )
    )

    assert result.account_consents.consents[AccountConsentType.ANALYTICS].granted is False


def test_rejects_unknown_consent_key() -> None:
    service = _service()

    with pytest.raises(ValidationError):
        service.execute(
            SetAccountConsentInput(owner_id="user-1", consent_key="not_a_real_key", granted=True)
        )


def test_rejects_revoking_terms_of_service() -> None:
    service = _service()

    with pytest.raises(ValidationError):
        service.execute(
            SetAccountConsentInput(
                owner_id="user-1",
                consent_key=AccountConsentType.TERMS_OF_SERVICE,
                granted=False,
            )
        )


def test_rejects_revoking_privacy_policy() -> None:
    service = _service()

    with pytest.raises(ValidationError):
        service.execute(
            SetAccountConsentInput(
                owner_id="user-1", consent_key=AccountConsentType.PRIVACY_POLICY, granted=False
            )
        )


def test_granting_terms_of_service_and_privacy_policy_succeeds() -> None:
    service = _service()

    result = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.TERMS_OF_SERVICE, granted=True
        )
    )

    decision = result.account_consents.consents[AccountConsentType.TERMS_OF_SERVICE]
    assert decision.granted is True
    assert decision.version == CURRENT_VERSIONS[AccountConsentType.TERMS_OF_SERVICE]
