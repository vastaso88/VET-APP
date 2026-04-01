from collections.abc import Iterable

from pydantic import BaseModel, Field

from ai_core.education.curiosity_engine import CuriosityEngine
from ai_core.education.education_engine import EducationEngine
from ai_core.education.education_formatter import EducationFormatter
from ai_core.education.owner_profiles import OwnerKnowledgeProfile
from ai_core.knowledge.quality.confidence_model import EvidencePack
from ai_core.knowledge.quality.quality_firewall import QualityFirewall
from ai_core.knowledge.quality.unknown_response_builder import UnknownResponseBuilder
from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.application.ports.llm_client import LLMClient, LLMGenerationRequest
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.knowledge.models import EvidenceSource

URGENT_RED_FLAG_KEYWORDS = {
    "convuls",
    "seizure",
    "non respira",
    "respira male",
    "dispnea",
    "emorrag",
    "sanguina",
    "trauma",
    "collasso",
    "collapse",
    "anuria",
    "non urina",
    "incidente",
}

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


class ChatOrchestrator:
    def __init__(self, llm_client: LLMClient, evidence_retriever: EvidenceRetriever) -> None:
        self._llm_client = llm_client
        self._evidence_retriever = evidence_retriever
        self._quality_firewall = QualityFirewall()
        self._unknown_response_builder = UnknownResponseBuilder()
        self._education_engine = EducationEngine()
        self._education_formatter = EducationFormatter()
        self._curiosity_engine = CuriosityEngine()

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        message = data.user_message.strip()
        lowered = message.lower()
        safety_flags = self._detect_urgent_red_flags(lowered)
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
            )

        intent = self._classify_intent(lowered)
        if intent == "general_info":
            return self._generate_general_answer(data, message)
        return self._generate_evidence_answer(data, message, intent)

    def _generate_general_answer(
        self,
        data: ChatOrchestratorInput,
        message: str,
    ) -> ChatOrchestratorResult:
        if self._curiosity_engine.is_curiosity_question(message):
            answer = self._curiosity_engine.generate_normal_behavior_education(message, data.species)
            return ChatOrchestratorResult(
                answer=answer,
                mode="general",
                confidence="medium",
                limitations=["Spiegazione educativa generale senza retrieval specialistico."],
                provider="rule-based",
                model="curiosity-engine",
            )
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
        evidence_pack = EvidencePack(
            pet_species=data.species,
            clinical_domain=self._domain_from_intent(intent),
            owner_question=message,
            sources=sources,
        )
        firewall_decision = self._quality_firewall.evaluate_evidence(evidence_pack)

        if self._quality_firewall.can_generate_answer(firewall_decision) is False:
            unknown_response = self._unknown_response_builder.build(firewall_decision)
            return ChatOrchestratorResult(
                answer=unknown_response.answer,
                mode="evidence",
                confidence="low",
                limitations=unknown_response.limitations,
                recommended_action=unknown_response.recommended_action,
                provider="rule-based",
                model="knowledge-quality-firewall",
            )

        approved_sources = firewall_decision.approved_sources
        owner_profile = OwnerKnowledgeProfile()
        education_payload = self._education_engine.build_education_blocks(approved_sources, owner_profile)
        education_payload = self._education_engine.adapt_to_owner_level(
            education_payload,
            owner_profile,
        )
        educational_context = self._education_formatter.format_payload(education_payload, owner_profile)
        evidence_block = self._format_sources_for_prompt(approved_sources)
        response = self._llm_client.generate(
            LLMGenerationRequest(
                system_prompt=(
                    "You are an evidence-first veterinary assistant. Use only the provided "
                    "sources and educational guidance, be explicit about uncertainty, and do not invent citations."
                ),
                user_prompt=(
                    f"Pet name: {data.pet_name}\n"
                    f"Species: {data.species}\n"
                    f"Question: {message}\n"
                    f"Educational guidance:\n{educational_context}\n"
                    f"Evidence:\n{evidence_block}\n"
                    "Write a concise answer in the user's language, mention limits, and avoid diagnosis."
                ),
            )
        )
        return ChatOrchestratorResult(
            answer=response.content,
            mode="evidence",
            confidence=firewall_decision.overall_confidence,
            sources=approved_sources,
            limitations=self._build_limitations(approved_sources, firewall_decision.reasons),
            recommended_action="Consulta il veterinario per una valutazione personalizzata se i sintomi persistono.",
            provider=response.provider,
            model=response.model,
        )

    @staticmethod
    def _detect_urgent_red_flags(message: str) -> list[str]:
        return [keyword for keyword in URGENT_RED_FLAG_KEYWORDS if keyword in message]

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
    def _domain_from_intent(intent: str) -> str:
        return {
            "clinical_question": "clinical",
            "nutrition_question": "nutrition",
            "behavior_question": "behavior",
            "preventive_care": "preventive",
        }.get(intent, "general")

    @staticmethod
    def _build_limitations(sources: list[EvidenceSource], firewall_reasons: list[str]) -> list[str]:
        limitations: list[str] = []
        if not any(source.tier == "A" for source in sources):
            limitations.append("Le fonti approvate non includono guideline o systematic review Tier A.")
        if any(source.species == "other" for source in sources):
            limitations.append("Parte dell'evidenza approvata non e specie-specifica.")
        if firewall_reasons:
            limitations.append(f"Firewall qualitativo attivo: {', '.join(sorted(set(firewall_reasons)))}.")
        if not limitations:
            limitations.append("Le evidenze restano informative e non sostituiscono una visita veterinaria.")
        return limitations
