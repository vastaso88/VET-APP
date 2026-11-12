from packages.bootstrap.container import ApplicationContainer
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.application.services.send_chat_message import owner_names_for_anonymization
from packages.core.domain.conversation.models import ChatMessage
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer
from packages.shared.config.settings import Settings


class RecordingLLMClient:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content="Capisco, vediamo insieme.", provider="fake", model="fake-model", token_count=5
        )

    def everything_sent(self) -> str:
        return "\n".join(f"{r.system_prompt}\n{r.user_prompt}" for r in self.requests)


def _settings(**overrides: str) -> Settings:
    return Settings().model_copy(update=overrides)


def test_the_rule_based_anonymizer_is_the_default_backend() -> None:
    assert Settings.model_fields["pii_anonymizer_backend"].default == "rules"
    container = ApplicationContainer(_settings(pii_anonymizer_backend="rules"))

    assert isinstance(container.pii_anonymizer, RuleBasedPiiAnonymizer)


def test_noop_is_honoured_outside_production_only() -> None:
    development = ApplicationContainer(
        _settings(pii_anonymizer_backend="noop", environment="development")
    )

    assert isinstance(development.pii_anonymizer, NoopPiiAnonymizer)


def test_production_never_runs_without_anonymization() -> None:
    container = ApplicationContainer(_settings())
    container.settings = _settings(pii_anonymizer_backend="noop", environment="production")

    assert isinstance(container._build_pii_anonymizer(), RuleBasedPiiAnonymizer)


def test_an_unknown_backend_name_falls_back_to_the_rules() -> None:
    container = ApplicationContainer(_settings(pii_anonymizer_backend="qualcosa"))

    assert isinstance(container.pii_anonymizer, RuleBasedPiiAnonymizer)


def test_owner_name_is_redacted_unless_it_is_also_the_pets_name() -> None:
    assert owner_names_for_anonymization("Francesco Russo", pet_name="Thor") == ["Francesco Russo"]
    assert owner_names_for_anonymization("  ", pet_name="Thor") == []
    assert owner_names_for_anonymization(None, pet_name="Thor") == []
    # Redacting it would blank the one name the conversation is about.
    assert owner_names_for_anonymization("Luna", pet_name="luna") == []
    assert owner_names_for_anonymization("Luna Bianchi", pet_name="Luna") == []


def test_earlier_turns_reach_the_provider_anonymized() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), RuleBasedPiiAnonymizer())

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="dimmelo comunque",
            species="cat",
            pet_name="Luna",
            conversation_history=[
                ChatMessage(
                    role="user",
                    content=(
                        "Il gatto vomita da ieri. Il veterinario mi richiama al 347 1234567 "
                        "oppure scrive a mario.rossi@example.com"
                    ),
                ),
                ChatMessage(role="assistant", content="Prova a osservare l'appetito."),
            ],
        )
    )

    sent = client.everything_sent()
    assert "Il gatto vomita da ieri" in sent
    assert "347 1234567" not in sent
    assert "mario.rossi@example.com" not in sent
    assert "[TELEFONO]" in sent


def test_the_owners_own_name_never_reaches_the_provider() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), RuleBasedPiiAnonymizer())

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Sono Francesco Russo, il mio gatto mangia meno da 2 giorni e pesa 4,2 kg",
            species="cat",
            pet_name="Luna",
            owner_names=["Francesco Russo"],
            conversation_history=[
                ChatMessage(role="user", content="Buongiorno, qui francesco"),
                ChatMessage(role="assistant", content="Buongiorno! Dimmi pure."),
            ],
        )
    )

    sent = client.everything_sent().lower()
    assert "francesco" not in sent
    assert "russo" not in sent
    assert "4,2 kg" in sent
    assert "luna" in sent


def test_document_text_is_summarized_without_the_owners_name() -> None:
    client = RecordingLLMClient()
    summarizer = DocumentSummarizer(client, RuleBasedPiiAnonymizer())

    summarizer.summarize(
        "Referto del 12/03/2026. Paziente: Thor, cane. Consegnato a Russo Francesco. "
        "Creatinina 1,4 mg/dL. Meloxicam 0,1 mg/kg ogni 24 ore.",
        "dog",
        ["Francesco Russo"],
    )

    sent = client.requests[-1].user_prompt
    assert "Russo" not in sent and "Francesco" not in sent
    assert "12/03/2026" in sent
    assert "Creatinina 1,4 mg/dL" in sent
    assert "0,1 mg/kg ogni 24 ore" in sent
