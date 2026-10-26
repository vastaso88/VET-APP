import re

from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis
from packages.core.domain.localization import normalize_locale
from packages.core.domain.localization_fr import CONNECTORS_FR

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

    def render(
        self,
        synthesis: EvidenceSynthesis,
        *,
        include_citation_markers: bool = True,
        response_locale: str = "it",
    ) -> str:
        """`include_citation_markers=False` strips inline "[n]" markers
        from the rendered text (2026-09-20 product realignment: for
        everyday concern questions, evidence should keep validating the
        answer internally without reading like an academic citation
        list — see chat_orchestrator._generate_evidence_answer, which
        keeps markers on for husbandry_question, a genuinely reference-
        style intent, and strips them everywhere else).
        """
        copy = _CONNECTORS[normalize_locale(response_locale)]
        parts: list[str] = []

        if synthesis.supported_claims:
            parts.append(" ".join(synthesis.supported_claims))

        if synthesis.uncertain_claims:
            parts.append(
                copy["uncertain_prefix"]
                + "; ".join(synthesis.uncertain_claims)
                + copy["uncertain_suffix"]
            )

        if synthesis.conflicting_evidence:
            parts.append(copy["conflicting_prefix"] + "; ".join(synthesis.conflicting_evidence))

        if synthesis.safe_owner_actions:
            parts.append(copy["actions_prefix"] + "; ".join(synthesis.safe_owner_actions) + ".")

        if synthesis.monitoring_points:
            parts.append(copy["monitoring_prefix"] + "; ".join(synthesis.monitoring_points) + ".")

        if synthesis.referral_conditions:
            parts.append(copy["referral_prefix"] + "; ".join(synthesis.referral_conditions) + ".")

        text = "\n\n".join(parts)
        if not include_citation_markers:
            text = _CITATION_MARKER_PATTERN.sub("", text)
        return text


_CONNECTORS: dict[str, dict[str, str]] = {
    "it": {
        "uncertain_prefix": "Alcune fonti suggeriscono anche che ",
        "uncertain_suffix": ", anche se non è del tutto certo.",
        "conflicting_prefix": "Su questo punto le fonti non sono concordi: ",
        "actions_prefix": "Nel frattempo puoi: ",
        "monitoring_prefix": "Tieni d'occhio: ",
        "referral_prefix": "Contatta il veterinario se: ",
    },
    "en": {
        "uncertain_prefix": "Some sources also suggest that ",
        "uncertain_suffix": ", although this is not fully certain.",
        "conflicting_prefix": "The sources do not agree on this point: ",
        "actions_prefix": "Meanwhile, you can: ",
        "monitoring_prefix": "Keep an eye on: ",
        "referral_prefix": "Contact the veterinarian if: ",
    },
    "es": {
        "uncertain_prefix": "Algunas fuentes también sugieren que ",
        "uncertain_suffix": ", aunque no es del todo seguro.",
        "conflicting_prefix": "Las fuentes no coinciden en este punto: ",
        "actions_prefix": "Mientras tanto, puedes: ",
        "monitoring_prefix": "Vigila: ",
        "referral_prefix": "Contacta con el veterinario si: ",
    },
    "de": {
        "uncertain_prefix": "Einige Quellen deuten auch darauf hin, dass ",
        "uncertain_suffix": ", wobei das nicht ganz sicher ist.",
        "conflicting_prefix": "Die Quellen sind sich in diesem Punkt nicht einig: ",
        "actions_prefix": "In der Zwischenzeit können Sie: ",
        "monitoring_prefix": "Behalten Sie im Auge: ",
        "referral_prefix": "Wenden Sie sich an die Tierärztin bzw. den Tierarzt, wenn: ",
    },
    "fr": CONNECTORS_FR,
}
