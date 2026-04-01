from packages.core.domain.knowledge.models import EvidenceSource


class CuriosityEngine:
    CURIOSITY_HINTS: tuple[str, ...] = (
        "perche",
        "why",
        "normal",
        "normale",
        "comportamento",
        "behavior",
        "fa sempre",
    )

    def is_curiosity_question(self, message: str) -> bool:
        lowered = message.lower()
        return any(hint in lowered for hint in self.CURIOSITY_HINTS)

    def generate_behavior_explanation(
        self,
        message: str,
        sources: list[EvidenceSource],
    ) -> str:
        if sources:
            snippet = sources[0].snippet or "alcuni comportamenti vanno letti nel loro contesto"
        else:
            snippet = "molti comportamenti hanno spiegazioni legate a contesto, abitudine e stato emotivo"
        return (
            f"Questo comportamento puo avere una spiegazione normale o contestuale: {snippet}. "
            "Conta osservare quando succede, cosa lo innesca e se cambia nel tempo."
        )

    def generate_normal_behavior_education(
        self,
        message: str,
        species: str,
    ) -> str:
        return (
            f"Per un {species}, alcuni comportamenti possono essere normali se il pet resta attivo, "
            "mangia, beve e non mostra segnali di dolore o peggioramento."
        )
