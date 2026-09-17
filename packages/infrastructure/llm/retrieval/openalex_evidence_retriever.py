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

BASE_URL = "https://api.openalex.org/works"

SPECIES_TERMS: dict[str, str] = {
    "dog": "canine dog",
    "cat": "feline cat",
    "rabbit": "rabbit lagomorph",
    "bird": "avian bird",
}

# OpenAlex's `type` field is coarse (article/review/...); like Crossref,
# finer methodological classification isn't available without a separate
# full-text lookup, so this stays a title-keyword heuristic.
HIGH_TIER_TITLE_MARKERS = ("systematic review", "meta-analysis", "clinical guideline", "consensus")
MID_TIER_TITLE_MARKERS = ("randomized controlled trial", "randomised controlled trial")

FetchFn = Callable[[str], bytes]


def _tier_from_title_and_type(title: str, work_type: str) -> str:
    lowered = title.lower()
    if "retract" in lowered:
        return "D"
    if any(marker in lowered for marker in HIGH_TIER_TITLE_MARKERS):
        return "A"
    if any(marker in lowered for marker in MID_TIER_TITLE_MARKERS):
        return "B"
    if work_type == "review":
        return "B"
    return "C"


def _domain_from_intent(intent: str) -> str:
    return {
        "clinical_question": "clinical",
        "nutrition_question": "nutrition",
        "behavior_question": "behavior",
        "preventive_care": "preventive",
    }.get(intent, "general")


def _reconstruct_abstract(inverted_index: dict[str, list[int]] | None) -> str | None:
    """OpenAlex never returns plain abstract text (publisher licensing) —
    only a word→positions inverted index. Rebuilding it is the documented,
    intended way to recover a usable snippet."""
    if not inverted_index:
        return None
    positioned: list[tuple[int, str]] = []
    for word, positions in inverted_index.items():
        for position in positions:
            positioned.append((position, word))
    positioned.sort(key=lambda pair: pair[0])
    text = " ".join(word for _, word in positioned)
    return text[:400] or None


def _default_fetcher(url: str, *, timeout_seconds: int) -> bytes:
    http_request = request.Request(url, headers={"Accept": "application/json"})
    with request.urlopen(http_request, timeout=timeout_seconds) as response:
        body: bytes = response.read()
        return body


class OpenAlexEvidenceRetriever(EvidenceRetriever):
    """Real scientific evidence retrieval via the OpenAlex REST API
    (spec v3 §20) — no API key required.

    OpenAlex is the strongest of the four sources for a direct, reliable
    open-access signal (`open_access.is_oa`), used here for access-depth
    classification rather than guessing from licenses. Any network/
    parsing failure returns an empty list rather than raising.
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

        results = payload.get("results") or []
        sources: list[EvidenceSource] = []
        seen: set[str] = set()
        for item in results:
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
        search = " ".join(part for part in (terms, species_term) if part)
        params = {
            "search": search,
            "per-page": str(min(max(request_data.max_results, 1), 25)),
            "filter": "type:article",
        }
        return f"{BASE_URL}?{urllib.parse.urlencode(params)}"

    @staticmethod
    def _to_evidence_source(
        item: dict, request_data: EvidenceRetrievalRequest
    ) -> EvidenceSource | None:
        title = item.get("title")
        if not title:
            return None
        work_type = item.get("type") or ""
        tier = _tier_from_title_and_type(title, work_type)
        if tier == "D":
            return None
        doi = item.get("doi")
        if doi and doi.startswith("https://doi.org/"):
            doi = doi.removeprefix("https://doi.org/")
        primary_location = item.get("primary_location") or {}
        journal = ((primary_location.get("source") or {}).get("display_name")) or (
            (item.get("host_venue") or {}).get("display_name")
        )
        is_open_access = bool((item.get("open_access") or {}).get("is_oa"))
        return EvidenceSource(
            title=title,
            journal=journal,
            year=item.get("publication_year"),
            doi=doi,
            pmid=None,
            tier=tier,
            access_depth="A" if is_open_access else ("B" if tier in ("A", "B") else "C"),
            clinical_domain=_domain_from_intent(request_data.intent),
            species=request_data.species,
            snippet=_reconstruct_abstract(item.get("abstract_inverted_index")),
            source_url=item.get("id"),
        )
