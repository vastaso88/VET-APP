from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.states import ConversationState
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class FakeLLMClient:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content="Risposta sintetica con fonti.",
            provider="fake",
            model="fake-model",
            token_count=12,
            finish_reason="stop",
        )


class FakePiiAnonymizer:
    """Records every text it was asked to anonymize and replaces a fixed
    substring with a placeholder, so a test can assert the LLM never sees it."""

    def __init__(self, redact: str, replacement: str = "<REDACTED>") -> None:
        self.requests: list[PiiAnonymizationRequest] = []
        self._redact = redact
        self._replacement = replacement

    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        self.requests.append(request)
        text = request.text
        redaction_count = 0
        if self._redact in text:
            text = text.replace(self._redact, self._replacement)
            redaction_count = 1
        return PiiAnonymizationResult(anonymized_text=text, redaction_count=redaction_count)


def test_chat_orchestrator_asks_a_safety_clarification_before_escalating() -> None:
    # An ambiguous red-flag message asks one short, category-specific
    # question before deciding how urgently to respond (spec v3 §9) —
    # it must not jump straight to the scariest message.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il gatto ha un collasso improvviso",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "safety_clarification"
    assert result.provider == "rule-based"
    assert result.ai_generated is False
    assert result.awaiting_safety_clarification is True
    assert result.safety_clarification_category == "collapse"
    assert not client.requests


def test_chat_orchestrator_escalates_immediately_for_unambiguous_severe_messages() -> None:
    # No clarification question when the first message already leaves no
    # doubt — asking here would only delay real emergency care.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il gatto è incosciente e non si sveglia dopo il collasso",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_escalates_when_clarification_reply_is_unclear() -> None:
    # Fail closed: an off-topic or unclear reply must escalate, never be
    # read as reassurance.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Boh, non so cosa dirti",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "triage"
    assert result.state == ConversationState.POSSIBLE_URGENT_CASE


def test_chat_orchestrator_downgrades_to_moderate_caution_on_clear_benign_explanation() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="È sveglio, reattivo e cammina normale, è durato pochi secondi",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "safety_clarification_resolved"
    # A moderate resolution reassures first and keeps the vet-contact advice
    # conditional ("if it doesn't improve") — it must not open with the
    # unconditional urgent-triage wording used for genuine emergencies.
    assert "valutazione veterinaria immediata" not in result.answer.lower()
    assert "veterinario" in result.answer.lower()  # still vet-aware, never dismissive


def test_chat_orchestrator_escalates_when_reply_says_it_is_worsening() -> None:
    # A worsening marker overrides any reassuring wording in the same reply.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="È sveglio ma sta peggiorando",
            species="cat",
            pet_name="Luna",
            awaiting_safety_clarification=True,
            safety_clarification_category="collapse",
        )
    )

    assert result.mode == "triage"


def test_chat_orchestrator_never_downgrades_seizures() -> None:
    # No benign explanation exists for a seizure — the category has no
    # reassuring markers at all, so any reply escalates.
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Sono già finite ed è tornato vigile, prima volta che capita",
            species="dog",
            pet_name="Milo",
            awaiting_safety_clarification=True,
            safety_clarification_category="seizure",
        )
    )

    assert result.mode == "triage"


def test_chat_orchestrator_requires_sources_for_evidence_mode() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio gatto vomita da due giorni, cosa posso fare?",
            species="cat",
            pet_name="Luna",
        )
    )

    assert result.mode == "evidence"
    assert result.provider == "rule-based"
    assert result.ai_generated is False
    assert not result.sources
    assert not client.requests


def test_chat_orchestrator_uses_llm_when_sources_are_available() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni",
            species="dog",
            pet_name="Milo",
        )
    )

    assert result.mode == "evidence"
    assert result.provider == "fake"
    assert result.ai_generated is True
    assert result.sources
    assert client.requests


def test_chat_orchestrator_sends_anonymized_text_to_llm_not_raw_pii() -> None:
    client = FakeLLMClient()
    anonymizer = FakePiiAnonymizer(redact="0491234567", replacement="<TELEFONO>")
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), anonymizer)

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce, richiamami al 0491234567",
            species="dog",
            pet_name="Milo",
        )
    )

    assert anonymizer.requests
    assert client.requests
    sent_prompt = client.requests[0].user_prompt
    assert "0491234567" not in sent_prompt
    assert "<TELEFONO>" in sent_prompt
