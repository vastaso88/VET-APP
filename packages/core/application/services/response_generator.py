from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis


class ResponseGenerator:
    """Turns a structured EvidenceSynthesis into the owner-facing reply
    (spec v3 §30) — friendly, calm, proportional to risk, in natural
    paragraphs rather than forced mechanical headings. Sections only
    appear when the synthesis actually populated them, so a simple case
    (just supported_claims) reads as a short direct answer, not a
    template with empty parts filled in.
    """

    def render(self, synthesis: EvidenceSynthesis) -> str:
        parts: list[str] = []

        if synthesis.supported_claims:
            parts.append(" ".join(synthesis.supported_claims))

        if synthesis.uncertain_claims:
            parts.append(
                "Alcune fonti suggeriscono anche che "
                + "; ".join(synthesis.uncertain_claims)
                + ", anche se non è del tutto certo."
            )

        if synthesis.conflicting_evidence:
            parts.append(
                "Su questo punto le fonti non sono concordi: "
                + "; ".join(synthesis.conflicting_evidence)
            )

        if synthesis.safe_owner_actions:
            parts.append(
                "Nel frattempo puoi: " + "; ".join(synthesis.safe_owner_actions) + "."
            )

        if synthesis.monitoring_points:
            parts.append("Tieni d'occhio: " + "; ".join(synthesis.monitoring_points) + ".")

        if synthesis.referral_conditions:
            parts.append(
                "Contatta il veterinario se: " + "; ".join(synthesis.referral_conditions) + "."
            )

        return "\n\n".join(parts)
