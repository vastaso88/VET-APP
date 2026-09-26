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

BASE_URL = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"

SPECIES_TERMS: dict[str, str] = {
    "dog": "(canine OR dog)",
    "cat": "(feline OR cat)",
    "small_mammal": (
        "(rabbit OR lagomorph OR guinea pig OR hamster OR chinchilla OR ferret OR rodent)"
    ),
    "bird": "(avian OR bird)",
    "reptile_amphibian": "(reptile OR amphibian OR lizard OR frog OR salamander OR axolotl)",
    "fish": "(fish OR pisces)",
}

FetchFn = Callable[[str], bytes]


def _tier_from_pub_types(pub_types: list[str]) -> str:
    lowered = [pub_type.lower() for pub_type in pub_types]
    if any("retracted" in pub_type for pub_type in lowered):
        return "D"
    if any("guideline" in pub_type or "consensus" in pub_type for pub_type in lowered):
        return "A"
    if any("systematic review" in pub_type or "meta-analysis" in pub_type for pub_type in lowered):
        return "A"
    if any("randomized controlled trial" in pub_type for pub_type in lowered):
        return "B"
    if any("review" in pub_type for pub_type in lowered):
        return "B"
    return "C"


def _access_depth_from_item(item: dict, tier: str) -> str:
    """Spec v3 §21: a distinct axis from `tier` — how much of the source we
    can actually see, not how methodologically strong it is."""
    if tier in ("A", "B"):
        return "B"  # guideline/consensus/systematic-review-grade document
    if item.get("isOpenAccess") == "Y" or item.get("inEPMC") == "Y":
        return "A"  # full text legally accessible
    return "C"  # metadata/abstract only — the common case for paywalled work


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


class EuropePmcEvidenceRetriever(EvidenceRetriever):
    """Real scientific evidence retrieval via the Europe PMC REST API
    (spec v3 §20) — no API key required.

    Exclusion rules (spec v3 §3): retracted publications are never
    surfaced. Any network/parsing failure returns an empty list rather
    than raising, so a flaky external API degrades to the existing
    "no source, no answer" behaviour instead of breaking the chat.
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
        url = self._build_url(request_data)
        try:
            raw = self._fetcher(url)
            payload = json.loads(raw.decode("utf-8"))
        except (error.URLError, TimeoutError, ValueError, OSError):
            return []

        results = payload.get("resultList", {}).get("result", []) or []
        sources: list[EvidenceSource] = []
        seen: set[str] = set()
        for item in results:
            source = self._to_evidence_source(item, request_data)
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

    def _build_url(self, request_data: EvidenceRetrievalRequest) -> str:
        terms = self._query_planner.build_query(request_data.query, request_data.intent)
        species_term = SPECIES_TERMS.get(request_data.species, "")
        query = " AND ".join(part for part in (terms, species_term, "SRC:MED") if part)
        params = {
            "query": query,
            "format": "json",
            "pageSize": str(min(max(request_data.max_results, 1), 25)),
            "resultType": "core",
        }
        return f"{BASE_URL}?{urllib.parse.urlencode(params)}"

    @staticmethod
    def _to_evidence_source(
        item: dict, request_data: EvidenceRetrievalRequest
    ) -> EvidenceSource | None:
        title = item.get("title")
        if not title:
            return None
        pub_types = (item.get("pubTypeList") or {}).get("pubType", []) or []
        tier = _tier_from_pub_types(pub_types)
        if tier == "D":
            return None
        year_raw = item.get("pubYear")
        try:
            year = int(year_raw) if year_raw else None
        except ValueError:
            year = None
        source_url = (
            f"https://europepmc.org/article/{item['source']}/{item['id']}"
            if item.get("source") and item.get("id")
            else None
        )
        journal_title = (
            (item.get("journalInfo") or {}).get("journal") or {}
        ).get("title")
        access_depth = _access_depth_from_item(item, tier)
        return EvidenceSource(
            title=title,
            journal=journal_title,
            year=year,
            doi=item.get("doi"),
            pmid=item.get("pmid"),
            tier=tier,
            access_depth=access_depth,
            clinical_domain=_domain_from_intent(request_data.intent),
            species=request_data.species,
            snippet=(item.get("abstractText") or "")[:400] or None,
            source_url=source_url,
        )
