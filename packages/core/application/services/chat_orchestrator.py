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
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.answer_validation import validate_answer
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.situation.coverage import (
    DEFAULT_COVERAGE_WEIGHTS,
    CoverageWeights,
    coverage_score,
)
from packages.core.domain.situation.models import SituationModel

# Fetch a wider candidate pool than we'll actually show, so the quality
# engine has real diversity to rank and select from (spec v3 §3-5) instead
# of just re-sorting whatever the retriever's own default cap happened to
# return.
EVIDENCE_POOL_MULTIPLIER = 3
EVIDENCE_MIN_POOL_SIZE = 8

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
    ),
    "nutrition_question": ("cibo", "mangia", "aliment", "dieta", "nutriz"),
    "behavior_question": ("comport", "ansia", "abbaia", "graffia", "aggress"),
    "preventive_care": ("vaccin", "antiparass", "checkup", "preven", "profilassi"),
}


class ChatOrchestratorInput(BaseModel):
    user_message: str
    species: str
    pet_name: str
    pet_id: str = ""
    conversation_history: list[ChatMessage] = Field(default_factory=list)
    situation_model: SituationModel | None = None
    interview_turns_used: int = 0
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False


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
        self._enable_interview_loop = enable_interview_loop
        self._coverage_weights = coverage_weights
        self._coverage_target = coverage_target
        self._max_interview_questions = max_interview_questions

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        message = data.user_message.strip()
        lowered = message.lower()
        safety_flags = self._safety_gate.evaluate(lowered)
        if safety_flags:
            return ChatOrchestratorResult(
                answer=(
                    f"Hai fatto bene a scrivermi subito. Quello che mi racconti di "
                    f"{data.pet_name} è un segnale che merita una valutazione veterinaria "
                    "immediata. Ecco cosa fare adesso:\n"
                    "1) contatta subito il tuo veterinario o un pronto soccorso veterinario;\n"
                    f"2) nel frattempo tieni {data.pet_name} calmo, al caldo e al sicuro;\n"
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
        if intent == "general_info" and self._enable_interview_loop and situation.working_domains:
            # We're mid-interview on an already-established clinical topic —
            # a short follow-up reply ("da due giorni", "solo in casa") won't
            # repeat the original keywords, but reclassifying it fresh would
            # silently drop the case into a generic, un-grounded answer.
            # Stay on the established topic instead.
            intent = situation.working_domains[0]
        if intent == "general_info":
            return self._generate_general_answer(data, message)

        coverage: float | None = None

        if self._enable_interview_loop:
            situation = self._situation_model_builder.update(
                situation, message, data.conversation_history
            )
            if intent not in situation.working_domains:
                situation = situation.merge(SituationModel(working_domains=[intent]))

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
                elif not situation.presenting_problem:
                    # Question budget exhausted and we still don't even know
                    # what the problem is: don't guess, and don't spend an
                    # evidence-retrieval call on a case we can't describe yet.
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
                # Otherwise: budget exhausted but we at least know the
                # presenting problem — fall through to the evidence step
                # below, which already refuses to answer without sources.

        result = self._generate_evidence_answer(data, message, intent, situation)
        result.situation_model = situation
        result.coverage_score = coverage
        result.interview_turns_used = turns_used
        result.medical_record_consent = medical_record_consent
        return result

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
    ) -> ChatOrchestratorResult:
        anonymized_message = self._anonymize_for_provider(message)
        anonymized_pet_name = self._anonymize_for_provider(data.pet_name)
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    "You are a veterinary app assistant. Answer clearly, avoid diagnosis, "
                    "and encourage professional care when symptoms worsen. There is no "
                    "retrieved evidence for this turn, so never include a [n] citation."
                ),
                user_prompt=(
                    f"Pet name: {anonymized_pet_name}\n"
                    f"Species: {data.species}\n"
                    f"User request: {anonymized_message}"
                ),
            )
        )
        # No sources exist in this path, so ANY [n] citation the model
        # produces is by definition invented (spec v3 §28).
        validation = validate_answer(response.content, sources_count=0)
        if not validation.is_valid:
            return self._validation_failure_result(
                sources=[], violations=validation.violations, mode="general"
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
    ) -> ChatOrchestratorResult:
        final_request = EvidenceRetrievalRequest(query=message, species=data.species, intent=intent)
        pool_size = max(
            final_request.max_results * EVIDENCE_POOL_MULTIPLIER, EVIDENCE_MIN_POOL_SIZE
        )
        pool_request = final_request.model_copy(update={"max_results": pool_size})
        raw_sources = self._evidence_retriever.retrieve(pool_request)
        ranked = self._evidence_quality_engine.rank_and_select(
            raw_sources,
            species=data.species,
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
                    "No source, no answer: il retrieval del prototipo non ha prodotto fonti ammissibili."
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
        anonymized_message = self._anonymize_for_provider(message)
        anonymized_pet_name = self._anonymize_for_provider(data.pet_name)
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    "You are an evidence-first veterinary assistant. Use only the provided "
                    "sources, be explicit about uncertainty, and do not invent citations — "
                    "only cite [n] markers that appear in the Evidence list below. Where it "
                    "reads naturally, structure the answer as: what we understand, what the "
                    "evidence supports, what to watch for, and when to contact a vet — but "
                    "prefer a short, direct answer over forcing every section in."
                ),
                user_prompt=(
                    f"Pet name: {anonymized_pet_name}\n"
                    f"Species: {data.species}\n"
                    f"Question: {anonymized_message}\n"
                    f"Evidence:\n{evidence_block}\n"
                    "Write a concise answer in the user's language, mention limits, and avoid diagnosis."
                ),
            )
        )

        validation = validate_answer(response.content, sources_count=len(sources))
        if not validation.is_valid:
            return self._validation_failure_result(
                sources=sources, violations=validation.violations, mode="evidence"
            )

        answer = response.content
        limitations = self._build_limitations(sources)
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
            recommended_action="Consulta il veterinario per una valutazione personalizzata se i sintomi persistono.",
            provider=response.provider,
            model=response.model,
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

    def _anonymize_for_provider(self, text: str) -> str:
        """Strip PII before text leaves the system to the external LLM
        provider. Only applied to the outbound prompt — evidence retrieval
        (local) and the stored conversation/reply keep the original text,
        per the documented anonymization boundary (docs/compliance/02_pii_anonymization.md)."""
        return self._pii_anonymizer.anonymize(PiiAnonymizationRequest(text=text)).anonymized_text

    @staticmethod
    def _classify_intent(message: str) -> str:
        for intent, keywords in EVIDENCE_KEYWORDS.items():
            if any(keyword in message for keyword in keywords):
                return intent
        return "general_info"

    @staticmethod
    def _format_sources_for_prompt(sources: Iterable[EvidenceSource]) -> str:
        lines: list[str] = []
        for index, source in enumerate(sources, start=1):
            lines.append(
                (
                    f"[{index}] {source.title} | {source.journal or 'Unknown journal'} | "
                    f"{source.year or 'n.d.'} | Tier {source.tier}\n"
                    f"Snippet: {source.snippet or 'No snippet available.'}"
                )
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
            limitations.append("Le fonti recuperate non includono guideline o systematic review Tier A.")
        if any(source.species == "other" for source in sources):
            limitations.append("Alcune fonti non sono specie-specifiche.")
        if all(source.access_depth == "C" for source in sources):
            limitations.append(
                "Per queste fonti abbiamo solo titolo e abstract, non il testo completo."
            )
        if not limitations:
            limitations.append("Le evidenze restano informative e non sostituiscono una visita veterinaria.")
        return limitations
