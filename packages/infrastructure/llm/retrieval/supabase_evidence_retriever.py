from __future__ import annotations

from typing import TYPE_CHECKING, Any

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource

if TYPE_CHECKING:
    from supabase import Client


QUERY_DOMAIN_MAP: dict[str, str] = {
    "clinical_question": "clinical",
    "nutrition_question": "nutrition",
    "behavior_question": "behavior",
    "preventive_care": "preventive",
}


class SupabaseEvidenceRetriever(EvidenceRetriever):
    def __init__(
        self,
        client: Client,
        function_name: str = "ai.match_source_chunks",
    ) -> None:
        self._client = client
        self._function_name = function_name

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        payload = {
            "query_embedding": self._build_placeholder_embedding(),
            "match_count": request.max_results,
            "species_filter": request.species,
            "domain_filter": QUERY_DOMAIN_MAP.get(request.intent),
            "min_tier": "C",
        }
        result = self._client.rpc(self._function_name, payload).execute()
        rows = getattr(result, "data", None) or []
        return self._deduplicate_rows(rows)

    @staticmethod
    def _build_placeholder_embedding() -> list[float]:
        # This keeps the adapter contract stable while the embedding query
        # generation pipeline is introduced in a later milestone.
        return [0.0] * 1536

    @staticmethod
    def _deduplicate_rows(rows: list[dict[str, Any]]) -> list[EvidenceSource]:
        deduped: dict[str, EvidenceSource] = {}
        for row in rows:
            document_id = str(row.get("document_id") or row.get("chunk_id") or len(deduped))
            if document_id in deduped:
                continue
            domains = row.get("clinical_domain") or row.get("clinical_domains") or []
            species_tags = row.get("species_tags") or []
            deduped[document_id] = EvidenceSource(
                title=row.get("title") or "Untitled source",
                journal=row.get("journal_name"),
                year=row.get("publication_year"),
                doi=row.get("doi"),
                pmid=row.get("pmid"),
                tier=row.get("reliability_tier") or "C",
                clinical_domain=domains[0] if domains else "general",
                species=species_tags[0] if species_tags else "other",
                snippet=row.get("content") or row.get("summary"),
                source_url=row.get("canonical_url"),
            )
        return list(deduped.values())
