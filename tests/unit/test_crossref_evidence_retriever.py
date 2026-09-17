import json
from collections.abc import Callable

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.crossref_evidence_retriever import (
    CrossrefEvidenceRetriever,
)


def _item(**overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "title": ["Example canine nutrition study"],
        "container-title": ["Journal of Veterinary Nutrition"],
        "published": {"date-parts": [[2021, 5]]},
        "DOI": "10.5678/example",
        "URL": "https://doi.org/10.5678/example",
    }
    base.update(overrides)
    return base


def _fetcher_for(items: list[dict[str, object]]) -> Callable[[str], bytes]:
    def fetch(url: str) -> bytes:
        return json.dumps({"message": {"items": items}}).encode("utf-8")

    return fetch


def test_maps_item_fields_into_evidence_source() -> None:
    retriever = CrossrefEvidenceRetriever(fetcher=_fetcher_for([_item()]))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="diet", species="dog", intent="nutrition_question")
    )

    assert len(sources) == 1
    source = sources[0]
    assert source.title == "Example canine nutrition study"
    assert source.journal == "Journal of Veterinary Nutrition"
    assert source.year == 2021
    assert source.doi == "10.5678/example"
    assert source.pmid is None


def test_excludes_retracted_publications() -> None:
    retriever = CrossrefEvidenceRetriever(
        fetcher=_fetcher_for([_item(title=["Retracted: example canine study"])])
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="diet", species="dog", intent="nutrition_question")
    )

    assert sources == []


def test_deduplicates_by_doi() -> None:
    retriever = CrossrefEvidenceRetriever(
        fetcher=_fetcher_for([_item(), _item(title=["Different title, same DOI"])])
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="diet", species="dog", intent="nutrition_question")
    )

    assert len(sources) == 1


def test_open_license_grants_access_depth_a() -> None:
    retriever = CrossrefEvidenceRetriever(
        fetcher=_fetcher_for(
            [_item(license=[{"URL": "https://creativecommons.org/licenses/by/4.0"}])]
        )
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="diet", species="dog", intent="nutrition_question")
    )

    assert sources[0].access_depth == "A"


def test_returns_empty_list_on_network_failure() -> None:
    def failing_fetch(url: str) -> bytes:
        raise OSError("network down")

    retriever = CrossrefEvidenceRetriever(fetcher=failing_fetch)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="diet", species="dog", intent="nutrition_question")
    )

    assert sources == []
