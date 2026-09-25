from packages.core.domain.safety.triage_clarification import (
    CLARIFYING_QUESTIONS,
    RED_FLAG_CATEGORIES,
    categorize,
    classify_severity,
    requires_immediate_escalation,
)


def test_categorize_matches_the_flagged_keyword_to_its_category() -> None:
    assert categorize(["collasso"]) == "collapse"
    assert categorize(["non respira", "dispnea"]) == "respiratory"


def test_categorize_returns_none_when_no_flag_maps_to_a_category() -> None:
    assert categorize(["something-unmapped"]) is None


def test_every_category_has_a_clarifying_question_except_documented_exceptions() -> None:
    # "toxin_medication" is the one deliberate exception — see its comment
    # in RED_FLAG_CATEGORIES: the original real-world finding for these
    # substances was "always escalate, whether given or only proposed",
    # so it skips straight to _urgent_triage_result with zero delay
    # instead of spending a turn on a question first, unlike seizure/
    # gi_stasis. This test still catches an ACCIDENTAL omission for any
    # other category.
    categories_without_a_question = {"toxin_medication"}
    assert set(CLARIFYING_QUESTIONS) == set(RED_FLAG_CATEGORIES) - categories_without_a_question


def test_requires_immediate_escalation_detects_unambiguous_severity_markers() -> None:
    assert requires_immediate_escalation("Il cane è incosciente e non si sveglia")
    assert requires_immediate_escalation("gengive bianche, sembra grave")


def test_requires_immediate_escalation_is_false_for_ordinary_messages() -> None:
    assert not requires_immediate_escalation("Il cane ha un po' di tosse da ieri")


def test_classify_severity_downgrades_on_a_clear_reassuring_reply() -> None:
    assert classify_severity("respiratory", "ha corso tanto ed è il caldo") == "moderate"


def test_classify_severity_escalates_when_reply_mentions_worsening() -> None:
    assert classify_severity("respiratory", "ha corso ma sta peggiorando") == "high"


def test_classify_severity_defaults_to_high_on_an_unclear_reply() -> None:
    assert classify_severity("respiratory", "non saprei dire") == "high"


def test_classify_severity_never_downgrades_seizures() -> None:
    # Seizure has no reassuring markers by design (spec's fail-closed stance) —
    # even a calm-sounding reply must still escalate.
    assert classify_severity("seizure", "è tornato tranquillo e vigile") == "high"
