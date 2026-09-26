from concurrent.futures import ThreadPoolExecutor

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource


class MultiSourceEvidenceRetriever(EvidenceRetriever):
    """Combines several EvidenceRetriever sources into one (spec v3 §20:
    PubMed, Europe PMC, Crossref, OpenAlex as complementary sources, not
    alternatives to choose between).

    Every source is always queried, in parallel (they are independent
    network calls, so this keeps overall latency close to the slowest
    single source instead of the sum of all four). Real-world finding:
    stopping early as soon as one source filled max_results let a source
    that happened to return a few weakly-relevant (tier C) matches crowd
    out a genuinely relevant, higher-tier match from a source queried
    later — so results are pooled first, deduplicated by DOI/PMID/title
    (the same paper is commonly indexed by more than one of these),
    ranked by tier (A best), and only then trimmed to max_results. A
    single source failing (network error, bad response) degrades
    gracefully — each retriever already swallows its own errors into an
    empty list — rather than failing retrieval altogether.
    """

    def __init__(self, sources: list[EvidenceRetriever]) -> None:
        self._sources = sources

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        with ThreadPoolExecutor(max_workers=len(self._sources) or 1) as pool:
            futures = [pool.submit(source.retrieve, request_data) for source in self._sources]
            results_per_source: list[list[EvidenceSource]] = []
            for future in futures:
                try:
                    results_per_source.append(future.result())
                except Exception:
                    results_per_source.append([])

        merged: list[EvidenceSource] = []
        seen: set[str] = set()
        for results in results_per_source:
            for candidate in results:
                dedup_key = (
                    candidate.doi
                    or candidate.pmid
                    or f"{candidate.title.strip().lower()}::{candidate.year}"
                )
                if dedup_key in seen:
                    continue
                seen.add(dedup_key)
                merged.append(candidate)
        merged.sort(key=lambda source: source.tier)
        return merged[: request_data.max_results]
