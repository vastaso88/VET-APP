from packages.core.domain.situation.models import SituationModel


class InterviewPlanner:
    """Decides the single next-best clarifying question for the current case,
    or that nothing more is worth asking (spec v3 §13).

    Question Utility = Information Gain × Case Relevance × Safety Relevance ÷ User Burden

    i.e. this is NOT "ask about every missing field" — it must pick the one
    question that most changes what we'd do next, prioritizing safety-critical
    unknowns, and stop asking once further questions add little value.
    """

    QUESTION_TEMPLATES: dict[str, str] = {
        "safety_critical_unknowns": (
            "Puoi darmi qualche dettaglio in più su questo aspetto? "
            "Mi serve per capire quanto è urgente la situazione."
        ),
        "presenting_problem": (
            "Cosa hai notato di preciso? Raccontami con parole tue cosa sta succedendo."
        ),
        "onset": "Da quanto tempo lo stai notando?",
        "observed_behaviours": "Puoi descrivere nel dettaglio cosa fa in quei momenti?",
        "contexts": "In quali situazioni succede di più (in casa, fuori, con altri animali)?",
        "known_medical_context": (
            "Ci sono condizioni di salute note o terapie in corso di cui dovrei sapere?"
        ),
    }

    # Priority order for the still-missing fields (safety_critical_unknowns is
    # handled separately below, since it flips the "missing = ask" logic: a
    # NON-empty list there means an unresolved safety concern to chase down).
    # This is a deterministic stand-in for the full utility formula in §13 —
    # revisit the ordering once real usage data shows which questions actually
    # change the final answer the most.
    _MISSING_FIELD_PRIORITY: tuple[str, ...] = (
        "presenting_problem",
        "onset",
        "observed_behaviours",
        "known_medical_context",
        "contexts",
    )

    def next_question(self, situation: SituationModel) -> str | None:
        """Return the next clarifying question to ask, or None if nothing
        meaningful is left to ask given what is already known.

        Guidance (spec v3 §13, §9):
        - safety_critical_unknowns should usually be resolved before anything else;
        - prefer the question with the highest expected information gain for
          THIS case, not simply the first missing field in QUESTION_TEMPLATES order;
        - never ask about a field that already has a value in `situation`;
        - never ask the SAME field twice in one conversation, even if it's
          still empty — extraction can legitimately fail to fill a field
          from a valid answer (e.g. a negative reply), and re-asking
          identically would loop instead of moving on;
        - return exactly one question, phrased naturally in Italian, using
          QUESTION_TEMPLATES (or a case-adapted variant of them).
        """
        if (
            situation.safety_critical_unknowns
            and "safety_critical_unknowns" not in situation.asked_interview_fields
        ):
            return self.QUESTION_TEMPLATES["safety_critical_unknowns"]
        for field in self._MISSING_FIELD_PRIORITY:
            if not getattr(situation, field) and field not in situation.asked_interview_fields:
                return self.QUESTION_TEMPLATES[field]
        return None

    def field_for_question(self, question: str) -> str | None:
        """Reverse-lookup which SituationModel field a question (as returned
        by next_question) targets, so the caller can record it as asked."""
        for field, template in self.QUESTION_TEMPLATES.items():
            if template == question:
                return field
        return None
