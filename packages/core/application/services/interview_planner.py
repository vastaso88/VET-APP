from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.situation.models import SituationModel
from packages.shared.errors.base import ProviderError

# Matches EvidenceSynthesizer.SYNTHESIS_MARKER / SituationModelBuilder's
# extraction marker — lets a test double (or a future real prompt-routing
# concern) recognize this specific call by system prompt content.
QUESTION_PHRASING_MARKER = "phrasing one anamnesis follow-up question"

# Topic-agnostic description of what each field is trying to learn, used
# to ground the LLM phrasing call in the actual informational goal rather
# than the (possibly animal-behaviour-specific) template wording — see
# InterviewPlanner._phrase_for_case.
_FIELD_INTENTS: dict[str, str] = {
    "safety_critical_unknowns": "how urgent or severe the situation actually is",
    "presenting_problem": "what exactly is happening, described concretely",
    "onset": "how long this has been going on",
    "observed_behaviours": (
        "what specifically is different or observable right now — in the animal's "
        "own behaviour if that's what the case is about, or in the enclosure/"
        "equipment/environment if the case is about that instead"
    ),
    "associated_signs": (
        "whether anything else has also changed alongside the main problem"
    ),
    "environmental_changes": (
        "whether anything recently changed (diet, environment, routine, a new "
        "animal, equipment, travel) that could be related"
    ),
    "contexts": "in which situations or circumstances this happens most",
    "known_medical_context": "any known medical history or ongoing treatment relevant to this",
}


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
        # Real-world finding: these two SituationModel fields already
        # existed but InterviewPlanner never asked about either, so a
        # proper anamnesis review-of-systems and recent-triggers check
        # never happened — the interview could reach "adequate coverage"
        # without ever touching either dimension.
        "associated_signs": (
            "Oltre a questo, hai notato altri cambiamenti — nell'appetito, "
            "nella sete, nell'energia, o in come fa i bisogni?"
        ),
        "environmental_changes": (
            "C'è stato qualche cambiamento nell'ultimo periodo — nuovo cibo, "
            "un trasloco, un nuovo animale in casa, un viaggio?"
        ),
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
        "associated_signs",
        "environmental_changes",
        "known_medical_context",
        "contexts",
    )

    def __init__(self, llm_client: LLMClient | None = None) -> None:
        """`llm_client=None` (the default) keeps `next_question` fully
        deterministic, returning QUESTION_TEMPLATES verbatim — every
        field-priority unit test relies on exactly this.

        Passing a real client (see ChatOrchestrator/container.py) turns on
        case-adapted phrasing. Real-world finding (2026-09-21): the fixed
        "observed_behaviours" template ("cosa fa in quei momenti?") reads
        as nonsense once the case isn't about an animal's own behaviour at
        all — e.g. "l'acqua dell'acquario è di nuovo torbida" has nothing
        that's "doing" anything. A proper anamnesis phrases each question
        in light of what's already been said instead of reading from a
        fixed lookup table, which is exactly the gap this closes.
        """
        self._llm_client = llm_client
        self._last_phrased: tuple[str, str] | None = None

    def next_question(self, situation: SituationModel) -> str | None:
        field = self._next_field(situation)
        if field is None:
            self._last_phrased = None
            return None
        template = self.QUESTION_TEMPLATES[field]
        if self._llm_client is None:
            self._last_phrased = None
            return template
        phrased = self._phrase_for_case(field, template, situation)
        self._last_phrased = (phrased, field) if phrased != template else None
        return phrased

    @staticmethod
    def _next_field(situation: SituationModel) -> str | None:
        if (
            situation.safety_critical_unknowns
            and "safety_critical_unknowns" not in situation.asked_interview_fields
        ):
            return "safety_critical_unknowns"
        for field in InterviewPlanner._MISSING_FIELD_PRIORITY:
            if not getattr(situation, field) and field not in situation.asked_interview_fields:
                return field
        return None

    def _phrase_for_case(self, field: str, template: str, situation: SituationModel) -> str:
        case_context = self._case_summary(situation)
        if not case_context:
            # Nothing case-specific yet to adapt to (e.g. the very first
            # extraction came back empty) — the generic template already
            # fits as well as anything, and an LLM round-trip would only
            # add latency for no benefit.
            return template
        try:
            response = self._llm_client.generate(  # type: ignore[union-attr]
                LLMGenerationRequest(
                    system_prompt=(
                        f"You are a veterinary intake assistant {QUESTION_PHRASING_MARKER} "
                        "in an ongoing anamnesis (case history) conversation. Reply with "
                        "ONLY the question itself, in Italian, one short sentence — no "
                        "preamble, no quotes, no numbering, no markdown.\n\n"
                        "You are told WHAT information is still missing (topic-agnostic) "
                        "and given a generic template as a rough starting point ONLY — "
                        "that template's exact wording often assumes an ANIMAL is doing "
                        "something, which is nonsense for a case about an enclosure, "
                        "water quality, or equipment (nothing is 'doing' anything there). "
                        "Always compose the question fresh for the specific case below: "
                        "never keep animal-behaviour phrasing ('cosa fa', 'come si "
                        "comporta') for a case that isn't about the animal's own actions. "
                        "Never invent facts, never assume anything beyond what the case "
                        "states."
                    ),
                    user_prompt=(
                        f"Case so far: {case_context}\n"
                        f"What you still need to learn: {_FIELD_INTENTS[field]}\n"
                        f"Rough starting-point template (adapt freely, do not just "
                        f"copy it): {template}"
                    ),
                    max_tokens=120,
                )
            )
        except ProviderError:
            return template
        phrased = response.content.strip().strip('"')
        return phrased or template

    @staticmethod
    def _case_summary(situation: SituationModel) -> str:
        parts: list[str] = []
        if situation.presenting_problem:
            parts.append(f"Presenting problem: {situation.presenting_problem}")
        if situation.onset:
            parts.append(f"Onset: {situation.onset}")
        if situation.observed_behaviours:
            parts.append("Observed: " + ", ".join(situation.observed_behaviours))
        if situation.associated_signs:
            parts.append("Associated signs: " + ", ".join(situation.associated_signs))
        if situation.environmental_changes:
            parts.append("Recent changes: " + ", ".join(situation.environmental_changes))
        if situation.known_medical_context:
            parts.append(f"Medical context: {situation.known_medical_context}")
        if situation.working_domains:
            parts.append("Topic: " + ", ".join(situation.working_domains))
        return " | ".join(parts)

    def field_for_question(self, question: str) -> str | None:
        """Reverse-lookup which SituationModel field a question (as returned
        by next_question) targets, so the caller can record it as asked.

        Checks the just-phrased question first (case-adapted text won't
        match any fixed template verbatim), falling back to an exact
        template match for the deterministic (no llm_client) path.
        """
        if self._last_phrased is not None and question == self._last_phrased[0]:
            return self._last_phrased[1]
        for field, template in self.QUESTION_TEMPLATES.items():
            if template == question:
                return field
        return None
