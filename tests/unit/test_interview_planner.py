from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.domain.situation.models import SituationModel
from packages.shared.errors.base import ProviderError


def test_asks_about_safety_critical_unknowns_first() -> None:
    planner = InterviewPlanner()
    situation = SituationModel(
        presenting_problem="tosse", safety_critical_unknowns=["respiro affannoso?"]
    )

    question = planner.next_question(situation)

    assert question == planner.QUESTION_TEMPLATES["safety_critical_unknowns"]


def test_asks_about_presenting_problem_when_nothing_else_is_missing_first() -> None:
    planner = InterviewPlanner()

    question = planner.next_question(SituationModel())

    assert question == planner.QUESTION_TEMPLATES["presenting_problem"]


def test_never_asks_about_a_field_already_known() -> None:
    planner = InterviewPlanner()
    situation = SituationModel(presenting_problem="tosse")

    question = planner.next_question(situation)

    assert question == planner.QUESTION_TEMPLATES["onset"]


def test_returns_none_when_every_tracked_field_is_known() -> None:
    planner = InterviewPlanner()
    situation = SituationModel(
        presenting_problem="tosse",
        onset="due giorni",
        observed_behaviours=["tossisce dopo bevuto"],
        associated_signs=["appetito normale"],
        environmental_changes=["nessun cambiamento"],
        known_medical_context="nessuna terapia",
        contexts=["in casa"],
    )

    assert planner.next_question(situation) is None


def test_asks_about_associated_signs_and_environmental_changes() -> None:
    # Real-world finding: these two fields already existed in
    # SituationModel but InterviewPlanner never asked about either — a
    # proper anamnesis needs both a review of systems ("anything else
    # changed?") and a check for recent triggers (diet, environment).
    planner = InterviewPlanner()
    situation = SituationModel(
        presenting_problem="tosse", onset="due giorni", observed_behaviours=["tossisce"]
    )

    question = planner.next_question(situation)

    assert question == planner.QUESTION_TEMPLATES["associated_signs"]


class _RecordingLLMClient:
    def __init__(self, reply: str) -> None:
        self._reply = reply
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(content=self._reply, provider="fake", model="fake-model", token_count=5)


class _FailingLLMClient:
    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        raise ProviderError("rate limited")


def test_skips_the_llm_call_when_there_is_no_case_context_yet() -> None:
    # 2026-09-21: with nothing case-specific known yet, the generic
    # template already fits as well as anything an LLM could produce —
    # calling out would only add latency for no benefit.
    client = _RecordingLLMClient("non dovrebbe mai arrivare qui")
    planner = InterviewPlanner(client)

    question = planner.next_question(SituationModel())

    assert question == planner.QUESTION_TEMPLATES["presenting_problem"]
    assert not client.requests


def test_phrases_the_question_for_the_case_when_an_llm_client_is_given() -> None:
    # Real-world finding: the fixed "observed_behaviours" template assumes
    # an ANIMAL is doing something, which reads as nonsense for a
    # husbandry/environmental case like cloudy tank water — nothing is
    # "doing" anything there. A real anamnesis phrases the question in
    # light of what's already known instead of reading from a fixed table.
    client = _RecordingLLMClient("La torbidità è comparsa subito o è peggiorata col tempo?")
    planner = InterviewPlanner(client)
    situation = SituationModel(
        presenting_problem="acqua dell'acquario torbida",
        onset="una settimana",
        working_domains=["husbandry_question"],
    )

    question = planner.next_question(situation)

    assert question == "La torbidità è comparsa subito o è peggiorata col tempo?"
    assert client.requests
    assert planner.field_for_question(question) == "observed_behaviours"


def test_falls_back_to_the_template_when_the_provider_fails() -> None:
    planner = InterviewPlanner(_FailingLLMClient())
    situation = SituationModel(presenting_problem="acqua dell'acquario torbida")

    question = planner.next_question(situation)

    assert question == planner.QUESTION_TEMPLATES["onset"]
