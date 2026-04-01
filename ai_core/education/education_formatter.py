from ai_core.education.education_models import EducationBlock, EducationResponsePayload
from ai_core.education.owner_profiles import OwnerKnowledgeProfile


class EducationFormatter:
    def simplify(self, text: str, style: str) -> str:
        if style == "simple":
            return text.replace("clinicamente", "").replace("contestualizzata", "chiara").strip()
        if style == "detailed":
            return text
        return text

    def add_reassurance(self, text: str) -> str:
        return f"{text} L'obiettivo e aiutarti a osservare meglio il quadro senza allarmismi inutili."

    def add_limits(self, text: str) -> str:
        return (
            f"{text} Queste indicazioni sono educative e non sostituiscono una valutazione veterinaria."
        )

    def add_actionable_steps(self, text: str, steps: list[str]) -> str:
        if not steps:
            return text
        return f"{text} Cose pratiche da osservare: {'; '.join(steps)}."

    def format_payload(
        self,
        payload: EducationResponsePayload,
        owner_profile: OwnerKnowledgeProfile,
    ) -> str:
        paragraphs: list[str] = []
        for block in payload.blocks:
            paragraphs.append(self._format_block(block, owner_profile))
        if payload.monitoring_guidance:
            paragraphs.append(f"Monitoraggio: {'; '.join(payload.monitoring_guidance)}.")
        if payload.prevention_tips:
            paragraphs.append(f"Prevenzione: {'; '.join(payload.prevention_tips)}.")
        joined = " ".join(paragraphs)
        simplified = self.simplify(joined, owner_profile.communication_style)
        limited = self.add_limits(self.add_reassurance(simplified))
        return self.add_actionable_steps(limited, payload.monitoring_guidance[:3])

    @staticmethod
    def _format_block(block: EducationBlock, owner_profile: OwnerKnowledgeProfile) -> str:
        intro = block.plain_explanation if owner_profile.communication_style == "simple" else block.clinical_fact
        monitor = f" Monitorare: {', '.join(block.what_to_monitor)}." if block.what_to_monitor else ""
        worry = f" Attenzione se: {', '.join(block.when_to_worry)}." if block.when_to_worry else ""
        prevention = f" Prevenzione: {block.prevention_tip}." if block.prevention_tip else ""
        return f"{block.title}: {intro} {block.why_it_matters}.{monitor}{worry}{prevention}"
