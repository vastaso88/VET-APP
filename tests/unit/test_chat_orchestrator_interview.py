from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.situation.models import SituationModel
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class RecordingEvidenceRetriever(EvidenceRetriever):
    """Wraps a real retriever but records the query it was asked for, so a
    test can assert on what text retrieval actually saw."""

    def __init__(self, wrapped: EvidenceRetriever) -> None:
        self._wrapped = wrapped
        self.queries: list[str] = []

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.queries.append(request_data.query)
        return self._wrapped.retrieve(request_data)


class ExtractionAwareLLMClient:
    """Returns valid situation-extraction JSON when asked to extract, otherwise
    a plain answer — mirrors how the real orchestrator uses the same LLMClient
    for two different roles."""

    def __init__(
        self,
        extraction_json: str,
        answer_text: str = '{"supported_claims": ["Risposta con fonti [1]."]}',
    ) -> None:
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


class FixedInterviewPlanner(InterviewPlanner):
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


def test_interview_loop_is_skipped_entirely_for_husbandry_questions() -> None:
    # A husbandry/equipment question ("che lampada UVB comprare") isn't a
    # symptom being investigated, so it must never be routed through the
    # coverage/interview loop even when it's enabled for the conversation
    # — if it were, this test's FixedInterviewPlanner would return its
    # question instead of an evidence answer.
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Non dovrebbe essere chiesto"),
        enable_interview_loop=True,
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Che lampada UVB devo usare per il mio geco leopardino?",
            species="Rettili e anfibi",
            pet_name="Spike",
        )
    )

    assert result.mode == "evidence"
    assert result.answer != "Non dovrebbe essere chiesto"
    assert result.coverage_score is None
    assert result.sources


def test_interview_loop_proceeds_to_evidence_once_coverage_target_is_met() -> None:
    extraction_json = (
        '{"presenting_problem": "tosse", "onset": "due giorni", '
        '"observed_behaviours": ["tossisce dopo aver bevuto"], '
        '"associated_signs": ["appetito invariato"], '
        '"environmental_changes": ["nessun cambiamento recente"], '
        '"contexts": ["in casa"], '
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


def test_interview_loop_does_not_repeat_the_give_up_message_forever() -> None:
    # Real-world finding: extraction repeatedly failing (e.g. every reply
    # is too vague to parse) used to trap the conversation permanently —
    # every subsequent turn returned the identical "please rephrase"
    # message with no way out. The second time this dead end is hit, the
    # orchestrator must force progress instead of repeating itself.
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Domanda che non deve più essere fatta"),
        enable_interview_loop=True,
        max_interview_questions=1,
    )

    first = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Il mio cane tossisce",
            species="dog",
            pet_name="Milo",
            interview_turns_used=1,
        )
    )
    assert first.state == ConversationState.INSUFFICIENT_EVIDENCE

    second = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Non saprei cos'altro dirti",
            species="dog",
            pet_name="Milo",
            situation_model=first.situation_model,
            interview_turns_used=first.interview_turns_used,
        )
    )

    assert second.mode != "interview" or second.state != ConversationState.INSUFFICIENT_EVIDENCE
    assert second.answer != first.answer


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


def test_interview_loop_stays_on_topic_when_follow_up_reply_lacks_keywords() -> None:
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Prossima domanda"),
        enable_interview_loop=True,
    )
    first_turn = orchestrator.answer(
        ChatOrchestratorInput(user_message="Il mio cane tossisce", species="dog", pet_name="Milo")
    )
    assert first_turn.mode == "interview"

    second_turn = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Da due giorni, solo in casa",
            species="dog",
            pet_name="Milo",
            situation_model=first_turn.situation_model,
            interview_turns_used=first_turn.interview_turns_used,
        )
    )

    # A follow-up with no clinical keywords must not be re-routed to a
    # generic, un-grounded answer — it should continue the same case.
    assert second_turn.mode != "general"


def test_working_domains_with_an_unrecognized_label_does_not_break_intent_routing() -> None:
    # Real-world finding: extraction can invent a plausible but
    # non-canonical domain label (e.g. "gastroenterology" instead of
    # "clinical_question") despite the prompt asking for exactly the
    # fixed set — a follow-up reply must not be routed using that
    # unrecognized value, which would silently misroute evidence
    # retrieval on that turn.
    client = ExtractionAwareLLMClient(extraction_json="{}")
    orchestrator = ChatOrchestrator(
        client,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        interview_planner=FixedInterviewPlanner("Prossima domanda"),
        enable_interview_loop=True,
    )
    situation = SituationModel(
        presenting_problem="tosse", working_domains=["gastroenterology", "clinical_question"]
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Da due giorni",
            species="dog",
            pet_name="Milo",
            situation_model=situation,
            interview_turns_used=1,
        )
    )

    assert result.mode != "general"


def test_interview_loop_never_repeats_the_same_question_when_a_field_never_fills() -> None:
    # Regression: extraction can legitimately fail to populate a field even
    # from a valid answer (e.g. a plain "no"), which must not make the real
    # InterviewPlanner ask the identical question every remaining turn.
    class NeverFillsAfterFirstTurn:
        def __init__(self) -> None:
            self.calls = 0

        def generate(self, request: LLMGenerationRequest) -> LLMResponse:
            if "extract structured case information" in request.system_prompt:
                self.calls += 1
                if self.calls == 1:
                    content = (
                        '{"presenting_problem": "non mangia", "onset": "due giorni", '
                        '"observed_behaviours": ["abbattuto"], '
                        '"working_domains": ["nutrition_question"]}'
                    )
                else:
                    content = "{}"
            else:
                content = "Risposta finale con [1]."
            return LLMResponse(content=content, provider="fake", model="fake-model", token_count=10)

    orchestrator = ChatOrchestrator(
        NeverFillsAfterFirstTurn(),
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        enable_interview_loop=True,
    )

    situation = None
    turns = 0
    questions_asked = []
    for message in ["Il mio cane non mangia da due giorni", "No, niente di che", "Boh non so"]:
        result = orchestrator.answer(
            ChatOrchestratorInput(
                user_message=message,
                species="dog",
                pet_name="Moka",
                situation_model=situation,
                interview_turns_used=turns,
            )
        )
        if result.mode == "interview":
            questions_asked.append(result.answer)
        situation = result.situation_model
        turns = result.interview_turns_used

    assert len(questions_asked) == len(set(questions_asked)), "a question was repeated"


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


def test_evidence_query_uses_accumulated_symptoms_not_just_the_final_reply() -> None:
    # Real-world finding: by the time the interview loop reaches evidence
    # mode, the triggering message is often a context-only reply ("succede
    # sempre in casa") with no symptom words at all — the symptoms the
    # owner actually reported live in the accumulated SituationModel from
    # earlier turns. Using only the raw current message starved retrieval
    # (and the synthesizer) of the real case.
    client = ExtractionAwareLLMClient(extraction_json="{}")
    wrapped_retriever = RecordingEvidenceRetriever(InMemoryEvidenceRetriever())
    orchestrator = ChatOrchestrator(
        client,
        wrapped_retriever,
        NoopPiiAnonymizer(),
        enable_interview_loop=True,
        max_interview_questions=1,
    )
    situation = SituationModel(
        presenting_problem="vomito e diarrea da due giorni",
        working_domains=["clinical_question"],
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Succede sempre in casa, niente di strano nell'ambiente",
            species="dog",
            pet_name="Milo",
            situation_model=situation,
            interview_turns_used=1,
        )
    )

    assert result.mode == "evidence"
    assert wrapped_retriever.queries
    assert "vomito" in wrapped_retriever.queries[-1]
