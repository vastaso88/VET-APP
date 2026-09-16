from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.domain.situation.models import SituationModel


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
        known_medical_context="nessuna terapia",
        contexts=["in casa"],
    )

    assert planner.next_question(situation) is None
