from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource


class IntentRoutedEvidenceRetriever(EvidenceRetriever):
    """Routes a request to a different EvidenceRetriever by intent, instead
    of always pooling every intent's results through the same pipeline.

    Real-world finding (live verification against the real scientific_multi
    backend): querying the biomedical multi-source pipeline for a husbandry
    question ("che lampada UVB per il mio geco?") reliably returns
    confident-looking but genuinely tangential real papers (flying-fox
    metabolic bone disease, snake shed-skin corticosterone, ornamental
    shrimp transport) — Europe PMC/PubMed/Crossref/OpenAlex have no way to
    know these are off-topic for THIS question, so they consistently reach
    the synthesis step and just as consistently fail it (no claim they
    actually support), burning an LLM call for nothing. Worse, pooling them
    with the curated husbandry catalog doesn't help: EvidenceQualityEngine's
    tier-based methodological_quality weighting is meant to rank among
    papers of the same kind, and isn't a fair comparison against a
    genuinely different evidence layer (a tier "B" real-but-tangential
    paper reliably outscores a tier "D" curated-but-on-topic note). For
    husbandry_question specifically, skip biomedical literature search
    altogether and answer only from the curated catalog; every other
    intent is unaffected.
    """

    def __init__(
        self,
        default: EvidenceRetriever,
        overrides: dict[str, EvidenceRetriever],
    ) -> None:
        self._default = default
        self._overrides = overrides

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        retriever = self._overrides.get(request.intent, self._default)
        return retriever.retrieve(request)
