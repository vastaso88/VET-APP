"""R25, option A (owner decision 2026-11-07): the profile's free notes and
the reminders, therapies included, reach the model only with the record
consent granted under the current text. Name, species, breed, sex, age and
weight stay available. The same rule for the summary written for the vet."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.vet_summary import VetSummaryInput, VetSummaryService
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.localization import translate
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

NOTES = "Diagnosi MBD lieve 2024, dieta renale"
THERAPY = "Antibiotico"


def _consent(
    granted: bool | None, version: str = CURRENT_VERSION
) -> MedicalRecordConsentRecord | None:
    if granted is None:
        return None
    return MedicalRecordConsentRecord(granted=granted, version=version)


def _pet(consent: MedicalRecordConsentRecord | None) -> PetProfile:
    return PetProfile(
        id="pet-1",
        owner_id="owner-1",
        name="Rex",
        species="Cane",
        breed="Beagle",
        sex="Maschio",
        age_years=4,
        weight_label="12 kg",
        notes=NOTES,
        medical_record_consent=consent,
    )


def _chat(consent: MedicalRecordConsentRecord | None) -> str:
    """The prompt the model receives for one ordinary message."""
    client = RecordingLLMClient()
    pets = InMemoryPetProfileRepository()
    pets.save(_pet(consent))
    reminders = InMemoryReminderRepository()
    today = datetime.now(UTC).date()
    reminders.save(
        Reminder(
            owner_id="owner-1",
            pet_id="pet-1",
            title=THERAPY,
            due_date=today - timedelta(days=1),
            kind="course",
            course_duration_days=7,
        )
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        reminder_context_retriever=ReminderContextRetriever(reminders),
    )
    service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="Rex ha le feci molli da ieri"
        )
    )
    return client.requests[-1].user_prompt


def _identity_present(prompt: str) -> None:
    for expected in ("Rex", "Cane", "Breed: Beagle", "Sex: Maschio", "Weight: 12 kg"):
        assert expected in prompt, expected
    assert "4" in prompt  # the age


def test_with_the_consent_denied_notes_and_reminders_stay_home() -> None:
    prompt = _chat(_consent(False))

    assert NOTES not in prompt and "Owner notes" not in prompt
    assert THERAPY not in prompt
    _identity_present(prompt)


def test_with_no_decision_yet_notes_and_reminders_stay_home() -> None:
    prompt = _chat(None)

    assert NOTES not in prompt and THERAPY not in prompt
    _identity_present(prompt)


def test_a_decision_under_an_older_text_does_not_count() -> None:
    prompt = _chat(_consent(True, version="v2"))

    assert NOTES not in prompt and THERAPY not in prompt


def test_with_the_consent_granted_notes_and_reminders_travel() -> None:
    prompt = _chat(_consent(True))

    assert f"Owner notes: {NOTES}" in prompt
    assert f"{THERAPY} (terapia in corso" in prompt
    _identity_present(prompt)


def test_the_record_notice_stays_true_without_the_consent() -> None:
    # "Rispondo senza i suoi referti": nothing of the record, the notes or the
    # reminders is in the prompt when the fixed notice could be shown.
    notice = translate("record_notice", "it", pet_name="Rex")
    assert "senza i suoi referti" in notice
    prompt = _chat(_consent(False))
    assert NOTES not in prompt and THERAPY not in prompt


# --- the summary for the vet ---------------------------------------------------


def _summary_prompt(consent: MedicalRecordConsentRecord | None) -> str:
    client = RecordingLLMClient()
    conversations = InMemoryConversationRepository()
    pets = InMemoryPetProfileRepository()
    pets.save(_pet(consent))
    conversation = conversations.save(
        Conversation(
            owner_id="owner-1",
            pet_id="pet-1",
            title="Feci molli",
            messages=[ChatMessage(role="user", content="Rex ha le feci molli da ieri")],
        )
    )
    VetSummaryService(conversations, pets, client, NoopPiiAnonymizer()).execute(
        VetSummaryInput(owner_id="owner-1", conversation_id=conversation.id)
    )
    return client.requests[-1].user_prompt


def test_the_vet_summary_reads_the_notes_only_with_the_consent() -> None:
    assert NOTES not in _summary_prompt(_consent(False))
    assert NOTES not in _summary_prompt(None)
    assert NOTES in _summary_prompt(_consent(True))
    assert "Rex" in _summary_prompt(_consent(False))
