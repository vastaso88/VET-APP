"""What the chat's LLM prompt actually contains about the pet: profile
fields, reminders, consent-gated medical records, and the missing-weight
suggestion (2026-10-03)."""

from datetime import UTC, date, datetime, timedelta

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    MEDICAL_RECORD_NOTICE_MARKER,
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.medical_record_context_retriever import (
    MAX_DOCUMENT_SUMMARY_CHARS,
    MedicalRecordContextRetriever,
)
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.medical_record.models import ClinicalEvent, MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails, PetProfile
from packages.core.domain.pet_profile.weight import WEIGHT_SUGGESTION_MARKER, is_weight_relevant
from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

TODAY = date(2026, 10, 3)
BLOOD_TEST_TEXT = "Esame emocromocitometrico del 12/09/2026: ematocrito 38% (37-55)."


class RecordingLLMClient:
    def __init__(self, content: str = "Risposta in prosa senza citazioni.") -> None:
        self._content = content
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content=self._content, provider="fake", model="fake-model", token_count=5
        )


def _records_retriever() -> MedicalRecordContextRetriever:
    attachments = InMemoryChatAttachmentRepository()
    attachments.save(
        ChatAttachment(
            id="att-1",
            owner_id="owner-1",
            pet_id="pet-1",
            storage_key="att-1",
            content_type="image/jpeg",
            original_filename="esame.jpg",
            analysis=BLOOD_TEST_TEXT,
        )
    )
    events = InMemoryClinicalEventRepository(
        seed=[
            ClinicalEvent(
                pet_id="pet-1", title="esame.jpg", subtitle="JPG · 1 MB", attachment_id="att-1"
            )
        ]
    )
    return MedicalRecordContextRetriever(events, attachment_repository=attachments)


def _orchestrator(
    client: RecordingLLMClient, retriever: MedicalRecordContextRetriever | None = None
) -> ChatOrchestrator:
    return ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        medical_record_context_retriever=retriever,
    )


def _prompt(client: RecordingLLMClient) -> str:
    return client.requests[-1].user_prompt


# --- profile fields ---------------------------------------------------------


def test_prompt_carries_the_full_pet_profile() -> None:
    client = RecordingLLMClient()

    _orchestrator(client).answer(
        ChatOrchestratorInput(
            user_message="Milo si gratta spesso l'orecchio da ieri",
            species="Cane",
            pet_name="Milo",
            breed="Beagle",
            birth_date_label="Feb 2022",
            sex="Maschio",
            weight_label="12,5 kg",
            dog_size_category="Media",
            notes="Stomaco delicato",
            today=TODAY,
        )
    )

    prompt = _prompt(client)
    for expected in (
        "Breed: Beagle",
        "Born: Feb 2022",
        "Sex: Maschio",
        "Weight: 12,5 kg",
        "Size category: Media",
        "Owner notes: Stomaco delicato",
        "Today's date: 2026-10-03",
    ):
        assert expected in prompt


def test_prompt_omits_profile_fields_the_owner_never_filled_in() -> None:
    client = RecordingLLMClient()

    _orchestrator(client).answer(
        ChatOrchestratorInput(
            user_message="Milo si gratta spesso l'orecchio da ieri", species="Cane", pet_name="Milo"
        )
    )

    prompt = _prompt(client)
    assert "Weight:" not in prompt
    assert "Sex:" not in prompt
    assert "None" not in prompt


def test_habitat_uses_the_numeric_dimensions_the_mobile_app_stores() -> None:
    client = RecordingLLMClient()

    _orchestrator(client).answer(
        ChatOrchestratorInput(
            user_message="I pesci stanno sempre in superficie da stamattina",
            species="Pesce",
            pet_name="Acquario del salotto",
            habitat=HabitatDetails(length_cm=60, width_cm=30, height_cm=36, volume_liters=54),
            aquarium_stock=[FishStock(species="Guppy", male_count=2, female_count=4)],
        )
    )

    assert "dimensions 60x30x36 cm" in _prompt(client)
    assert "54 liters" in _prompt(client)


def test_habitat_round_trips_the_mobile_apps_json_shape_without_losing_fields() -> None:
    # Real-world finding: the backend model used to know only a free-text
    # `dimensions`, so re-saving a pet (e.g. toggling the medical-record
    # consent) rewrote `habitat` without the tank's length/width/height.
    row = {
        "id": "pet-1",
        "owner_id": "owner-1",
        "name": "Acquario",
        "species": "Pesce",
        "weight_label": "",
        "habitat": {
            "length_cm": 60,
            "width_cm": 30,
            "height_cm": 36,
            "volume_liters": 54,
            "temperature_label": "24-26°C",
            "substrate": "Ghiaia",
            "notes": "Filtro esterno",
        },
    }

    dumped = PetProfile.model_validate(row).model_dump(mode="json")

    for key, value in row["habitat"].items():  # type: ignore[attr-defined]
        assert dumped["habitat"][key] == value


# --- reminders --------------------------------------------------------------


def _reminder(title: str, due: date, **extra: object) -> Reminder:
    return Reminder(owner_id="owner-1", pet_id="pet-1", title=title, due_date=due, **extra)  # type: ignore[arg-type]


def test_reminder_summary_keeps_only_active_relevant_reminders_of_this_pet() -> None:
    repository = InMemoryReminderRepository()
    repository.save(_reminder("Vaccino di richiamo", TODAY + timedelta(days=10)))
    repository.save(
        _reminder(
            "Antibiotico",
            TODAY - timedelta(days=2),
            kind="course",
            course_duration_days=7,
            notes="2 volte al giorno",
        )
    )
    repository.save(_reminder("Già fatto", TODAY + timedelta(days=3), is_done=True))
    repository.save(_reminder("Vecchio", TODAY - timedelta(days=90)))
    repository.save(_reminder("Lontano", TODAY + timedelta(days=200)))
    repository.save(Reminder(owner_id="owner-1", pet_id="pet-2", title="Altro pet", due_date=TODAY))

    summary = ReminderContextRetriever(repository).summarize_for_pet("owner-1", "pet-1", TODAY)

    assert summary is not None
    assert "Antibiotico (terapia in corso dal 2026-10-01 al 2026-10-08) — 2 volte" in summary
    assert "Vaccino di richiamo (previsto per il 2026-10-13)" in summary
    for excluded in ("Già fatto", "Vecchio", "Lontano", "Altro pet"):
        assert excluded not in summary


def test_reminder_summary_is_none_when_nothing_is_relevant() -> None:
    assert (
        ReminderContextRetriever(InMemoryReminderRepository()).summarize_for_pet(
            "owner-1", "pet-1", TODAY
        )
        is None
    )


def test_send_chat_message_feeds_profile_and_reminders_into_the_prompt() -> None:
    client = RecordingLLMClient()
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Rex",
            species="Cane",
            sex="Maschio",
            weight_label="30 kg",
        )
    )
    reminders = InMemoryReminderRepository()
    today = datetime.now(UTC).date()
    reminders.save(
        _reminder("Antibiotico", today - timedelta(days=1), kind="course", course_duration_days=7)
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        _orchestrator(client),
        pets,
        reminder_context_retriever=ReminderContextRetriever(reminders),
    )

    service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="Rex ha ancora le feci molli da ieri"
        )
    )

    prompt = _prompt(client)
    assert "Weight: 30 kg" in prompt
    assert "Sex: Maschio" in prompt
    assert "Antibiotico (terapia in corso" in prompt


# --- medical records & consent ----------------------------------------------


def _ask_about_exam(client: RecordingLLMClient, consent: bool | None) -> str:
    _orchestrator(client, _records_retriever()).answer(
        ChatOrchestratorInput(
            user_message="Rex è stanco da tre giorni e mangia poco, cosa posso fare?",
            species="Cane",
            pet_name="Rex",
            pet_id="pet-1",
            weight_label="30 kg",
            medical_record_consent=consent,
        )
    )
    return _prompt(client)


def test_with_consent_the_uploaded_documents_text_reaches_the_prompt() -> None:
    prompt = _ask_about_exam(RecordingLLMClient(), consent=True)

    assert BLOOD_TEST_TEXT in prompt
    assert "NOT given you permission" not in prompt


def test_without_consent_no_record_content_reaches_the_prompt_and_the_chat_is_told_why() -> None:
    for consent in (None, False):
        prompt = _ask_about_exam(RecordingLLMClient(), consent=consent)

        assert BLOOD_TEST_TEXT not in prompt
        assert "esame.jpg" not in prompt
        assert "1 document(s)" in prompt
        assert "NOT given you permission" in prompt


def test_without_consent_the_reply_says_so_transparently_once_per_conversation() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, _records_retriever())
    question = ChatOrchestratorInput(
        user_message="Rex è stanco da tre giorni e mangia poco, cosa posso fare?",
        species="Cane",
        pet_name="Rex",
        pet_id="pet-1",
        weight_label="30 kg",
    )

    first = orchestrator.answer(question)

    assert MEDICAL_RECORD_NOTICE_MARKER in first.answer
    assert "consenso non è attivo" in first.answer

    second = orchestrator.answer(
        question.model_copy(
            update={
                "conversation_history": [
                    ChatMessage(role="user", content=question.user_message),
                    ChatMessage(role="assistant", content=first.answer),
                ]
            }
        )
    )

    assert MEDICAL_RECORD_NOTICE_MARKER not in second.answer


def test_no_notice_when_consent_is_granted_or_the_topic_is_not_clinical() -> None:
    client = RecordingLLMClient()
    orchestrator = _orchestrator(client, _records_retriever())
    base = {"species": "Cane", "pet_name": "Rex", "pet_id": "pet-1", "weight_label": "30 kg"}

    granted = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Rex è stanco da tre giorni e mangia poco",
            medical_record_consent=True,
            **base,  # type: ignore[arg-type]
        )
    )
    behaviour = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Rex abbaia e graffia la porta quando resta solo, ha ansia?",
            **base,  # type: ignore[arg-type]
        )
    )

    assert MEDICAL_RECORD_NOTICE_MARKER not in granted.answer
    assert MEDICAL_RECORD_NOTICE_MARKER not in behaviour.answer


def test_without_consent_and_without_records_nothing_is_said_about_records() -> None:
    client = RecordingLLMClient()
    retriever = MedicalRecordContextRetriever(InMemoryClinicalEventRepository())

    _orchestrator(client, retriever).answer(
        ChatOrchestratorInput(
            user_message="Rex è stanco da tre giorni e mangia poco",
            species="Cane",
            pet_name="Rex",
            pet_id="pet-1",
        )
    )

    assert "Medical records" not in _prompt(client)


def test_pet_level_revocation_keeps_records_out_of_the_prompt() -> None:
    client = RecordingLLMClient()
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Rex",
            species="Cane",
            weight_label="30 kg",
            medical_record_consent=MedicalRecordConsentRecord(granted=False, version="v1"),
        )
    )
    service = SendChatMessageService(
        InMemoryConversationRepository(), _orchestrator(client, _records_retriever()), pets
    )

    service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="Rex è stanco da tre giorni"
        )
    )

    assert BLOOD_TEST_TEXT not in _prompt(client)


def test_a_document_summary_from_another_pets_attachment_is_never_used() -> None:
    attachments = InMemoryChatAttachmentRepository()
    attachments.save(
        ChatAttachment(
            id="att-x",
            owner_id="owner-2",
            pet_id="pet-other",
            storage_key="att-x",
            content_type="image/jpeg",
            original_filename="x.jpg",
            analysis="contenuto di un altro animale",
        )
    )
    events = InMemoryClinicalEventRepository(
        seed=[ClinicalEvent(pet_id="pet-1", title="Referto", attachment_id="att-x")]
    )

    summary = MedicalRecordContextRetriever(
        events, attachment_repository=attachments
    ).summarize_for_pet("pet-1")

    # The record is listed, with an honest note that its file was not
    # read — and nothing of the other pet's document.
    assert summary is not None
    assert summary.startswith("- Referto")
    assert "contenuto di un altro animale" not in summary
    assert "non è stato letto" in summary


def test_long_document_summaries_are_clipped() -> None:
    attachments = InMemoryChatAttachmentRepository()
    attachments.save(
        ChatAttachment(
            id="att-1",
            owner_id="owner-1",
            pet_id="pet-1",
            storage_key="att-1",
            content_type="image/png",
            original_filename="lungo.png",
            analysis="x" * (MAX_DOCUMENT_SUMMARY_CHARS * 3),
        )
    )
    events = InMemoryClinicalEventRepository(
        seed=[ClinicalEvent(pet_id="pet-1", title="Referto", attachment_id="att-1")]
    )

    summary = MedicalRecordContextRetriever(
        events, attachment_repository=attachments
    ).summarize_for_pet("pet-1")

    assert summary is not None
    assert len(summary) < MAX_DOCUMENT_SUMMARY_CHARS + 100


# --- missing weight ---------------------------------------------------------


def _answer(message: str, **extra: object) -> str:
    client = RecordingLLMClient()
    fields: dict[str, object] = {"user_message": message, "species": "Cane", "pet_name": "Rex"}
    fields.update(extra)
    return _orchestrator(client).answer(ChatOrchestratorInput(**fields)).answer  # type: ignore[arg-type]


def test_missing_weight_is_suggested_when_the_topic_depends_on_it() -> None:
    for message in (
        "Quanto cibo devo dare a Rex ogni giorno?",
        "Quante crocchette devo dare a Rex al giorno?",
        "Rex mi sembra in sovrappeso, come posso aiutarlo?",
        "Quale antiparassitario mi consigli per Rex in estate?",
        "Rex deve fare un'anestesia per la pulizia dei denti, è rischiosa?",
    ):
        assert WEIGHT_SUGGESTION_MARKER in _answer(message), message


def test_missing_weight_is_suggested_on_a_dosage_request_too() -> None:
    answer = _answer("Che dose di antinfiammatorio posso dare a Rex?")

    assert "Non ti do una cifra precisa" in answer
    assert WEIGHT_SUGGESTION_MARKER in answer


def test_no_suggestion_when_the_weight_is_in_the_profile() -> None:
    answer = _answer("Quanto cibo devo dare a Rex ogni giorno?", weight_label="30 kg")

    assert WEIGHT_SUGGESTION_MARKER not in answer


def test_no_suggestion_when_the_topic_does_not_depend_on_weight() -> None:
    assert WEIGHT_SUGGESTION_MARKER not in _answer("Rex abbaia quando resta solo in casa")


def test_the_suggestion_is_made_only_once_per_conversation() -> None:
    first = _answer("Quanto cibo devo dare a Rex ogni giorno?")
    assert WEIGHT_SUGGESTION_MARKER in first

    second = _answer(
        "E per la dieta di mantenimento invece?",
        conversation_history=[
            ChatMessage(role="user", content="Quanto cibo devo dare a Rex ogni giorno?"),
            ChatMessage(role="assistant", content=first),
        ],
    )

    assert WEIGHT_SUGGESTION_MARKER not in second


def test_no_weight_suggestion_for_an_aquarium() -> None:
    answer = _answer(
        "Che alimentazione consigli per i miei pesci?",
        species="Pesce",
        pet_name="Acquario",
        aquarium_stock=[FishStock(species="Guppy", male_count=2, female_count=4)],
    )

    assert WEIGHT_SUGGESTION_MARKER not in answer


def test_no_weight_suggestion_on_an_emergency_escalation() -> None:
    client = RecordingLLMClient()
    result = _orchestrator(client).answer(
        ChatOrchestratorInput(
            user_message="Che dose di ibuprofene posso dare a Rex?", species="Cane", pet_name="Rex"
        )
    )

    assert result.mode == "triage"
    assert WEIGHT_SUGGESTION_MARKER not in result.answer


def test_weight_relevance_does_not_fire_on_lookalike_words() -> None:
    assert not is_weight_relevant("Il mio pesce nuota storto")
    assert not is_weight_relevant("Rex è un cane pesante da gestire al guinzaglio")
    assert is_weight_relevant("Devo mettere lo spot-on a Rex")
