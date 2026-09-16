from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.situation.models import SituationModel
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class ExtractionAwareLLMClient:
    """Returns valid situation-extraction JSON when asked to extract, otherwise
    a plain answer — mirrors how the real orchestrator uses the same LLMClient
    for two different roles."""

    def __init__(self, extraction_json: str, answer_text: str = "Risposta con fonti.") -> None:
        self._extraction_json = extraction_json
        self._answer_text = answer_text
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        if "extract structured case information" in request.system_prompt:
            content = self._extraction_json
        else:
            content = self._answer_text
        return LLMResponse(content=content, provider="fake", model="fake-model", token_count=10)


class FixedInterviewPlanner:
    def __init__(self, question: str | None) -> None:
        self.question = question

    def next_question(self, situation: SituationModel) -> str | None:
        return self.question


def test_interview_loop_asks_a_question_when_coverage_is_low() -> None:
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Da quanto tempo?"),
        enable_interview_loop=True,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(user_message="Il mio cane tossisce", species="dog", pet_name="Milo")
    )

    assert result.mode == "interview"
    assert result.state == ConversationState.NEED_MORE_INFORMATION
    assert result.answer == "Da quanto tempo?"
    assert result.interview_turns_used == 1


def test_interview_loop_proceeds_to_evidence_once_coverage_target_is_met() -> None:
    extraction_json = (
        '{"presenting_problem": "tosse", "onset": "due giorni", '
        '"observed_behaviours": ["tossisce dopo aver bevuto"], "contexts": ["in casa"], '
        '"known_medical_context": "nessuna", "working_domains": ["respiratory"]}'
    )
    client = ExtractionAwareLLMClient(extraction_json=extraction_json)
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Non dovrebbe essere chiesto"),
        enable_interview_loop=True,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "evidence"
    assert result.state == ConversationState.ADEQUATE_EVIDENCE_FOUND
    assert result.coverage_score == 1.0


def test_interview_loop_suggests_restart_when_budget_exhausted_and_problem_still_unknown() -> None:
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Domanda che non deve più essere fatta"),
        enable_interview_loop=True,
        max_interview_questions=1,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce",
            species="dog",
            pet_name="Milo",
            interview_turns_used=1,
        )
    )

    assert result.mode == "interview"
    assert result.state == ConversationState.INSUFFICIENT_EVIDENCE
    assert "ricominciare" in result.answer


def test_interview_loop_proceeds_to_evidence_when_budget_exhausted_but_problem_is_known() -> None:
    extraction_json = '{"presenting_problem": "tosse"}'
    client = ExtractionAwareLLMClient(extraction_json=extraction_json)
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Domanda che non deve più essere fatta"),
        enable_interview_loop=True,
        max_interview_questions=1,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce",
            species="dog",
            pet_name="Milo",
            interview_turns_used=1,
        )
    )

    assert result.mode == "evidence"


def test_interview_loop_is_disabled_by_default() -> None:
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Non deve mai essere chiamato"),
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce da due giorni", species="dog", pet_name="Milo"
        )
    )

    assert result.mode == "evidence"
    assert result.coverage_score is None


def test_interview_loop_with_the_real_planner_asks_presenting_problem_first() -> None:
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), enable_interview_loop=True
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(user_message="Il mio cane tossisce", species="dog", pet_name="Milo")
    )

    assert result.mode == "interview"
    assert "Cosa hai notato di preciso" in result.answer
