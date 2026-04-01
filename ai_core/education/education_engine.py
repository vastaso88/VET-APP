from ai_core.education.education_models import EducationBlock, EducationResponsePayload
from ai_core.education.owner_profiles import OwnerKnowledgeProfile
from packages.core.domain.knowledge.models import EvidenceSource

DOMAIN_MONITORING_GUIDANCE: dict[str, list[str]] = {
    "nutrition": ["appetito", "assunzione di acqua", "energia generale"],
    "clinical": ["durata dei sintomi", "energia", "eventuale peggioramento"],
    "behavior": ["trigger", "frequenza", "cambiamenti nell'ambiente"],
    "preventive": ["scadenze", "richiami", "esposizioni a rischio"],
}

DOMAIN_PREVENTION_TIPS: dict[str, str] = {
    "nutrition": "mantieni acqua disponibile e osserva eventuali variazioni rispetto al solito",
    "clinical": "annota inizio, frequenza e segnali associati per aiutare il veterinario se serve",
    "behavior": "osserva contesto e rinforzi prima di interpretare il comportamento come patologico",
    "preventive": "mantieni aggiornati controlli, profilassi e richiami",
}


class EducationEngine:
    def build_education_blocks(
        self,
        sources: list[EvidenceSource],
        owner_profile: OwnerKnowledgeProfile,
    ) -> EducationResponsePayload:
        blocks = [self._build_block(source, owner_profile) for source in sources]
        monitoring = self.generate_monitoring_guidance(sources)
        prevention = self.generate_prevention_tips(sources)
        return EducationResponsePayload(
            blocks=blocks,
            monitoring_guidance=monitoring,
            prevention_tips=prevention,
        )

    def adapt_to_owner_level(
        self,
        payload: EducationResponsePayload,
        owner_profile: OwnerKnowledgeProfile,
    ) -> EducationResponsePayload:
        if owner_profile.experience_level == "experienced":
            return payload
        adapted = payload.model_copy(deep=True)
        for block in adapted.blocks:
            if owner_profile.experience_level == "new_owner":
                block.clinical_fact = block.plain_explanation
                block.why_it_matters = f"In pratica: {block.why_it_matters.lower()}"
        return adapted

    def generate_monitoring_guidance(self, sources: list[EvidenceSource]) -> list[str]:
        guidance: list[str] = []
        for source in sources:
            guidance.extend(DOMAIN_MONITORING_GUIDANCE.get(source.clinical_domain, ["andamento generale"]))
        return list(dict.fromkeys(guidance))

    def generate_prevention_tips(self, sources: list[EvidenceSource]) -> list[str]:
        tips: list[str] = []
        for source in sources:
            tip = DOMAIN_PREVENTION_TIPS.get(source.clinical_domain)
            if tip:
                tips.append(tip)
        return list(dict.fromkeys(tips))

    def _build_block(
        self,
        source: EvidenceSource,
        owner_profile: OwnerKnowledgeProfile,
    ) -> EducationBlock:
        snippet = source.snippet or "serve sempre leggere il quadro nel suo contesto"
        plain = self._plain_explanation(snippet, owner_profile.communication_style)
        monitoring = DOMAIN_MONITORING_GUIDANCE.get(source.clinical_domain, ["andamento del pet"])
        return EducationBlock(
            title=source.title,
            clinical_fact=snippet,
            plain_explanation=plain,
            why_it_matters="Aiuta a capire cosa osservare e quando serve aumentare l'attenzione",
            what_to_monitor=monitoring,
            when_to_worry=self._when_to_worry(source),
            prevention_tip=DOMAIN_PREVENTION_TIPS.get(source.clinical_domain),
        )

    @staticmethod
    def _plain_explanation(snippet: str, style: str) -> str:
        if style == "simple":
            return f"In parole semplici: {snippet}"
        if style == "detailed":
            return f"Spiegazione educativa: {snippet}"
        return snippet

    @staticmethod
    def _when_to_worry(source: EvidenceSource) -> list[str]:
        snippet = (source.snippet or "").lower()
        warnings: list[str] = []
        if "hydration" in snippet or "acqua" in snippet:
            warnings.append("beve poco o mostra segni di disidratazione")
        if "respiratory" in snippet or "respir" in snippet:
            warnings.append("respira con fatica o peggiora rapidamente")
        if "persistent" in snippet or "continua" in snippet:
            warnings.append("il problema continua o si ripete")
        if not warnings:
            warnings.append("compare peggioramento, dolore o riduzione di energia")
        return warnings
