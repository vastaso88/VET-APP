"""The consent copy must not promise more than the system does.

The medical-record consent used to say that only the relevant information was
read, "mai l'intera cartella", while the chat gets the three most recent
records whatever the question is. These tests tie the numbers in the wording
to the limits the code applies, so changing one forces a look at the other
(and at the version number).
"""

import json
import re
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from packages.core.application.services.medical_record_context_retriever import (
    MAX_EXPLAINED_DOCUMENTS,
    MAX_ONGOING_CONDITIONS,
    MedicalRecordContextRetriever,
)
from packages.core.domain.consent.account_consent_text import (
    CONSENT_TEXT_IT as ACCOUNT_CONSENT_TEXT_IT,
)
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType, ConsentRecord
from packages.core.domain.medical_record.consent_text import (
    CONSENT_TEXT_IT,
    CURRENT_VERSION,
    INLINE_QUESTION_IT,
    effective_decision,
)
from packages.core.domain.medical_record.models import ClinicalEvent, PetCondition
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
    InMemoryPetConditionRepository,
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


def test_medical_record_wording_states_the_categories_dates_and_ongoing_conditions() -> None:
    # v3: the chat reads the category and the event date of each entry, and
    # the illnesses still ongoing (name and start date, at most five).
    repository = InMemoryClinicalEventRepository(
        seed=[
            ClinicalEvent(
                pet_id="pet-1",
                title="Emocromo",
                category="exam",
                subtype="blood",
                event_date=date(2026, 3, 12),
            )
        ]
    )
    conditions = InMemoryPetConditionRepository(
        seed=[
            PetCondition(pet_id="pet-1", name=f"Malattia {number}", started_on=date(2026, 1, 1))
            for number in range(MAX_ONGOING_CONDITIONS + 3)
        ]
    )

    summary = MedicalRecordContextRetriever(
        repository, condition_repository=conditions
    ).summarize_for_pet("pet-1")

    assert summary is not None
    assert "Emocromo (esame: analisi del sangue, 12/03/2026)" in summary
    condition_lines = summary.split("Malattie in corso:\n")[1].splitlines()
    assert len(condition_lines) == MAX_ONGOING_CONDITIONS == 5
    assert "dal 01/01/2026" in summary
    for text in (CONSENT_TEXT_IT, INLINE_QUESTION_IT):
        assert "malattie pregresse ancora in corso" in text
    assert "al massimo cinque" in CONSENT_TEXT_IT
    for words in ("categoria", "visita", "esame", "vaccino", "terapia", "data dell'evento"):
        assert words in CONSENT_TEXT_IT


def test_a_decision_taken_under_the_previous_wording_no_longer_counts() -> None:
    assert CURRENT_VERSION == "v3"
    assert effective_decision(ConsentRecord(granted=True, version="v2")) is None
    assert effective_decision(ConsentRecord(granted=False, version="v2")) is None
    assert effective_decision(ConsentRecord(granted=True, version=CURRENT_VERSION)) is True


def test_medical_record_wording_names_the_external_ai_provider_as_recipient() -> None:
    assert "intelligenza artificiale" in CONSENT_TEXT_IT
    assert "intelligenza artificiale" in INLINE_QUESTION_IT


def test_medical_record_version_moved_past_the_wording_that_over_promised() -> None:
    assert CURRENT_VERSION != "v1"


def test_the_card_in_the_app_shows_the_wording_on_record() -> None:
    source = _CONSENT_CARD.read_text(encoding="utf-8")
    assert "context.l10n.petsConsentFullText" in source
    catalog = _CONSENT_CARD.parents[4] / "l10n/app_it.arb"
    assert json.loads(catalog.read_text(encoding="utf-8"))["petsConsentFullText"] == CONSENT_TEXT_IT


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


def test_the_italian_chat_question_is_the_text_on_record() -> None:
    from packages.core.domain.localization import translate

    assert translate("consent_request", "it", pet_name="{pet_name}") == INLINE_QUESTION_IT
