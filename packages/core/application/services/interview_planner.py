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

    def next_question(self, situation: SituationModel) -> str | None:
        """Return the next clarifying question to ask, or None if nothing
        meaningful is left to ask given what is already known.

        Guidance (spec v3 §13, §9):
        - safety_critical_unknowns should usually be resolved before anything else;
        - prefer the question with the highest expected information gain for
          THIS case, not simply the first missing field in QUESTION_TEMPLATES order;
        - never ask about a field that already has a value in `situation`;
        - return exactly one question, phrased naturally in Italian, using
          QUESTION_TEMPLATES (or a case-adapted variant of them).
        """
        # TODO(human): implement the next-best-question selection heuristic
        # described above. `situation` fields available: presenting_problem,
        # onset, contexts, observed_behaviours, associated_signs,
        # known_medical_context, environmental_changes, working_domains,
        # safety_critical_unknowns — see packages/core/domain/situation/models.py.
        raise NotImplementedError("InterviewPlanner.next_question is not implemented yet")
