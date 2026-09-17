from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource


class MultiSourceEvidenceRetriever(EvidenceRetriever):
    """Combines several EvidenceRetriever sources into one (spec v3 §20:
    PubMed, Europe PMC, Crossref, OpenAlex as complementary sources, not
    alternatives to choose between).

    Each source is queried for the full requested count so a source
    returning few or no results doesn't starve the pool; results are then
    deduplicated across sources by DOI/PMID/title (the same paper is
    commonly indexed by more than one of these) and trimmed to the
    caller's max_results. A single source failing (network error, bad
    response) degrades gracefully — each retriever already swallows its
    own errors into an empty list — rather than failing retrieval
    altogether.
    """

    def __init__(self, sources: list[EvidenceRetriever]) -> None:
        self._sources = sources

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        merged: list[EvidenceSource] = []
        seen: set[str] = set()
        for source_retriever in self._sources:
            for candidate in source_retriever.retrieve(request_data):
                dedup_key = (
                    candidate.doi
                    or candidate.pmid
                    or f"{candidate.title.strip().lower()}::{candidate.year}"
                )
                if dedup_key in seen:
                    continue
                seen.add(dedup_key)
                merged.append(candidate)
                if len(merged) >= request_data.max_results:
                    return merged
        return merged
