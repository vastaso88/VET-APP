import pytest

from packages.core.application.services.safety_gate import SafetyGate
from packages.core.domain.safety.triage_clarification import (
    categorize as categorize_safety_flags,
)
from packages.core.domain.safety.triage_clarification import requires_immediate_escalation


@pytest.mark.parametrize(
    "message",
    [
        "respira a bocca aperta e fa molta fatica a respirare",
        "fa fatica a respirare da stamattina",
        "respira a fatica",
        "non riesce a respirare bene",
    ],
)
def test_laboured_breathing_is_flagged_in_the_owners_own_words(message: str) -> None:
    # 2026-10-05 evaluation: none of these raised a flag for a cat.
    flags = SafetyGate().evaluate(message, species="Gatto")

    assert flags
    assert categorize_safety_flags(flags) == "respiratory"


@pytest.mark.parametrize(
    "message",
    [
        "non mangia e non fa le feci da ieri sera",
        "ha smesso di mangiare",
        "non fa più le feci",
    ],
)
def test_a_rabbit_that_stops_eating_or_passing_stool_is_flagged(message: str) -> None:
    flags = SafetyGate().evaluate(message, species="Piccoli mammiferi")

    assert flags
    assert categorize_safety_flags(flags) == "gi_stasis"


def test_the_same_words_about_a_dog_are_not_a_gut_stasis_emergency() -> None:
    assert SafetyGate().evaluate("non mangia più le crocchette", species="Cane") == []


def test_ordinary_mentions_of_breathing_are_not_flagged() -> None:
    assert SafetyGate().evaluate("respira normalmente e dorme tranquillo", species="Gatto") == []


def test_severe_breathing_difficulty_skips_the_clarifying_question() -> None:
    assert requires_immediate_escalation("respira a bocca aperta e fa molta fatica a respirare")
    # Milder wording still gets the "after a run, or at rest?" question.
    assert not requires_immediate_escalation("respira a bocca aperta dopo la corsa")
