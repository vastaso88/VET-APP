import re

from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis

# Strips a trailing "[1]"/"[12]" citation marker (with its leading space,
# if any) from rendered prose. Non-overlapping matches handle consecutive
# markers ("...riposo [1][2].") cleanly: each bracket is removed in turn,
# and only the first of the run has a leading space to strip.
_CITATION_MARKER_PATTERN = re.compile(r"\s?\[\d+\]")


class ResponseGenerator:
    """Turns a structured EvidenceSynthesis into the owner-facing reply
    (spec v3 §30) — friendly, calm, proportional to risk, in natural
    paragraphs rather than forced mechanical headings. Sections only
    appear when the synthesis actually populated them, so a simple case
    (just supported_claims) reads as a short direct answer, not a
    template with empty parts filled in.
    """

    def render(self, synthesis: EvidenceSynthesis, *, include_citation_markers: bool = True) -> str:
        """`include_citation_markers=False` strips inline "[n]" markers
        from the rendered text (2026-09-20 product realignment: for
        everyday concern questions, evidence should keep validating the
        answer internally without reading like an academic citation
        list — see chat_orchestrator._generate_evidence_answer, which
        keeps markers on for husbandry_question, a genuinely reference-
        style intent, and strips them everywhere else).
        """
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

        text = "\n\n".join(parts)
        if not include_citation_markers:
            text = _CITATION_MARKER_PATTERN.sub("", text)
        return text
