import string

from packages.core.domain import localization
from packages.core.domain.localization_fr import (
    CLARIFYING_QUESTIONS_FR,
    CONNECTORS_FR,
    MESSAGES_FR,
    QUESTION_TEMPLATES_FR,
)


def _fields(text: str) -> set[str]:
    return {name for _, name, _, _ in string.Formatter().parse(text) if name}


def test_french_messages_cover_every_key_with_the_same_placeholders() -> None:
    source = {key: values["it"] for key, values in localization._MESSAGES.items()}
    assert set(MESSAGES_FR) == set(source)
    for key, text in MESSAGES_FR.items():
        assert text.strip(), key
        assert _fields(text) == _fields(source[key]), key


def test_french_messages_keep_the_detection_markers_and_sections() -> None:
    assert MESSAGES_FR["weight_marker"] in MESSAGES_FR["weight_suggestion"]
    assert MESSAGES_FR["record_marker"] in MESSAGES_FR["record_notice"]
    sections = localization._MESSAGES["summary_sections"]["it"].split("|")
    assert len(MESSAGES_FR["summary_sections"].split("|")) == len(sections)


def test_french_side_catalogs_have_the_italian_keys() -> None:
    from packages.core.application.services.interview_planner import InterviewPlanner
    from packages.core.application.services.response_generator import _CONNECTORS
    from packages.core.domain.safety.triage_clarification import CLARIFYING_QUESTIONS

    assert set(CONNECTORS_FR) == set(_CONNECTORS["it"])
    assert set(QUESTION_TEMPLATES_FR) == set(InterviewPlanner.QUESTION_TEMPLATES)
    assert set(CLARIFYING_QUESTIONS_FR) == set(CLARIFYING_QUESTIONS)
