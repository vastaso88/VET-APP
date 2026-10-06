"""The consent copy must not promise more than the system does.

The medical-record consent used to say that only the relevant information was
read, "mai l'intera cartella", while the chat gets the three most recent
records whatever the question is. These tests tie the numbers in the wording
to the limits the code applies, so changing one forces a look at the other
(and at the version number).
"""

import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

from packages.core.application.services.medical_record_context_retriever import (
    MAX_EXPLAINED_DOCUMENTS,
    MedicalRecordContextRetriever,
)
from packages.core.domain.consent.account_consent_text import (
    CONSENT_TEXT_IT as ACCOUNT_CONSENT_TEXT_IT,
)
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.core.domain.medical_record.consent_text import (
    CONSENT_TEXT_IT,
    CURRENT_VERSION,
    INLINE_QUESTION_IT,
)
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
)

_CONSENT_CARD = (
    Path(__file__).resolve().parents[2]
    / "apps/mobile_app/lib/features/pets/presentation/widgets/medical_record_consent_card.dart"
)


def test_medical_record_wording_no_longer_promises_a_selection_it_does_not_make() -> None:
    for text in (CONSENT_TEXT_IT, INLINE_QUESTION_IT):
        assert "mai l'intera cartella" not in text
        assert "solo le informazioni rilevanti" not in text


def test_medical_record_wording_states_how_much_the_chat_reads() -> None:
    repository = InMemoryClinicalEventRepository(
        seed=[
            ClinicalEvent(
                pet_id="pet-1",
                title=f"Evento {number}",
                created_at=datetime.now(UTC) - timedelta(days=number),
            )
            for number in range(5)
        ]
    )

    summary = MedicalRecordContextRetriever(repository).summarize_for_pet("pet-1")

    assert summary is not None
    assert len([line for line in summary.splitlines() if line.startswith("- ")]) == 3
    assert "tre voci" in CONSENT_TEXT_IT
    assert "tre voci" in INLINE_QUESTION_IT
    assert MAX_EXPLAINED_DOCUMENTS == 2
    assert "al massimo due" in CONSENT_TEXT_IT


def test_medical_record_wording_names_the_external_ai_provider_as_recipient() -> None:
    assert "intelligenza artificiale" in CONSENT_TEXT_IT
    assert "intelligenza artificiale" in INLINE_QUESTION_IT


def test_medical_record_version_moved_past_the_wording_that_over_promised() -> None:
    assert CURRENT_VERSION != "v1"


def test_the_card_in_the_app_shows_the_wording_on_record() -> None:
    source = _CONSENT_CARD.read_text(encoding="utf-8")
    declaration = re.search(
        r"const _approvedConsentText =((?:\s*(?:\"[^\"]*\"|'[^']*'))+)\s*;", source
    )
    assert declaration is not None, "the card no longer declares _approvedConsentText"

    segments = re.findall(r"\"([^\"]*)\"|'([^']*)'", declaration.group(1))

    assert "".join(double or single for double, single in segments) == CONSENT_TEXT_IT


def test_privacy_text_does_not_promise_a_page_that_does_not_exist() -> None:
    assert "consultabile" not in ACCOUNT_CONSENT_TEXT_IT[AccountConsentType.PRIVACY_POLICY]
    assert CURRENT_VERSIONS[AccountConsentType.PRIVACY_POLICY] != "v1"


_PET_STORE = (
    Path(__file__).resolve().parents[2]
    / "apps/mobile_app/lib/features/pets/data/pet_demo_store.dart"
)


def test_the_app_reads_decisions_under_the_same_consent_version_as_the_backend() -> None:
    # The app reads the consent straight from Supabase and treats a decision
    # under any other version as "not decided": if this constant lagged
    # behind CURRENT_VERSION, every consent would silently read as undecided.
    source = _PET_STORE.read_text(encoding="utf-8")
    declaration = re.search(r"const _currentConsentVersion = '([^']+)';", source)
    assert declaration is not None, "pet_demo_store.dart no longer declares _currentConsentVersion"

    assert declaration.group(1) == CURRENT_VERSION
