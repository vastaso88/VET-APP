import json
import urllib.parse
from collections.abc import Callable
from urllib import error, request

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.application.services.evidence_query_planner import EvidenceQueryPlanner
from packages.core.domain.knowledge.models import EvidenceSource

ESEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
ESUMMARY_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"

SPECIES_TERMS: dict[str, str] = {
    "dog": "(canine OR dog OR canis)",
    "cat": "(feline OR cat OR felis)",
    "rabbit": "(rabbit OR lagomorph)",
    "bird": "(avian OR bird)",
}

FetchFn = Callable[[str], bytes]


def _tier_from_pub_types(pub_types: list[str]) -> str:
    lowered = [pub_type.lower() for pub_type in pub_types]
    if any("retracted" in pub_type for pub_type in lowered):
        return "D"
    if any("guideline" in pub_type or "practice guideline" in pub_type for pub_type in lowered):
        return "A"
    if any("systematic review" in pub_type or "meta-analysis" in pub_type for pub_type in lowered):
        return "A"
    if any("randomized controlled trial" in pub_type for pub_type in lowered):
        return "B"
    if any("review" in pub_type for pub_type in lowered):
        return "B"
    return "C"


def _domain_from_intent(intent: str) -> str:
    return {
        "clinical_question": "clinical",
        "nutrition_question": "nutrition",
        "behavior_question": "behavior",
        "preventive_care": "preventive",
    }.get(intent, "general")


def _default_fetcher(url: str, *, timeout_seconds: int) -> bytes:
    http_request = request.Request(url, headers={"Accept": "application/json"})
    with request.urlopen(http_request, timeout=timeout_seconds) as response:
        body: bytes = response.read()
        return body


class PubMedEvidenceRetriever(EvidenceRetriever):
    """Real scientific evidence retrieval via NCBI PubMed E-utilities
    (spec v3 §20) — no API key required for this call volume.

    Two-step lookup (esearch → esummary), matching how E-utilities is
    meant to be used: esearch returns matching PMIDs, esummary returns
    their metadata in one batched call. Exclusion/degrade rules mirror
    EuropePmcEvidenceRetriever: retracted publications are dropped, and
    any network/parsing failure returns an empty list rather than raising.
    """

    def __init__(
        self,
        *,
        timeout_seconds: int = 10,
        fetcher: FetchFn | None = None,
        query_planner: EvidenceQueryPlanner | None = None,
    ) -> None:
        self._timeout_seconds = timeout_seconds
        self._fetcher = fetcher or (
            lambda url: _default_fetcher(url, timeout_seconds=timeout_seconds)
        )
        self._query_planner = query_planner or EvidenceQueryPlanner()

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        pmids = self._search(request_data)
        if not pmids:
            return []
        summaries = self._summarize(pmids)
        sources: list[EvidenceSource] = []
        seen: set[str] = set()
        for pmid in pmids:
            item = summaries.get(pmid)
            if item is None:
                continue
            source = self._to_evidence_source(pmid, item, request_data)
            if source is None:
                continue
            dedup_key = source.doi or source.pmid or source.title
            if dedup_key in seen:
                continue
            seen.add(dedup_key)
            sources.append(source)
            if len(sources) >= request_data.max_results:
                break
        return sources

    def _search(self, request_data: EvidenceRetrievalRequest) -> list[str]:
        terms = self._query_planner.build_query(request_data.query, request_data.intent)
        species_term = SPECIES_TERMS.get(request_data.species, "")
        term = " AND ".join(part for part in (terms, species_term) if part)
        params = {
            "db": "pubmed",
            "term": term,
            "retmode": "json",
            "retmax": str(min(max(request_data.max_results, 1), 25)),
        }
        url = f"{ESEARCH_URL}?{urllib.parse.urlencode(params)}"
        try:
            payload = json.loads(self._fetcher(url).decode("utf-8"))
        except (error.URLError, TimeoutError, ValueError, OSError):
            return []
        result = payload.get("esearchresult") or {}
        return list(result.get("idlist") or [])

    def _summarize(self, pmids: list[str]) -> dict[str, dict]:
        params = {"db": "pubmed", "id": ",".join(pmids), "retmode": "json"}
        url = f"{ESUMMARY_URL}?{urllib.parse.urlencode(params)}"
        try:
            payload = json.loads(self._fetcher(url).decode("utf-8"))
        except (error.URLError, TimeoutError, ValueError, OSError):
            return {}
        result = payload.get("result") or {}
        return {uid: result[uid] for uid in result.get("uids", []) if uid in result}

    @staticmethod
    def _to_evidence_source(
        pmid: str, item: dict, request_data: EvidenceRetrievalRequest
    ) -> EvidenceSource | None:
        title = item.get("title")
        if not title:
            return None
        pub_types = item.get("pubtype") or []
        tier = _tier_from_pub_types(pub_types)
        if tier == "D":
            return None
        pub_date = item.get("pubdate") or ""
        year: int | None = None
        for token in pub_date.replace("-", " ").split():
            if token.isdigit() and len(token) == 4:
                year = int(token)
                break
        doi = None
        for article_id in item.get("articleids") or []:
            if article_id.get("idtype") == "doi":
                doi = article_id.get("value")
                break
        return EvidenceSource(
            title=title,
            journal=item.get("source"),
            year=year,
            doi=doi,
            pmid=pmid,
            tier=tier,
            # PubMed's esummary never carries full text or an OA flag —
            # metadata/abstract-level access is the honest default here.
            access_depth="B" if tier in ("A", "B") else "C",
            clinical_domain=_domain_from_intent(request_data.intent),
            species=request_data.species,
            snippet=None,
            source_url=f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/",
        )
