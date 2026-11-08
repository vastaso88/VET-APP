"""Owner decision 2026-11-08: the microchip number never reaches the model
provider, nor the external literature services, on any path."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.application.services.vet_summary import VetSummaryInput, VetSummaryService
from packages.core.domain.conversation.answer_cache import normalize_question
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer

CHIP = "380260101234567"
GROUPED = "380 260 101 234 567"


class _Retriever:
    def __init__(self) -> None:
        self.queries: list[str] = []

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.queries.append(request.query)
        return []


class _RecordingConsent(ConsentInterpreter):
    def __init__(self) -> None:
        super().__init__()
        self.seen: list[str] = []

    def interpret(self, message: str) -> bool | None:
        self.seen.append(message)
        return super().interpret(message)


def _assert_clean(text: str) -> None:
    assert CHIP not in text and GROUPED not in text and "380260" not in text, text


def test_chat_never_sends_the_microchip_on_any_purpose_nor_to_the_literature_search() -> None:
    # The keyword helper fails, so the raw question would be the search query:
    # it must still be the anonymized one.
    client = RecordingLLMClient(by_purpose={"evidence_query": "not json"})
    retriever = _Retriever()
    orchestrator = ChatOrchestrator(
        client,
        retriever,
        RuleBasedPiiAnonymizer(),
        evidence_query_normalizer=EvidenceQueryNormalizer(client),
    )

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                f"Rex zoppica da due giorni dopo la passeggiata, microchip {CHIP}, "
                f"sul libretto è scritto {GROUPED}"
            ),
            species="Cane",
            pet_name="Rex",
            notes=f"Microchip: {CHIP}",
        )
    )

    assert client.requests
    for request in client.requests:
        _assert_clean(request.system_prompt)
        _assert_clean(request.user_prompt)
    for query in retriever.queries:
        _assert_clean(query)


def test_the_consent_reply_reaches_the_interpreter_anonymized() -> None:
    consent = _RecordingConsent()
    orchestrator = ChatOrchestrator(
        RecordingLLMClient(),
        _Retriever(),
        RuleBasedPiiAnonymizer(),
        consent_interpreter=consent,
        enable_interview_loop=True,
    )

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message=f"Sì, va bene. Il microchip è {CHIP}",
            species="Cane",
            pet_name="Rex",
            pet_id="pet-1",
            awaiting_medical_record_consent=True,
        )
    )

    assert consent.seen
    for text in consent.seen:
        _assert_clean(text)


def test_the_vet_summary_never_sends_the_microchip() -> None:
    client = RecordingLLMClient()
    conversations = InMemoryConversationRepository()
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Thor",
            species="Cane",
            notes=f"Microchip {CHIP}",
        )
    )
    conversation = Conversation(
        owner_id="owner-1",
        pet_id="pet-1",
        title="Zoppia",
        messages=[
            ChatMessage(
                role="user",
                content=f"Il veterinario ha letto il chip n. {GROUPED}",
                created_at=datetime(2026, 11, 1, 9, 0, tzinfo=UTC),
            )
        ],
    )
    conversations.save(conversation)

    VetSummaryService(conversations, pets, client, RuleBasedPiiAnonymizer()).execute(
        VetSummaryInput(owner_id="owner-1", conversation_id=conversation.id)
    )

    [request] = client.requests
    _assert_clean(request.user_prompt)


def test_a_document_text_is_summarized_without_the_microchip() -> None:
    client = RecordingLLMClient()

    DocumentSummarizer(client, RuleBasedPiiAnonymizer()).summarize(
        f"Libretto sanitario\nMicrochip: {CHIP}\nVaccino trivalente 12/03/2026", "Cane"
    )

    [request] = client.requests
    _assert_clean(request.user_prompt)
    assert "12/03/2026" in request.user_prompt


def test_the_answer_cache_key_carries_no_microchip() -> None:
    text = (
        RuleBasedPiiAnonymizer()
        .anonymize(PiiAnonymizationRequest(text=f"Il microchip {CHIP} va registrato?"))
        .anonymized_text
    )
    key: Any = normalize_question(text)
    _assert_clean(str(key))
