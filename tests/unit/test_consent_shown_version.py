"""The version of the text the app showed travels with the acceptance (docs/compliance/04)."""

from __future__ import annotations

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

TERMS = AccountConsentType.TERMS_OF_SERVICE
NOTICE = AccountConsentType.EMERGENCY_NOTICE
USER_A, USER_B = "owner-a", "owner-b"


def _service() -> tuple[SetAccountConsentService, InMemoryAccountConsentsRepository]:
    repository = InMemoryAccountConsentsRepository()
    return SetAccountConsentService(repository), repository


def _version(repository: InMemoryAccountConsentsRepository, owner: str, key: str) -> str | None:
    record = repository.get(owner)
    return record.consents[key].version if record and key in record.consents else None


@pytest.mark.parametrize("key", [TERMS, NOTICE])
def test_the_current_version_shown_is_recorded(key: str) -> None:
    service, repository = _service()
    service.execute(
        SetAccountConsentInput(
            owner_id=USER_A, consent_key=key, granted=True, shown_version=CURRENT_VERSIONS[key]
        )
    )
    assert _version(repository, USER_A, key) == CURRENT_VERSIONS[key]


def test_an_older_text_shown_records_nothing() -> None:
    service, repository = _service()
    with pytest.raises(ValidationError, match="consent_version_mismatch"):
        service.execute(
            SetAccountConsentInput(
                owner_id=USER_A, consent_key=TERMS, granted=True, shown_version="v0"
            )
        )
    assert _version(repository, USER_A, TERMS) is None


def test_an_app_that_sends_no_version_is_still_served_and_the_gap_is_logged(
    caplog: pytest.LogCaptureFixture,
) -> None:
    service, repository = _service()
    with caplog.at_level("INFO"):
        service.execute(SetAccountConsentInput(owner_id=USER_A, consent_key=TERMS, granted=True))
    assert _version(repository, USER_A, TERMS) == CURRENT_VERSIONS[TERMS]
    assert "without a declared version: terms_of_service" in caplog.text
    assert USER_A not in caplog.text


def test_a_refused_acceptance_of_user_b_leaves_user_a_untouched() -> None:
    service, repository = _service()
    service.execute(
        SetAccountConsentInput(
            owner_id=USER_A, consent_key=TERMS, granted=True, shown_version=CURRENT_VERSIONS[TERMS]
        )
    )
    with pytest.raises(ValidationError):
        service.execute(
            SetAccountConsentInput(
                owner_id=USER_B, consent_key=TERMS, granted=True, shown_version="v0"
            )
        )
    assert _version(repository, USER_A, TERMS) == CURRENT_VERSIONS[TERMS]
    assert _version(repository, USER_B, TERMS) is None


def test_the_versions_this_build_of_the_app_falls_back_on_are_the_ones_in_force() -> None:
    """`AccountConsentKeys.shownVersions` (the last resort when the catalogue could not be read)
    is raised together with `CURRENT_VERSIONS`."""
    import re
    from pathlib import Path

    source = Path(
        "apps/mobile_app/lib/features/account_consents/domain/account_consent_models.dart"
    ).read_text(encoding="utf-8")
    block = source[source.index("static const shownVersions") :]
    declared = dict(re.findall(r"(\w+): '?(v\d+|\w+)'?", block[: block.index("};")]))
    emergency = re.search(r"emergencyNoticeVersion = '(v\d+)'", source)
    assert emergency is not None
    assert declared["termsOfService"] == CURRENT_VERSIONS[AccountConsentType.TERMS_OF_SERVICE]
    assert declared["privacyPolicy"] == CURRENT_VERSIONS[AccountConsentType.PRIVACY_POLICY]
    assert emergency.group(1) == CURRENT_VERSIONS[AccountConsentType.EMERGENCY_NOTICE]
