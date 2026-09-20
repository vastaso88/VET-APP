import logging
from collections.abc import Iterable

from pydantic import BaseModel, Field

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest, PiiAnonymizer
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.evidence_quality_engine import EvidenceQualityEngine
from packages.core.application.services.evidence_synthesizer import EvidenceSynthesizer
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.response_generator import ResponseGenerator
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.answer_validation import validate_answer
from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.pet_profile.models import FishStock, HabitatDetails
from packages.core.domain.pet_profile.species import normalize_species
from packages.core.domain.safety.triage_clarification import (
    CLARIFYING_QUESTIONS,
    requires_immediate_escalation,
)
from packages.core.domain.safety.triage_clarification import (
    categorize as categorize_safety_flags,
)
from packages.core.domain.safety.triage_clarification import (
    classify_severity as classify_safety_severity,
)
from packages.core.domain.situation.coverage import (
    DEFAULT_COVERAGE_WEIGHTS,
    CoverageWeights,
    coverage_score,
)
from packages.core.domain.situation.models import SituationModel
from packages.shared.errors.base import ProviderError

logger = logging.getLogger("vetgpt.chat")

# Fetch a wider candidate pool than we'll actually show, so the quality
# engine has real diversity to rank and select from (spec v3 §3-5) instead
# of just re-sorting whatever the retriever's own default cap happened to
# return.
EVIDENCE_POOL_MULTIPLIER = 3
EVIDENCE_MIN_POOL_SIZE = 8

# Real-world finding: the curated husbandry catalog groups every
# sub-topic (UVB/thermal, metabolic bone disease, enclosure size...) under
# one "husbandry" domain per species family — fine while there were only
# 1-3 entries per species, but EvidenceQualityEngine scores same-tier,
# same-domain, same-species, undated curated notes IDENTICALLY, so once a
# 4th entry was added for reptile_amphibian, a stable sort's tie-breaking
# silently dropped the newest one at the default max_results=3 cutoff —
# not because it was less relevant, only because it was last in the list.
# A bigger cap for this intent specifically comfortably fits today's
# catalog; a real fix (sub-topic tagging + query-aware ranking within the
# catalog) would scale further but is a bigger change than this warrants
# right now.
HUSBANDRY_MAX_RESULTS = 6

EVIDENCE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "clinical_question": (
        "vomit",
        "vomita",
        "diarrea",
        "tosse",
        "tossisce",
        "febbre",
        "dolore",
        "sintomo",
        "terapia",
        "tigna",
        "dermatofit",
        "prurito",
        "gratta",
        "pelle rossa",
        "crosta",
        "ferita",
        "gonfiore",
        "zoppica",
        "letargia",
        "letargic",
        "respira",
        "convulsion",
        "parassit",
        "pulci",
        "zecch",
        # Real-world finding: several genuinely clinical questions about
        # exotic species (a chicken's blackened toe, a turtle's sticky
        # shell, glass-like stool, a rabbit's testicular lumps) matched
        # none of the symptom words above — all written with dog/cat
        # vocabulary in mind — so the message fell through to
        # "general_info" and skipped evidence retrieval entirely,
        # breaking "no source, no answer" for a real clinical concern.
        # Generic phrases an owner uses to voice a health worry,
        # regardless of species or specific symptom, generalize far
        # better than enumerating every possible ailment description per
        # species/body part.
        "sono preoccupat",
        "molto preoccupat",
        "cosa può essere",
        "cosa potrebbe essere",
        "sapete cosa",
        "cosa devo fare",
        "è normale che",
        "malat",
        "sostanza appiccicosa",
        "zona nera",
    ),
    "nutrition_question": ("cibo", "mangia", "aliment", "dieta", "nutriz"),
    "behavior_question": ("comport", "ansia", "abbaia", "graffia", "aggress"),
    "preventive_care": ("vaccin", "antiparass", "checkup", "preven", "profilassi"),
    # Real-world finding: husbandry/equipment questions for exotic species
    # ("che lampada UVB per il geco?", "come ciclo l'acquario nuovo?") were
    # falling into clinical_question by default and then, correctly but
    # unhelpfully, hitting "no source, no answer" — PubMed/Europe PMC/
    # Crossref/OpenAlex only index peer-reviewed biomedical literature,
    # which essentially never covers terrarium/aquarium setup. This isn't
    # a symptom being investigated, it's an environmental-parameter
    # question, so it gets its own intent: a distinct evidence domain
    # (see in_memory_evidence_retriever.py's curated "husbandry" catalog)
    # and, below, a skip of the symptom-interview loop that doesn't apply
    # to it.
    "husbandry_question": (
        "uvb",
        "terrario",
        "teca",
        "riscaldamento",
        "tappetino riscaldante",
        "lampada",
        "termostato",
        "wattaggio",
        "watt",
        "fotoperiodo",
        "basking",
        "punto caldo",
        "substrato",
        "umidità",
        "acquario",
        "vasca",
        "ciclo dell'azoto",
        "ciclaggio",
        "ciclare",
        "filtro",
        "parametri dell'acqua",
        "cambio d'acqua",
        "gorgogliatore",
        # Real-world finding (live verification): "il mio camaleonte ha
        # bisogno di stare al sole diretto vicino alla finestra?" used none
        # of the UVB/equipment jargon above — a very plausible real
        # phrasing for the same underlying question. Kept to multi-word
        # phrases rather than the bare word "sole": as a substring it
        # would collide with "consolare"/"consolerò" (comforting a
        # distressed pet is a plausible behavior-question phrase).
        "sole diretto",
        "luce diretta del sole",
        "raggi diretti del sole",
        "prendere il sole",
        "esposizione al sole",
        # Real-world finding (stress test round 3): "come posso arricchire
        # la gabbia del mio pappagallo per non farlo annoiare?" matched
        # none of the reptile/aquarium-specific terms above and fell
        # through to a symptom-oriented interview question ("da quanto
        # tempo lo stai notando?") — a wrong fit for an enrichment
        # question with no symptom onset at all.
        "gabbia",
        "arricchimento",
        "arricchire",
        "si annoia",
        "annoiarsi",
    ),
}

# Real-world finding: defaulting to "general_info" for anything that
# matched none of the keywords above meant most substantive pet questions
# — a vague symptom report, a medication/dosage question, a symptom
# described in unfamiliar vocabulary — skipped the interview and
# evidence-grounding pipeline entirely and got an ungrounded free-text
# answer instead, exactly what this app exists to avoid. "general_info"
# is now reserved for messages that ARE this narrow list (greeting,
# thanks, a meta-question about the assistant itself) — everything else
# defaults to clinical_question instead (see _classify_intent). Matched
# as a substring but only within a short message (see the length gate in
# _classify_intent) — a real question that happens to contain one of
# these words ("va bene dargli il farmaco?") is long enough to never be
# misclassified.
SMALL_TALK_MESSAGES: frozenset[str] = frozenset(
    {
        "ciao",
        "buongiorno",
        "buonasera",
        "buondì",
        "salve",
        "hey",
        "grazie",
        "grazie mille",
        "ok",
        "va bene",
        "perfetto",
        "capito",
        "chi sei",
        "cosa sei",
        "cosa sai fare",
        "come funzioni",
        "cosa puoi fare",
    }
)

# Real-world finding: asked for an exact drug dose, the general LLM path
# confidently computed and handed over a specific mg figure with only a
# disclaimer at the end — owners tend to act on the number, not the small
# print after it. Caught deterministically, ahead of any LLM call, so no
# amount of prompt drift can let a number slip through (see
# _dosage_guard_result). Deliberately narrow phrasing (asking HOW MUCH,
# not just mentioning a drug) to avoid intercepting a real clinical
# question that happens to name a medication.
DOSAGE_REQUEST_MARKERS: tuple[str, ...] = (
    "quanti mg",
    "quanti ml",
    "che dose",
    "quale dose",
    "dose esatta",
    "dose precisa",
    "dosaggio esatto",
    "dosaggio preciso",
    "quanto dosaggio",
)

# Real-world finding: "Ho un cane e anche un gatto, entrambi non mangiano"
# was answered as if it were one ordinary case — the second animal was
# silently dropped rather than flagged. Two distinct animals with their
# own independent complaints need their own conversations (each has its
# own history/situation model); a second animal mentioned only as
# CONTEXT for the registered pet's own case (a conflict, a competition
# over food, a fright) should stay in the same conversation instead —
# that distinction is exactly what MULTI_PET_INTERACTION_MARKERS is for.
# Deliberately conservative: only the clear "both independently" phrasing
# triggers the redirect; anything else (including no marker at all)
# leaves the case alone rather than risk interrupting a real one.
SPECIES_WORD_TO_FAMILY: dict[str, str] = {
    "cane": "dog",
    "cani": "dog",
    "gatto": "cat",
    "gatti": "cat",
    "gatta": "cat",
    "gatte": "cat",
    "coniglio": "small_mammal",
    "conigli": "small_mammal",
    "criceto": "small_mammal",
    "cavia": "small_mammal",
    "furetto": "small_mammal",
    "uccello": "bird",
    "uccelli": "bird",
    "pappagallo": "bird",
    "canarino": "bird",
    "tartaruga": "reptile_amphibian",
    "rettile": "reptile_amphibian",
    "pesce": "fish",
    "pesci": "fish",
}
MULTI_PET_INDEPENDENT_MARKERS: tuple[str, ...] = (
    "entrambi",
    "entrambe",
    "tutti e due",
    "tutti e 2",
    "tutte e due",
    "tutte e 2",
)
MULTI_PET_INTERACTION_MARKERS: tuple[str, ...] = (
    "litiga",
    "litigano",
    "aggredisce",
    "aggrediscono",
    "attacca",
    "attaccano",
    "si azzuffano",
    "dopo aver visto",
    "quando vede",
    "quando vedono",
    "in presenza di",
    "insieme a",
    "insieme al",
    "convivenza",
    "conflitto",
)


class ChatOrchestratorInput(BaseModel):
    user_message: str
    species: str
    pet_name: str
    pet_id: str = ""
    # Real-world finding: the pet profile already carries breed/age/notes,
    # but the LLM prompt only ever included name and species - context the
    # owner already entered was silently dropped every turn.
    breed: str | None = None
    age_years: int | None = None
    notes: str | None = None
    # Habitat/enclosure characteristics (aquarium/terrarium/aviary) and
    # multi-species aquarium stock - mirrors PetProfile's fields of the
    # same name; forward-looking, since the mobile pets feature that would
    # populate these is still local-only as of this finding (2026-09-20).
    habitat: HabitatDetails | None = None
    aquarium_stock: list[FishStock] = Field(default_factory=list)
    conversation_history: list[ChatMessage] = Field(default_factory=list)
    situation_model: SituationModel | None = None
    interview_turns_used: int = 0
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None


class ChatOrchestratorResult(BaseModel):
    answer: str
    mode: str
    confidence: str
    ai_generated: bool
    sources: list[EvidenceSource] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)
    safety_flags: list[str] = Field(default_factory=list)
    recommended_action: str | None = None
    provider: str
    model: str
    state: ConversationState = ConversationState.ADEQUATE_EVIDENCE_FOUND
    situation_model: SituationModel | None = None
    coverage_score: float | None = None
    interview_turns_used: int = 0
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None
    evidence_synthesis: EvidenceSynthesis | None = None
    """Structured synthesis behind `answer` for mode="evidence" (spec v3
    §27) — supported/uncertain/conflicting claims kept distinguishable
    rather than blurred into one paragraph. None for every other mode."""


class ChatOrchestrator:
    def __init__(
        self,
        llm_client: LLMClient,
        evidence_retriever: EvidenceRetriever,
        pii_anonymizer: PiiAnonymizer,
        *,
        safety_gate: SafetyGate | None = None,
        situation_model_builder: SituationModelBuilder | None = None,
        interview_planner: InterviewPlanner | None = None,
        medical_record_context_retriever: MedicalRecordContextRetriever | None = None,
        consent_interpreter: ConsentInterpreter | None = None,
        evidence_quality_engine: EvidenceQualityEngine | None = None,
        evidence_synthesizer: EvidenceSynthesizer | None = None,
        response_generator: ResponseGenerator | None = None,
        response_language: str = "it",
        enable_interview_loop: bool = False,
        coverage_weights: CoverageWeights = DEFAULT_COVERAGE_WEIGHTS,
        coverage_target: float = 0.85,
        max_interview_questions: int = 3,
    ) -> None:
        self._llm_client = llm_client
        self._evidence_retriever = evidence_retriever
        self._pii_anonymizer = pii_anonymizer
        self._safety_gate = safety_gate or SafetyGate()
        self._situation_model_builder = situation_model_builder or SituationModelBuilder(llm_client)
        self._interview_planner = interview_planner or InterviewPlanner()
        # No infra-free default is possible here (it needs a repository) —
        # None simply means this deployment never offers record access.
        self._medical_record_context_retriever = medical_record_context_retriever
        self._consent_interpreter = consent_interpreter or ConsentInterpreter()
        self._evidence_quality_engine = evidence_quality_engine or EvidenceQualityEngine()
        self._evidence_synthesizer = evidence_synthesizer or EvidenceSynthesizer(
            llm_client, response_language=response_language
        )
        self._response_generator = response_generator or ResponseGenerator()
        self._enable_interview_loop = enable_interview_loop
        self._coverage_weights = coverage_weights
        self._coverage_target = coverage_target
        self._max_interview_questions = max_interview_questions

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        result = self._answer(data)
        self._log_outcome(data, result)
        return result

    @staticmethod
    def _log_outcome(data: ChatOrchestratorInput, result: ChatOrchestratorResult) -> None:
        """Structured, PII-free observability for Beta metrics (spec v3
        §42, §49) — decision outcomes and provider/coverage/turn counters
        only, never the raw message content."""
        logger.info(
            "chat_turn mode=%s state=%s confidence=%s coverage=%s "
            "interview_turns=%s provider=%s model=%s sources=%s "
            "safety_flags=%s species=%s",
            result.mode,
            result.state.value,
            result.confidence,
            result.coverage_score,
            result.interview_turns_used,
            result.provider,
            result.model,
            len(result.sources),
            ",".join(result.safety_flags) or "-",
            data.species,
        )

    def _answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        message = data.user_message.strip()
        lowered = message.lower()

        if data.awaiting_safety_clarification and data.safety_clarification_category:
            return self._resolve_safety_clarification(
                data.pet_name, data.safety_clarification_category, message
            )

        # Real-world finding (stress test): a pet profile registered as
        # "Gatto" with a message body describing "il mio furetto..." used
        # the CAT's safety rules and evidence for an animal that is
        # actually a ferret — generic across any species pair, not
        # specific to this one: a stale/mis-set profile shouldn't override
        # what the owner is actually describing right now. Only overrides
        # when exactly one species family is unambiguously named and it
        # disagrees with the profile; two different species words present
        # (a real multi-pet mention, or a figurative comparison) is
        # deliberately left ambiguous and falls back to the profile.
        effective_species = self._effective_species(lowered, data.species)

        safety_flags = self._safety_gate.evaluate(lowered, species=effective_species)
        if safety_flags:
            if requires_immediate_escalation(message):
                # Already unambiguous and severe — asking a clarifying
                # question here would only delay real emergency care.
                return self._urgent_triage_result(data.pet_name, safety_flags)

            category = categorize_safety_flags(safety_flags)
            question = CLARIFYING_QUESTIONS.get(category) if category else None
            if question is not None:
                return ChatOrchestratorResult(
                    answer=question,
                    mode="safety_clarification",
                    confidence="low",
                    ai_generated=False,
                    safety_flags=safety_flags,
                    provider="rule-based",
                    model="safety-clarification-gate",
                    state=ConversationState.NEED_MORE_INFORMATION,
                    awaiting_safety_clarification=True,
                    safety_clarification_category=category,
                )
            # No mapped category for these keywords (shouldn't happen given
            # RED_FLAG_CATEGORIES covers every SafetyGate keyword) — fail
            # safe by escalating directly rather than asking a question we
            # don't have.
            return self._urgent_triage_result(data.pet_name, safety_flags)

        if self._is_dosage_request(lowered):
            # Real-world finding: asked for an exact drug dose, the general
            # LLM path confidently computed and handed over a specific mg
            # figure (with a disclaimer only at the end, which owners tend
            # not to act on). This app must support the vet, never replace
            # their clinical judgement — a rule-based, non-negotiable
            # refusal here, ahead of any LLM call, guarantees that no
            # amount of prompt drift can slip a number through.
            return self._dosage_guard_result()

        if self._describes_independent_multi_pet_complaint(lowered):
            return self._multi_pet_redirect_result(data.pet_name)

        situation = data.situation_model or SituationModel()
        turns_used = data.interview_turns_used
        medical_record_consent = data.medical_record_consent

        resolving_consent = (
            self._enable_interview_loop
            and data.awaiting_medical_record_consent
            and medical_record_consent is None
        )
        if resolving_consent:
            return self._resolve_medical_record_consent(data, message, situation, turns_used)

        intent = self._classify_intent(lowered)
        if (
            intent in ("general_info", "clinical_question")
            and self._enable_interview_loop
            and situation.working_domains
        ):
            # We're mid-interview on an already-established clinical topic —
            # a short follow-up reply ("da due giorni", "solo in casa") won't
            # repeat the original keywords, but reclassifying it fresh would
            # silently drop the case into a generic, un-grounded answer.
            # Stay on the established topic instead — but only trust a
            # working_domains entry that's actually one of our known
            # intents: extraction is an LLM call, and despite the prompt
            # asking for exactly these values, it can still invent a
            # free-text label (e.g. "gastroenterology") that would
            # otherwise silently break evidence retrieval on this turn.
            known_domain = next(
                (domain for domain in situation.working_domains if domain in EVIDENCE_KEYWORDS),
                None,
            )
            if known_domain is not None:
                intent = known_domain
        if intent == "general_info":
            return self._generate_general_answer(data, message, effective_species)

        coverage: float | None = None

        # Husbandry/equipment questions skip the symptom-interview loop
        # entirely: it exists to build up a clinical picture (onset,
        # associated signs...) before answering a health concern, which
        # doesn't apply to "what wattage UVB bulb" — that's answerable
        # from the question alone, and coverage would never legitimately
        # reach the target anyway (a "husbandry_question" doesn't set
        # presenting_problem/onset the way a symptom report does).
        if self._enable_interview_loop and intent != "husbandry_question":
            situation = self._situation_model_builder.update(
                situation, message, data.conversation_history
            )
            if intent not in situation.working_domains:
                situation = situation.merge(SituationModel(working_domains=[intent]))

            if medical_record_consent and not situation.known_medical_context:
                # Consent was already granted (this turn's answer, or a
                # standing per-pet decision from a previous conversation) —
                # use it rather than re-asking or silently ignoring it.
                record_summary = self._retrieve_medical_record_summary(data.pet_id)
                if record_summary:
                    situation = situation.merge(
                        SituationModel(known_medical_context=record_summary)
                    )

            coverage = coverage_score(situation, self._coverage_weights)
            if coverage < self._coverage_target:
                if (
                    medical_record_consent is None
                    and not situation.known_medical_context
                    and self._retrieve_medical_record_summary(data.pet_id) is not None
                ):
                    return ChatOrchestratorResult(
                        answer=(
                            f"Vuoi che consulti la cartella clinica di {data.pet_name} "
                            "per darti un consiglio più preciso? Guarderò solo le informazioni "
                            "rilevanti per questo caso."
                        ),
                        mode="consent_request",
                        confidence="low",
                        ai_generated=False,
                        provider="rule-based",
                        model="medical-record-consent-gate",
                        state=ConversationState.NEED_MORE_INFORMATION,
                        situation_model=situation,
                        coverage_score=coverage,
                        interview_turns_used=turns_used,
                        medical_record_consent=None,
                        awaiting_medical_record_consent=True,
                    )
                if turns_used < self._max_interview_questions:
                    question = self._interview_planner.next_question(situation)
                    if question is not None:
                        asked_field = self._interview_planner.field_for_question(question)
                        if asked_field is not None:
                            situation = situation.merge(
                                SituationModel(asked_interview_fields=[asked_field])
                            )
                        return ChatOrchestratorResult(
                            answer=question,
                            mode="interview",
                            confidence="low",
                            ai_generated=False,
                            provider="rule-based",
                            model="interview-planner",
                            state=ConversationState.NEED_MORE_INFORMATION,
                            situation_model=situation,
                            coverage_score=coverage,
                            interview_turns_used=turns_used + 1,
                            medical_record_consent=medical_record_consent,
                        )
                elif (
                    not situation.presenting_problem
                    and "__gave_up_once__" not in situation.asked_interview_fields
                ):
                    # Question budget exhausted and we still don't even know
                    # what the problem is: don't guess, and don't spend an
                    # evidence-retrieval call on a case we can't describe
                    # yet. Marked so this can only happen ONCE per
                    # conversation (see below) — repeating this exact
                    # message forever if the next reply also fails to
                    # extract anything would trap the owner with no way
                    # forward.
                    situation = situation.merge(
                        SituationModel(asked_interview_fields=["__gave_up_once__"])
                    )
                    return ChatOrchestratorResult(
                        answer=(
                            "Non sono riuscito a capire bene la situazione con le domande "
                            "fatte finora, e non voglio darti un'indicazione basata su "
                            "informazioni incomplete. Puoi provare a raccontarmi di nuovo "
                            "cosa sta succedendo, magari con altre parole, oppure "
                            "ricominciare la conversazione da capo."
                        ),
                        mode="interview",
                        confidence="low",
                        ai_generated=False,
                        provider="rule-based",
                        model="interview-planner",
                        state=ConversationState.INSUFFICIENT_EVIDENCE,
                        situation_model=situation,
                        coverage_score=coverage,
                        interview_turns_used=turns_used,
                        medical_record_consent=medical_record_consent,
                    )
                elif not situation.presenting_problem:
                    # Second time in a row extraction produced nothing
                    # usable: asking again would just repeat the same dead
                    # end. Force progress with the owner's own words as a
                    # last-resort presenting_problem rather than trap them
                    # here indefinitely.
                    situation = situation.merge(SituationModel(presenting_problem=message))
                # Otherwise: budget exhausted but we at least know the
                # presenting problem — fall through to the evidence step
                # below, which already refuses to answer without sources.

        result = self._generate_evidence_answer(
            data, message, intent, situation, effective_species
        )
        result.situation_model = situation
        result.coverage_score = coverage
        result.interview_turns_used = turns_used
        result.medical_record_consent = medical_record_consent
        return result

    @staticmethod
    def _urgent_triage_result(pet_name: str, safety_flags: list[str]) -> ChatOrchestratorResult:
        return ChatOrchestratorResult(
            answer=(
                f"Hai fatto bene a scrivermi subito. Quello che mi racconti di "
                f"{pet_name} è un segnale che merita una valutazione veterinaria "
                "immediata. Ecco cosa fare adesso:\n"
                "1) contatta subito il tuo veterinario o un pronto soccorso veterinario;\n"
                f"2) nel frattempo tieni {pet_name} calmo, al caldo e al sicuro;\n"
                "3) evita di dargli cibo, acqua in eccesso o farmaci senza indicazione "
                "del veterinario."
            ),
            mode="triage",
            confidence="high",
            ai_generated=False,
            safety_flags=safety_flags,
            limitations=["Triage prudenziale generato senza approfondimento diagnostico."],
            recommended_action="Valutazione veterinaria immediata.",
            provider="rule-based",
            model="safety-triage-guard",
            state=ConversationState.POSSIBLE_URGENT_CASE,
        )

    @staticmethod
    def _is_dosage_request(message: str) -> bool:
        return any(marker in message for marker in DOSAGE_REQUEST_MARKERS)

    @staticmethod
    def _describes_independent_multi_pet_complaint(message: str) -> bool:
        if any(marker in message for marker in MULTI_PET_INTERACTION_MARKERS):
            return False
        if not any(marker in message for marker in MULTI_PET_INDEPENDENT_MARKERS):
            return False
        mentioned_families = {
            family for word, family in SPECIES_WORD_TO_FAMILY.items() if word in message
        }
        return len(mentioned_families) >= 2

    @staticmethod
    def _effective_species(message: str, profile_species: str) -> str:
        """Prefers a species named explicitly in the message body over the
        pet profile's on-file species when they disagree — see the
        real-world finding in `_answer`. Reuses SPECIES_WORD_TO_FAMILY
        (already generic across species, built for the multi-pet check
        above) rather than hardcoding a specific mismatch pair. Only
        overrides when exactly one family is unambiguously named: two
        different families mentioned together is either a genuine
        multi-pet case (handled separately above) or a figurative
        comparison, and guessing wrong there is worse than just trusting
        the profile.
        """
        profile_family = normalize_species(profile_species)
        mentioned_families = {
            family for word, family in SPECIES_WORD_TO_FAMILY.items() if word in message
        }
        if len(mentioned_families) == 1:
            (mentioned_family,) = mentioned_families
            if mentioned_family != profile_family:
                return mentioned_family
        return profile_species

    @staticmethod
    def _mentions_wrong_species(text: str, effective_species: str) -> bool:
        """Real-world finding: an aquarium (species="Pesce") got an
        AI-generated reply opening with "Nota per il tuo cane" ("Note for
        your dog") — a genuine LLM error, not anything this codebase
        inserted (ResponseGenerator only concatenates the model's own
        synthesis strings). Reuses SPECIES_WORD_TO_FAMILY generically
        rather than special-casing "cane": flags a possessive reference
        ("tuo"/"tua {word}") to any species family other than the pet's
        own, wherever that word falls in the vocabulary. Deliberately
        narrow to the possessive construction — a legitimate comparison
        ("a differenza del cane, i pesci non hanno...") mentions another
        species without claiming it's THIS pet, and must not be flagged.
        """
        family = normalize_species(effective_species)
        lowered = text.lower()
        return any(
            f"tuo {word}" in lowered or f"tua {word}" in lowered
            for word, mentioned_family in SPECIES_WORD_TO_FAMILY.items()
            if mentioned_family != family
        )

    @staticmethod
    def _multi_pet_redirect_result(pet_name: str) -> ChatOrchestratorResult:
        return ChatOrchestratorResult(
            answer=(
                "Ho notato che mi parli di più di un animale con problemi che "
                f"sembrano indipendenti tra loro. Per seguire bene ciascun caso "
                f"ti conviene aprire una conversazione separata per {pet_name} "
                "e una per l'altro animale — così ognuno ha la propria storia "
                "e i propri dettagli, senza mescolare le informazioni. Se "
                "invece il problema riguarda proprio un'interazione tra i due "
                "(ad esempio si aggrediscono, competono per il cibo, uno si è "
                "spaventato per l'altro), dimmelo pure qui: in quel caso il "
                f"contesto dell'altro animale mi serve per capire cosa "
                f"succede a {pet_name}."
            ),
            mode="multi_pet_redirect",
            confidence="high",
            ai_generated=False,
            provider="rule-based",
            model="multi-pet-guard",
        )

    @staticmethod
    def _dosage_guard_result() -> ChatOrchestratorResult:
        return ChatOrchestratorResult(
            answer=(
                "Non ti do una cifra precisa: il dosaggio corretto di un farmaco "
                "dipende dal peso esatto, dalla condizione clinica e dalla "
                "formulazione specifica del prodotto — è una valutazione che spetta "
                "solo al veterinario, l'unico che può stabilire o modificare una "
                "terapia. Puoi trovare indicazioni generali sui dosaggi su fonti "
                "veterinarie ufficiali, ma per il tuo animale conferma sempre la "
                "dose esatta con il veterinario prima di somministrare qualsiasi "
                "farmaco."
            ),
            mode="general",
            confidence="high",
            ai_generated=False,
            limitations=[
                "Questa app supporta il lavoro del veterinario, non lo sostituisce: "
                "non fornisce mai dosaggi farmacologici precisi."
            ],
            recommended_action="Conferma il dosaggio esatto con il veterinario.",
            provider="rule-based",
            model="dosage-guard",
        )

    def _resolve_safety_clarification(
        self, pet_name: str, category: str, reply: str
    ) -> ChatOrchestratorResult:
        """Handle the reply to a pending safety clarification (spec v3 §9).

        Fail closed: anything other than a clear, specific, benign
        explanation for THIS category — including an unclear or
        off-topic reply — escalates exactly as if no clarification had
        been asked. A "moderate" outcome never says "nothing to worry
        about": it still asks the owner to watch closely and call the vet
        if anything changes, per the app's prudential line.
        """
        severity = classify_safety_severity(category, reply)
        if severity == "high":
            return self._urgent_triage_result(pet_name, [category])

        return ChatOrchestratorResult(
            answer=(
                f"Grazie per il dettaglio. Quello che descrivi per {pet_name} sembra "
                "spesso legato a uno sforzo, al caldo o all'emozione del momento, e di "
                "solito si risolve da solo in poco tempo. Nel frattempo: tienilo "
                "tranquillo, offrigli acqua fresca e osservalo per 15-20 minuti. "
                "Se non migliora, se peggiora anche di poco, o se hai anche solo un "
                "dubbio, contatta subito il veterinario — meglio una chiamata in più "
                "che rischiare."
            ),
            mode="safety_clarification_resolved",
            confidence="medium",
            ai_generated=False,
            provider="rule-based",
            model="safety-clarification-gate",
            recommended_action=(
                "Osservazione ravvicinata; contattare il veterinario se non migliora "
                "o in caso di dubbio."
            ),
        )

    def _retrieve_medical_record_summary(self, pet_id: str) -> str | None:
        if self._medical_record_context_retriever is None or not pet_id:
            return None
        return self._medical_record_context_retriever.summarize_for_pet(pet_id)

    def _resolve_medical_record_consent(
        self,
        data: ChatOrchestratorInput,
        message: str,
        situation: SituationModel,
        turns_used: int,
    ) -> ChatOrchestratorResult:
        """Handle the reply to a pending consent question (spec v3 §18).

        This always returns directly: the reply itself ("sì"/"no") isn't
        clinical content, so it must never be forwarded to evidence
        retrieval or the general-answer LLM call as if it were the
        question — that turn just resolves consent and, if there's
        already enough to ask about, asks the next real question.
        """
        interpreted = self._consent_interpreter.interpret(message)
        # Fail closed: an unclear reply is treated as "not granted", never
        # as implicit permission.
        consent = interpreted if interpreted is not None else False
        if consent:
            record_summary = self._retrieve_medical_record_summary(data.pet_id)
            if record_summary:
                situation = situation.merge(SituationModel(known_medical_context=record_summary))
                acknowledgement = "Grazie, ho dato un'occhiata alla cartella clinica. "
            else:
                acknowledgement = "Va bene. "
        else:
            acknowledgement = "Va bene, procediamo senza consultarla. "

        coverage = coverage_score(situation, self._coverage_weights)
        question = None
        if coverage < self._coverage_target and turns_used < self._max_interview_questions:
            question = self._interview_planner.next_question(situation)
            if question is not None:
                asked_field = self._interview_planner.field_for_question(question)
                if asked_field is not None:
                    situation = situation.merge(
                        SituationModel(asked_interview_fields=[asked_field])
                    )

        answer = (
            f"{acknowledgement}{question}"
            if question is not None
            else f"{acknowledgement}Raccontami pure di nuovo cosa hai osservato, così ti rispondo."
        )
        return ChatOrchestratorResult(
            answer=answer,
            mode="interview",
            confidence="low",
            ai_generated=False,
            provider="rule-based",
            model="medical-record-consent-gate",
            state=ConversationState.NEED_MORE_INFORMATION,
            situation_model=situation,
            coverage_score=coverage,
            interview_turns_used=turns_used + (1 if question is not None else 0),
            medical_record_consent=consent,
        )

    def _generate_general_answer(
        self,
        data: ChatOrchestratorInput,
        message: str,
        effective_species: str,
    ) -> ChatOrchestratorResult:
        anonymized_message = self._anonymize_for_provider(message)
        try:
            response = self._llm_client.generate(
                LLMGenerationRequest(
                    system_prompt=(
                        "You are a veterinary app assistant. Answer clearly, avoid diagnosis, "
                        "and encourage professional care when symptoms worsen. There is no "
                        "retrieved evidence for this turn, so never include a [n] citation. "
                        "Always refer to the animal consistent with the Species given below — "
                        "never assume or default to a different species (e.g. never call it a "
                        "dog/cane unless Species really is a dog), even if the pet's name is "
                        "unusual or describes an object or place rather than a typical name."
                    ),
                    user_prompt=(
                        f"{self._pet_context_block(data)}\n"
                        f"User request: {anonymized_message}"
                    ),
                    # See EvidenceSynthesizer/SituationModelBuilder for why:
                    # a reasoning model can burn the whole 600-token default
                    # on internal reasoning and return nothing, or (as
                    # observed live) a genuinely detailed, appropriate
                    # answer (e.g. a decontamination protocol) gets cut off
                    # mid-sentence instead.
                    max_tokens=1200,
                )
            )
        except ProviderError:
            return ChatOrchestratorResult(
                answer=(
                    "In questo momento non riesco a elaborare una risposta (il servizio è "
                    "temporaneamente non disponibile). Riprova tra poco, oppure consulta il "
                    "veterinario se la situazione richiede attenzione ora."
                ),
                mode="general",
                confidence="low",
                ai_generated=False,
                limitations=["Risposta non disponibile: provider LLM non raggiungibile."],
                provider="rule-based",
                model="general-answer-guard",
                state=ConversationState.RETRIEVAL_FAILURE,
            )
        # No sources exist in this path, so ANY [n] citation the model
        # produces is by definition invented (spec v3 §28).
        validation = validate_answer(response.content, sources_count=0)
        if not validation.is_valid:
            return self._validation_failure_result(
                sources=[], violations=validation.violations, mode="general"
            )
        if self._mentions_wrong_species(response.content, effective_species):
            return self._validation_failure_result(
                sources=[],
                violations=["wrong_species_reference"],
                mode="general",
            )
        return ChatOrchestratorResult(
            answer=response.content,
            mode="general",
            confidence="medium",
            ai_generated=True,
            limitations=["General guidance without evidence retrieval."],
            provider=response.provider,
            model=response.model,
        )

    def _generate_evidence_answer(
        self,
        data: ChatOrchestratorInput,
        message: str,
        intent: str,
        situation: SituationModel,
        effective_species: str,
    ) -> ChatOrchestratorResult:
        case_text = self._case_context_text(situation, message)
        canonical_species = normalize_species(effective_species)
        max_results = (
            HUSBANDRY_MAX_RESULTS
            if intent == "husbandry_question"
            else EvidenceRetrievalRequest.model_fields["max_results"].default
        )
        final_request = EvidenceRetrievalRequest(
            query=case_text, species=canonical_species, intent=intent, max_results=max_results
        )
        pool_size = max(
            final_request.max_results * EVIDENCE_POOL_MULTIPLIER, EVIDENCE_MIN_POOL_SIZE
        )
        pool_request = final_request.model_copy(update={"max_results": pool_size})
        raw_sources = self._evidence_retriever.retrieve(pool_request)
        ranked = self._evidence_quality_engine.rank_and_select(
            raw_sources,
            species=canonical_species,
            intent=intent,
            max_results=final_request.max_results,
        )
        sources = ranked.sources
        if not sources:
            return ChatOrchestratorResult(
                answer=(
                    "Non ho trovato evidenze affidabili sufficienti per rispondere in modo "
                    "sicuro a questa domanda. Posso aiutarti a riformularla oppure a "
                    "preparare le informazioni da portare al veterinario."
                ),
                mode="evidence",
                confidence="low",
                ai_generated=False,
                limitations=[
                    "No source, no answer: il retrieval del prototipo non ha prodotto fonti "
                    "ammissibili."
                ],
                recommended_action=(
                    "Se il sintomo persiste, peggiora o coinvolge dolore, appetito o energia, "
                    "consulta il veterinario."
                ),
                provider="rule-based",
                model="evidence-guard",
                state=ConversationState.INSUFFICIENT_EVIDENCE,
            )

        evidence_block = self._format_sources_for_prompt(sources)
        anonymized_message = self._anonymize_for_provider(case_text)
        try:
            synthesis, response = self._evidence_synthesizer.synthesize(
                f"{self._pet_context_block(data)}\n"
                f"Question: {anonymized_message}\n"
                f"Evidence:\n{evidence_block}"
            )
        except ProviderError:
            # The retrieval-side adapters all degrade to "no results" on a
            # network/provider failure rather than raising (spec v3 §20) —
            # the LLM call deserves the same fail-safe treatment: a
            # rate-limited or down provider shouldn't crash the whole turn.
            return ChatOrchestratorResult(
                answer=(
                    "In questo momento non riesco a elaborare una risposta basata sulle "
                    "fonti scientifiche (il servizio è temporaneamente non disponibile). "
                    "Riprova tra poco, oppure consulta il veterinario se la situazione "
                    "richiede attenzione ora."
                ),
                mode="evidence",
                confidence="low",
                ai_generated=False,
                sources=sources,
                limitations=[
                    "Sintesi delle evidenze non disponibile: provider LLM non raggiungibile."
                ],
                provider="rule-based",
                model="evidence-guard",
                state=ConversationState.RETRIEVAL_FAILURE,
            )

        if synthesis.is_empty():
            return self._validation_failure_result(
                sources=sources,
                violations=["evidence_synthesis_empty: nessuna claim supportata prodotta"],
                mode="evidence",
            )

        validation = validate_answer(synthesis.all_claim_text(), sources_count=len(sources))
        if not validation.is_valid:
            return self._validation_failure_result(
                sources=sources, violations=validation.violations, mode="evidence"
            )
        # Real-world finding: an aquarium (species="Pesce") got an
        # AI-generated reply opening with "Nota per il tuo cane" — the
        # LLM's own error (ResponseGenerator only concatenates the
        # synthesis's own strings, nothing in this codebase inserts a
        # species word). A deterministic check here is a safety net for
        # the same reason validate_answer checks citations/absolute claims
        # mechanically rather than only trusting the prompt.
        if self._mentions_wrong_species(synthesis.all_claim_text(), effective_species):
            return self._validation_failure_result(
                sources=sources,
                violations=["wrong_species_reference"],
                mode="evidence",
            )

        answer = self._response_generator.render(synthesis)
        limitations = [*self._build_limitations(sources), *synthesis.evidence_gaps]
        if situation.safety_critical_unknowns:
            # Final safety review (spec v3 §29): the case still has an
            # unresolved safety-critical question even though we reached
            # an evidence answer — surface that rather than answering as
            # if everything is fine. Safety overrides completeness.
            answer = (
                "Prima di tutto: per alcuni aspetti che mi hai descritto non ho ancora "
                "abbastanza chiarezza per escludere una situazione seria, quindi se "
                f"peggiora non aspettare e contatta il veterinario. Detto questo:\n\n{answer}"
            )
            limitations = [
                *limitations,
                "Nel caso restano aspetti di sicurezza non del tutto chiariti dall'intervista.",
            ]

        return ChatOrchestratorResult(
            answer=answer,
            mode="evidence",
            confidence=self._confidence_from_score(ranked.top_score),
            ai_generated=True,
            sources=sources,
            limitations=limitations,
            recommended_action=(
                "Consulta il veterinario per una valutazione personalizzata se i sintomi "
                "persistono."
            ),
            provider=response.provider,
            model=response.model,
            evidence_synthesis=synthesis,
        )

    @staticmethod
    def _validation_failure_result(
        *, sources: list[EvidenceSource], violations: list[str], mode: str
    ) -> ChatOrchestratorResult:
        source_note = (
            "Ti lascio comunque le fonti che avevo trovato, puoi consultarle direttamente. "
            if sources
            else ""
        )
        return ChatOrchestratorResult(
            answer=(
                "Quello che stavo per dirti non ha superato i nostri controlli di sicurezza "
                "(ad esempio un riferimento non verificabile o un'affermazione troppo assoluta), "
                "quindi preferisco non mostrartelo così com'è. "
                f"{source_note}"
                "Prova a riformulare la domanda, oppure consulta il veterinario per una "
                "valutazione diretta."
            ),
            mode=mode,
            confidence="low",
            ai_generated=False,
            sources=sources,
            limitations=[
                f"Risposta scartata dal controllo di validazione: {v}" for v in violations
            ],
            recommended_action="Consulta il veterinario per una valutazione personalizzata.",
            provider="rule-based",
            model="answer-validator",
            state=ConversationState.SOURCE_VALIDATION_FAILURE,
        )

    @staticmethod
    def _case_context_text(situation: SituationModel, latest_message: str) -> str:
        """Builds the text handed to evidence retrieval and synthesis.

        Real-world finding: using only the current turn's raw message broke
        down badly once the interview loop had already run for a few turns
        — by the time coverage was reached, the triggering message was
        often a context-only reply (e.g. "succede sempre in casa"), with
        every symptom keyword the owner had actually reported sitting in
        earlier turns and in the accumulated SituationModel instead. That
        starved both the retrieval query (falling back to a generic,
        low-precision search) and the synthesizer (given no real case to
        reason about). Folding in the accumulated fields keeps the
        symptom vocabulary available regardless of which turn happens to
        cross the coverage threshold.
        """
        parts: list[str] = []
        if situation.presenting_problem:
            parts.append(situation.presenting_problem)
        if situation.onset:
            parts.append(f"Onset: {situation.onset}")
        if situation.observed_behaviours:
            parts.append("Observed: " + ", ".join(situation.observed_behaviours))
        if situation.associated_signs:
            parts.append("Associated signs: " + ", ".join(situation.associated_signs))
        if situation.known_medical_context:
            parts.append(f"Medical context: {situation.known_medical_context}")
        parts.append(latest_message)
        return " ".join(parts)

    def _anonymize_for_provider(self, text: str) -> str:
        """Strip PII before text leaves the system to the external LLM
        provider. Only applied to the outbound prompt — evidence retrieval
        (local) and the stored conversation/reply keep the original text,
        per the documented anonymization boundary (docs/compliance/02_pii_anonymization.md)."""
        return self._pii_anonymizer.anonymize(PiiAnonymizationRequest(text=text)).anonymized_text

    def _pet_context_block(self, data: ChatOrchestratorInput) -> str:
        """Every field PetProfile actually has today, not just name/species
        — several of these existed on the profile already but were never
        forwarded into a prompt before this. Optional fields are omitted
        entirely rather than printed as "None"/empty, so the model isn't
        invited to comment on an absence the owner never provided.

        Real-world finding: an aquarium registered as a pet got advice
        about cleaning a food bowl — nothing about the profile told the
        model this was a tank, not a cat or dog. Habitat/aquarium-stock
        context closes exactly that gap once the mobile pets feature
        starts sending it (still local-only as of this finding).
        """
        lines = [
            f"Pet name: {self._anonymize_for_provider(data.pet_name)}",
            f"Species: {data.species}",
        ]
        if data.breed:
            lines.append(f"Breed: {data.breed}")
        if data.age_years is not None:
            lines.append(f"Age: {data.age_years} years")
        if data.notes:
            lines.append(f"Owner notes: {self._anonymize_for_provider(data.notes)}")
        if data.habitat is not None and not data.habitat.is_empty():
            habitat_facts = [
                fact
                for fact in (
                    f"dimensions {data.habitat.dimensions}" if data.habitat.dimensions else "",
                    f"{data.habitat.volume_liters} liters"
                    if data.habitat.volume_liters
                    else "",
                    f"temperature {data.habitat.temperature_label}"
                    if data.habitat.temperature_label
                    else "",
                    f"substrate {data.habitat.substrate}" if data.habitat.substrate else "",
                )
                if fact
            ]
            if habitat_facts:
                lines.append(f"Habitat: {', '.join(habitat_facts)}")
            if data.habitat.notes:
                lines.append(f"Habitat notes: {self._anonymize_for_provider(data.habitat.notes)}")
        if data.aquarium_stock:
            stock_text = "; ".join(
                f"{fish.species} ({fish.male_count}M/{fish.female_count}F)"
                for fish in data.aquarium_stock
            )
            lines.append(f"Aquarium stock: {stock_text}")
        return "\n".join(lines)

    @staticmethod
    def _classify_intent(message: str) -> str:
        for intent, keywords in EVIDENCE_KEYWORDS.items():
            if any(keyword in message for keyword in keywords):
                return intent
        normalized = message.strip().rstrip("!.?").strip()
        # A short-length gate, not just a marker match: "va bene" alone
        # would otherwise misclassify a real question like "va bene
        # dargli il farmaco?" as small talk. Genuine greetings/thanks are
        # short; a message long enough to describe an actual case never
        # is, regardless of which words it happens to contain.
        if len(normalized) <= 30 and any(marker in normalized for marker in SMALL_TALK_MESSAGES):
            return "general_info"
        return "clinical_question"

    @staticmethod
    def _format_sources_for_prompt(sources: Iterable[EvidenceSource]) -> str:
        lines: list[str] = []
        for index, source in enumerate(sources, start=1):
            lines.append(
                f"[{index}] {source.title} | {source.journal or 'Unknown journal'} | "
                f"{source.year or 'n.d.'} | Tier {source.tier}\n"
                f"Snippet: {source.snippet or 'No snippet available.'}"
            )
        return "\n".join(lines)

    @staticmethod
    def _confidence_from_score(top_score: float) -> str:
        """Confidence now reflects the EvidenceQualityEngine's composite
        score of the best-ranked source (methodology + relevance + species
        match + recency + access depth) rather than just "is there a Tier A
        source and are there at least two of them" (spec v3 §24-25)."""
        if top_score >= 0.75:
            return "high"
        if top_score >= 0.5:
            return "medium"
        return "low"

    @staticmethod
    def _build_limitations(sources: list[EvidenceSource]) -> list[str]:
        limitations: list[str] = []
        if not any(source.tier == "A" for source in sources):
            limitations.append(
                "Le fonti recuperate non includono guideline o systematic review Tier A."
            )
        if any(source.species == "other" for source in sources):
            limitations.append("Alcune fonti non sono specie-specifiche.")
        if all(source.access_depth == "C" for source in sources):
            limitations.append(
                "Per queste fonti abbiamo solo titolo e abstract, non il testo completo."
            )
        if any(source.clinical_domain == "husbandry" for source in sources):
            # These are curated husbandry reference notes (access_depth "D"),
            # not peer-reviewed veterinary literature, and are tagged at
            # species-family level (e.g. "reptile_amphibian"), not the exact
            # species/morph — needs must be verified against a caresheet
            # for that specific animal.
            limitations.append(
                "Le indicazioni di allestimento/allevamento provengono da riferimenti "
                "divulgativi curati, non da letteratura scientifica peer-reviewed: "
                "verifica sempre i parametri per la tua specie e sottospecie esatta "
                "con un veterinario esperto in esotici o un allevatore specializzato."
            )
        if not limitations:
            limitations.append(
                "Le evidenze restano informative e non sostituiscono una visita veterinaria."
            )
        return limitations
