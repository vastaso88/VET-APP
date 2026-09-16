from collections.abc import Iterable

from pydantic import BaseModel, Field

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.situation.coverage import (
    DEFAULT_COVERAGE_WEIGHTS,
    CoverageWeights,
    coverage_score,
)
from packages.core.domain.situation.models import SituationModel

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
    conversation_history: list[ChatMessage] = Field(default_factory=list)
    situation_model: SituationModel | None = None
    interview_turns_used: int = 0


class ChatOrchestratorResult(BaseModel):
    answer: str
    mode: str
    confidence: str
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


class ChatOrchestrator:
    def __init__(
        self,
        llm_client: LLMClient,
        evidence_retriever: EvidenceRetriever,
        *,
        safety_gate: SafetyGate | None = None,
        situation_model_builder: SituationModelBuilder | None = None,
        interview_planner: InterviewPlanner | None = None,
        enable_interview_loop: bool = False,
        coverage_weights: CoverageWeights = DEFAULT_COVERAGE_WEIGHTS,
        coverage_target: float = 0.85,
        max_interview_questions: int = 1,
    ) -> None:
        self._llm_client = llm_client
        self._evidence_retriever = evidence_retriever
        self._safety_gate = safety_gate or SafetyGate()
        self._situation_model_builder = situation_model_builder or SituationModelBuilder(llm_client)
        self._interview_planner = interview_planner or InterviewPlanner()
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
                    "I sintomi descritti possono indicare una situazione urgente. "
                    "Contatta subito il veterinario o un pronto soccorso veterinario e, "
                    "nel frattempo, mantieni il pet al caldo, tranquillo e in sicurezza."
                ),
                mode="triage",
                confidence="high",
                safety_flags=safety_flags,
                limitations=["Triage prudenziale generato senza approfondimento diagnostico."],
                recommended_action="Valutazione veterinaria immediata.",
                provider="rule-based",
                model="safety-triage-guard",
                state=ConversationState.POSSIBLE_URGENT_CASE,
            )

        intent = self._classify_intent(lowered)
        if intent == "general_info":
            return self._generate_general_answer(data, message)

        situation = data.situation_model or SituationModel()
        turns_used = data.interview_turns_used
        if self._enable_interview_loop:
            situation = self._situation_model_builder.update(
                situation, message, data.conversation_history
            )
            coverage = coverage_score(situation, self._coverage_weights)
            if coverage < self._coverage_target and turns_used < self._max_interview_questions:
                question = self._interview_planner.next_question(situation)
                if question is not None:
                    return ChatOrchestratorResult(
                        answer=question,
                        mode="interview",
                        confidence="low",
                        provider="rule-based",
                        model="interview-planner",
                        state=ConversationState.NEED_MORE_INFORMATION,
                        situation_model=situation,
                        coverage_score=coverage,
                        interview_turns_used=turns_used + 1,
                    )
        else:
            coverage = None

        result = self._generate_evidence_answer(data, message, intent)
        result.situation_model = situation
        result.coverage_score = coverage
        result.interview_turns_used = turns_used
        return result

    def _generate_general_answer(
        self,
        data: ChatOrchestratorInput,
        message: str,
    ) -> ChatOrchestratorResult:
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    "You are a veterinary app assistant. Answer clearly, avoid diagnosis, "
                    "and encourage professional care when symptoms worsen."
                ),
                user_prompt=(
                    f"Pet name: {data.pet_name}\n"
                    f"Species: {data.species}\n"
                    f"User request: {message}"
                ),
            )
        )
        return ChatOrchestratorResult(
            answer=response.content,
            mode="general",
            confidence="medium",
            limitations=["General guidance without evidence retrieval."],
            provider=response.provider,
            model=response.model,
        )

    def _generate_evidence_answer(
        self,
        data: ChatOrchestratorInput,
        message: str,
        intent: str,
    ) -> ChatOrchestratorResult:
        sources = self._evidence_retriever.retrieve(
            EvidenceRetrievalRequest(query=message, species=data.species, intent=intent)
        )
        if not sources:
            return ChatOrchestratorResult(
                answer=(
                    "Non ho trovato evidenze affidabili sufficienti per rispondere in modo "
                    "sicuro a questa domanda. Posso aiutarti a riformularla oppure a "
                    "preparare le informazioni da portare al veterinario."
                ),
                mode="evidence",
                confidence="low",
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
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    "You are an evidence-first veterinary assistant. Use only the provided "
                    "sources, be explicit about uncertainty, and do not invent citations."
                ),
                user_prompt=(
                    f"Pet name: {data.pet_name}\n"
                    f"Species: {data.species}\n"
                    f"Question: {message}\n"
                    f"Evidence:\n{evidence_block}\n"
                    "Write a concise answer in the user's language, mention limits, and avoid diagnosis."
                ),
            )
        )
        return ChatOrchestratorResult(
            answer=response.content,
            mode="evidence",
            confidence=self._confidence_from_sources(sources),
            sources=sources,
            limitations=self._build_limitations(sources),
            recommended_action="Consulta il veterinario per una valutazione personalizzata se i sintomi persistono.",
            provider=response.provider,
            model=response.model,
        )

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
    def _confidence_from_sources(sources: list[EvidenceSource]) -> str:
        if any(source.tier == "A" for source in sources):
            return "high"
        if len(sources) >= 2:
            return "medium"
        return "low"

    @staticmethod
    def _build_limitations(sources: list[EvidenceSource]) -> list[str]:
        limitations: list[str] = []
        if not any(source.tier == "A" for source in sources):
            limitations.append("Le fonti recuperate non includono guideline o systematic review Tier A.")
        if any(source.species == "other" for source in sources):
            limitations.append("Alcune fonti non sono specie-specifiche.")
        if not limitations:
            limitations.append("Le evidenze restano informative e non sostituiscono una visita veterinaria.")
        return limitations
