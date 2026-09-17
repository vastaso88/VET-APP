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

BASE_URL = "https://api.crossref.org/works"

SPECIES_TERMS: dict[str, str] = {
    "dog": "canine dog",
    "cat": "feline cat",
    "rabbit": "rabbit lagomorph",
    "bird": "avian bird",
}

# Crossref's metadata doesn't classify study type the way PubMed/Europe
# PMC do — the title is the only reliable signal available without an
# extra per-item lookup, so tiering here is a coarser, title-keyword
# heuristic rather than a real publication-type classification.
HIGH_TIER_TITLE_MARKERS = ("systematic review", "meta-analysis", "clinical guideline", "consensus")
MID_TIER_TITLE_MARKERS = ("randomized controlled trial", "randomised controlled trial", "review")

FetchFn = Callable[[str], bytes]


def _tier_from_title(title: str) -> str:
    lowered = title.lower()
    if "retract" in lowered:
        return "D"
    if any(marker in lowered for marker in HIGH_TIER_TITLE_MARKERS):
        return "A"
    if any(marker in lowered for marker in MID_TIER_TITLE_MARKERS):
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


class CrossrefEvidenceRetriever(EvidenceRetriever):
    """Real scientific evidence retrieval via the Crossref REST API
    (spec v3 §20) — no API key required.

    Crossref indexes bibliographic metadata for essentially every DOI
    ever registered, across publishers — strong for discovery and DOI
    normalization, weak for full text (this API never returns it) and
    for methodological classification (no structured publication-type
    field comparable to PubMed's). Any network/parsing failure returns
    an empty list rather than raising.
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
            payload = json.loads(self._fetcher(url).decode("utf-8"))
        except (error.URLError, TimeoutError, ValueError, OSError):
            return []

        items = (payload.get("message") or {}).get("items") or []
        sources: list[EvidenceSource] = []
        seen: set[str] = set()
        for item in items:
            source = self._to_evidence_source(item, request_data)
            if source is None:
                continue
            dedup_key = source.doi or source.title
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
        query = " ".join(part for part in (terms, species_term) if part)
        params = {
            "query": query,
            "rows": str(min(max(request_data.max_results, 1), 25)),
            "filter": "type:journal-article",
        }
        return f"{BASE_URL}?{urllib.parse.urlencode(params)}"

    @staticmethod
    def _to_evidence_source(
        item: dict, request_data: EvidenceRetrievalRequest
    ) -> EvidenceSource | None:
        titles = item.get("title") or []
        title = titles[0] if titles else None
        if not title:
            return None
        tier = _tier_from_title(title)
        if tier == "D":
            return None
        year = None
        date_parts = ((item.get("published") or {}).get("date-parts") or [[]])[0]
        if date_parts:
            year = date_parts[0]
        container_titles = item.get("container-title") or []
        # An open license on the version of record is the only full-text
        # signal Crossref exposes — anything else is metadata-only.
        has_open_license = any(
            "creativecommons.org" in (license_entry.get("URL") or "")
            for license_entry in item.get("license") or []
        )
        return EvidenceSource(
            title=title,
            journal=container_titles[0] if container_titles else None,
            year=year,
            doi=item.get("DOI"),
            pmid=None,
            tier=tier,
            access_depth="A" if has_open_license else ("B" if tier in ("A", "B") else "C"),
            clinical_domain=_domain_from_intent(request_data.intent),
            species=request_data.species,
            snippet=None,
            source_url=item.get("URL"),
        )
