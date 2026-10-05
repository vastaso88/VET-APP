from datetime import date

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    MEDICAL_RECORD_NOTICE_MARKER,
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryClinicalEventRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

EXPLANATION = (
    "Sono stati controllati i valori che dicono come lavorano i reni. Quasi tutto è "
    "nella norma. La creatinina è a 3,1 contro un massimo di 2,0: è un valore che sale "
    "quando i reni filtrano meno, e per Micia è coerente con il problema renale che già "
    "conosci. Al veterinario puoi chiedere ogni quanto conviene ricontrollare."
)
ONLY_QUESTIONS = "Capisco. Da quanto tempo lo vedi così? Mangia e beve normalmente?"
BLOOD_TAIL = "ULTIMA RIGA DEL REFERTO DEL SANGUE"
BLOOD_REPORT = "Creatinina 3,1 mg/dL (rif. 0,8-2,0) ALTO. " + "Altri valori nella norma. " * 70
URINE_REPORT = "Peso specifico 1.018 (rif. > 1.035) BASSO. UPC 0,5."


class ScriptedLLMClient:
    """Returns the scripted replies in order (the last one repeats)."""

    def __init__(self, *replies: str) -> None:
        self._replies = list(replies)
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        content = self._replies[min(len(self.requests), len(self._replies)) - 1]
        return LLMResponse(content=content, provider="fake", model="fake-model", token_count=1)


def _orchestrator(
    client: ScriptedLLMClient,
    *,
    events: list[ClinicalEvent] | None = None,
    attachments: list[ChatAttachment] | None = None,
) -> ChatOrchestrator:
    attachment_repository = InMemoryChatAttachmentRepository()
    for attachment in attachments or []:
        attachment_repository.save(attachment)
    return ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        medical_record_context_retriever=MedicalRecordContextRetriever(
            InMemoryClinicalEventRepository(seed=events or []),
            attachment_repository=attachment_repository,
        ),
    )


def _attachment(attachment_id: str, analysis: str | None) -> ChatAttachment:
    return ChatAttachment(
        id=attachment_id,
        owner_id="owner-1",
        pet_id="pet-1",
        storage_key=attachment_id,
        content_type="application/pdf",
        original_filename="referto.pdf",
        analysis=analysis,
        analysis_failed=analysis is None,
    )


def _records() -> tuple[list[ClinicalEvent], list[ChatAttachment]]:
    events = [
        ClinicalEvent(
            pet_id="pet-1",
            title="Esami del sangue",
            event_date=date(2026, 9, 12),
            attachment_id="att-blood",
        ),
        ClinicalEvent(
            pet_id="pet-1",
            title="Esame delle urine",
            event_date=date(2026, 9, 10),
            attachment_id="att-urine",
        ),
    ]
    attachments = [
        _attachment("att-blood", BLOOD_REPORT + BLOOD_TAIL),
        _attachment("att-urine", URINE_REPORT),
    ]
    return events, attachments


def _ask(
    message: str, *, consent: bool | None = True, **overrides: object
) -> ChatOrchestratorInput:
    values: dict[str, object] = {
        "user_message": message,
        "species": "cat",
        "pet_name": "Micia",
        "pet_id": "pet-1",
        "medical_record_consent": consent,
    }
    values.update(overrides)
    return ChatOrchestratorInput.model_validate(values)


def test_a_report_is_explained_from_its_full_text_and_the_reply_says_which_one() -> None:
    events, attachments = _records()
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask("Mi spieghi il referto degli esami del sangue?")
    )

    [request] = client.requests
    # The whole document, not an excerpt cut mid-table.
    assert BLOOD_TAIL in request.user_prompt
    assert URINE_REPORT not in request.user_prompt
    assert "«Esame delle urine» del 10 settembre 2026" in request.user_prompt
    assert "Do NOT ask about the animal's symptoms" in request.system_prompt
    assert result.answer.startswith("Ho letto «Esami del sangue» del 12 settembre 2026.\n\n")
    assert result.answer.endswith(EXPLANATION)
    assert result.mode == "natural"


def test_the_document_the_owner_names_is_the_one_that_is_read() -> None:
    events, attachments = _records()
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask("spiegami l'esame delle urine")
    )

    assert URINE_REPORT in client.requests[0].user_prompt
    assert BLOOD_TAIL not in client.requests[0].user_prompt
    assert result.answer.startswith("Ho letto «Esame delle urine» del 10 settembre 2026.")


def test_a_question_about_one_value_reads_the_document_that_reports_it() -> None:
    events, attachments = _records()
    attachments[1] = _attachment(
        "att-urine", URINE_REPORT + " Rapporto proteine/creatinina urinario: 0,5."
    )
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask("Cosa significa che la creatinina è alta?")
    )

    # The urine report only mentions the word; the blood report gives the value.
    assert result.answer.startswith("Ho letto «Esami del sangue» del 12 settembre 2026.\n")


def test_the_reading_line_is_not_repeated_within_a_conversation() -> None:
    events, attachments = _records()
    client = ScriptedLLMClient(EXPLANATION)
    line = "Ho letto «Esami del sangue» del 12 settembre 2026."

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask(
            "voglio solo capire cosa c'è scritto nel referto del sangue",
            conversation_history=[
                ChatMessage(role="user", content="spiegami il referto del sangue"),
                ChatMessage(role="assistant", content=f"{line}\n\n{EXPLANATION}"),
            ],
        )
    )

    assert line not in result.answer


def test_without_consent_the_chat_says_so_instead_of_asking_for_symptoms() -> None:
    events, attachments = _records()
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask("spiegami il referto degli esami", consent=False)
    )

    assert client.requests == []
    assert result.mode == "record_status"
    assert not result.ai_generated
    assert MEDICAL_RECORD_NOTICE_MARKER in result.answer
    assert "consenso non è attivo" in result.answer
    assert "?" not in result.answer


def test_a_record_whose_file_could_not_be_read_is_reported_as_such() -> None:
    events = [
        ClinicalEvent(
            pet_id="pet-1",
            title="Esami del sangue",
            event_date=date(2026, 9, 18),
            attachment_id="att-failed",
        )
    ]
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(
        client, events=events, attachments=[_attachment("att-failed", None)]
    ).answer(_ask("spiegami il referto degli esami del sangue"))

    assert client.requests == []
    assert "«Esami del sangue» del 18 settembre 2026" in result.answer
    assert "non sono riuscito a leggere il file" in result.answer


def test_with_no_documents_the_chat_says_there_is_nothing_to_explain() -> None:
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client).answer(_ask("mi spieghi il referto?", consent=None))

    assert client.requests == []
    assert "Non trovo documenti nella cartella clinica di Micia" in result.answer


def test_values_typed_by_the_owner_are_explained_even_without_any_record() -> None:
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client).answer(
        _ask("mi hanno detto creatinina 2,4 e urea 80, cosa vuol dire?", consent=None)
    )

    assert len(client.requests) == 1
    assert result.mode == "natural"
    assert not result.answer.startswith("Ho letto")


def test_a_document_attached_to_the_message_is_explained_and_acknowledged() -> None:
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client).answer(
        _ask(
            "cosa dice?",
            consent=None,
            photo_context="Referto esami ematochimici. Creatinina 1,0 mg/dL (rif. 0,5-1,5).",
        )
    )

    assert "Creatinina 1,0 mg/dL" in client.requests[0].user_prompt
    assert result.answer.startswith("Ho letto il documento che mi hai allegato.\n\n")


def test_an_attached_file_that_could_not_be_read_is_reported_as_such() -> None:
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client).answer(
        _ask("cosa dice questo esame?", consent=None, attachment_unreadable=True)
    )

    assert client.requests == []
    assert "Non sono riuscito a leggere il file che hai allegato" in result.answer


def test_a_direct_question_never_gets_a_reply_made_only_of_questions() -> None:
    client = ScriptedLLMClient(ONLY_QUESTIONS, EXPLANATION)

    result = _orchestrator(client).answer(
        _ask("quante volte al giorno deve mangiare?", consent=None)
    )

    assert len(client.requests) == 2
    assert "Do not ask for information before answering" in client.requests[0].system_prompt
    assert "your previous draft only asked questions" in client.requests[1].system_prompt
    assert result.answer == EXPLANATION


def test_a_vague_symptom_may_be_met_with_a_question() -> None:
    client = ScriptedLLMClient(ONLY_QUESTIONS)

    result = _orchestrator(client).answer(_ask("Micia è mogia", consent=None))

    assert len(client.requests) == 1
    assert result.answer == ONLY_QUESTIONS


def test_after_two_rounds_of_questions_the_chat_must_give_something_useful() -> None:
    client = ScriptedLLMClient(ONLY_QUESTIONS, EXPLANATION)

    result = _orchestrator(client).answer(
        _ask(
            "sembra stanca",
            consent=None,
            conversation_history=[
                ChatMessage(role="user", content="Micia è mogia"),
                ChatMessage(role="assistant", content=ONLY_QUESTIONS),
                ChatMessage(role="user", content="da ieri"),
                ChatMessage(role="assistant", content=ONLY_QUESTIONS),
            ],
        )
    )

    assert "must NOT ask anything more" in client.requests[0].system_prompt
    assert len(client.requests) == 2
    assert result.answer == EXPLANATION


def test_the_owner_saying_stop_ends_the_questions() -> None:
    client = ScriptedLLMClient(EXPLANATION)

    _orchestrator(client).answer(
        _ask(
            "non saprei dire altro",
            consent=None,
            conversation_history=[
                ChatMessage(role="user", content="Micia è mogia"),
                ChatMessage(role="assistant", content=ONLY_QUESTIONS),
            ],
        )
    )

    assert "Do not ask for information before answering" in client.requests[0].system_prompt


def test_an_emergency_named_in_a_report_request_is_still_escalated_first() -> None:
    events, attachments = _records()
    client = ScriptedLLMClient(EXPLANATION)

    result = _orchestrator(client, events=events, attachments=attachments).answer(
        _ask("mi spieghi il referto? intanto ha le convulsioni e non respira")
    )

    assert result.mode in {"triage", "safety_clarification"}
    assert client.requests == []
