from ai_core.knowledge.quality.confidence_model import ContradictionAssessment, EvidencePack

RISK_BUCKET_KEYWORDS: dict[str, tuple[str, ...]] = {
    "urgent": ("immediate", "urgent", "emergency", "immediata", "subito"),
    "consult": ("consult", "evaluation", "valutazione", "veterinario"),
    "monitor": ("monitor", "observe", "osservare", "watch"),
}


class ContradictionDetector:
    def detect(self, evidence_pack: EvidencePack) -> ContradictionAssessment:
        if len(evidence_pack.sources) < 2:
            return ContradictionAssessment()

        buckets = {self._risk_bucket(source.snippet or "") for source in evidence_pack.sources}
        contradiction_types: list[str] = []
        rationale: list[str] = []

        if "urgent" in buckets and "monitor" in buckets:
            contradiction_types.append("risk_level_conflict")
            rationale.append("Le fonti suggeriscono livelli di urgenza incompatibili.")
        if "consult" in buckets and "monitor" in buckets and len(buckets) > 1:
            contradiction_types.append("recommendation_conflict")
            rationale.append("Le raccomandazioni non convergono sullo stesso livello di azione.")

        contradiction_flag = bool(contradiction_types)
        return ContradictionAssessment(
            contradiction_flag=contradiction_flag,
            contradiction_types=contradiction_types,
            confidence_downgrade=0.2 if contradiction_flag else 0.0,
            safe_response_trigger=contradiction_flag,
            rationale=rationale,
        )

    @staticmethod
    def _risk_bucket(snippet: str) -> str:
        lowered = snippet.lower()
        for bucket, keywords in RISK_BUCKET_KEYWORDS.items():
            if any(keyword in lowered for keyword in keywords):
                return bucket
        return "monitor"
