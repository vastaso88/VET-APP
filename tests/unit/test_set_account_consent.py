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


def test_error_reports_consent_is_optional_revocable_and_has_a_text_in_every_language() -> None:
    from packages.core.domain.consent.account_consent_text import (
        CONSENT_TEXTS_BY_LANGUAGE,
        build_consent_catalog,
    )

    assert AccountConsentType.DIAGNOSTICS in AccountConsentType.OPTIONAL
    assert AccountConsentType.DIAGNOSTICS not in AccountConsentType.MANDATORY

    service = _service()
    granted = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.DIAGNOSTICS, granted=True
        )
    )
    decision = granted.account_consents.consents[AccountConsentType.DIAGNOSTICS]
    assert decision.granted is True
    assert decision.version == CURRENT_VERSIONS[AccountConsentType.DIAGNOSTICS]

    revoked = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.DIAGNOSTICS, granted=False
        )
    )
    assert revoked.account_consents.consents[AccountConsentType.DIAGNOSTICS].granted is False

    for language in CONSENT_TEXTS_BY_LANGUAGE:
        text = build_consent_catalog(language)[AccountConsentType.DIAGNOSTICS].text
        assert text.strip()
        assert any(
            word in text for word in ("Germania", "Germany", "Alemania", "Deutschland", "Allemagne")
        )


# -- marketing and statistics are not for anyone under 18, whatever the client sends ----


def _service_with_age(birth_year_offset: int | None) -> SetAccountConsentService:
    from datetime import UTC, datetime

    from packages.core.application.services.age_gate import AgeGateService
    from packages.core.domain.age.models import AccountAge
    from packages.infrastructure.persistence.in_memory_account_age_repository import (
        InMemoryAccountAgeRepository,
    )

    ages = InMemoryAccountAgeRepository()
    if birth_year_offset is not None:
        today = datetime.now(UTC).date()
        ages.create(
            AccountAge(
                owner_id="user-1",
                birth_date=today.replace(year=today.year - birth_year_offset),
                declared_at=datetime.now(UTC),
            )
        )
    return SetAccountConsentService(InMemoryAccountConsentsRepository(), AgeGateService(ages))


@pytest.mark.parametrize("key", [AccountConsentType.MARKETING_EMAIL, AccountConsentType.ANALYTICS])
@pytest.mark.parametrize("years", [14, 16, 17, 10])
def test_a_minor_cannot_grant_marketing_or_analytics(key: str, years: int) -> None:
    from packages.shared.errors.base import AgeRestrictedError

    service = _service_with_age(years)

    with pytest.raises(AgeRestrictedError) as error:
        service.execute(SetAccountConsentInput(owner_id="user-1", consent_key=key, granted=True))

    assert error.value.code == "consent_not_for_minors"


def test_a_minor_can_still_decline_and_give_the_other_optional_consents() -> None:
    service = _service_with_age(16)

    declined = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.MARKETING_EMAIL, granted=False
        )
    )
    assert declined.account_consents.consents[AccountConsentType.MARKETING_EMAIL].granted is False
    for key in (AccountConsentType.DIAGNOSTICS, AccountConsentType.CONTRIBUTION_RULES):
        done = service.execute(
            SetAccountConsentInput(owner_id="user-1", consent_key=key, granted=True)
        )
        assert done.account_consents.consents[key].granted is True


@pytest.mark.parametrize("years", [18, 40, None])
def test_an_adult_or_an_undeclared_age_is_not_blocked_here(years: int | None) -> None:
    service = _service_with_age(years)
    result = service.execute(
        SetAccountConsentInput(
            owner_id="user-1", consent_key=AccountConsentType.MARKETING_EMAIL, granted=True
        )
    )
    assert result.account_consents.consents[AccountConsentType.MARKETING_EMAIL].granted is True
