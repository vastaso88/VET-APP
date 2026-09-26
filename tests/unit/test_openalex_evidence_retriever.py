import json
from collections.abc import Callable

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.openalex_evidence_retriever import (
    OpenAlexEvidenceRetriever,
)


def _item(**overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "title": "Example feline behavior study",
        "type": "article",
        "publication_year": 2023,
        "doi": "https://doi.org/10.9999/example",
        "primary_location": {"source": {"display_name": "Journal of Feline Behavior"}},
        "open_access": {"is_oa": False},
        "id": "https://openalex.org/W123",
    }
    base.update(overrides)
    return base


def _fetcher_for(results: list[dict[str, object]]) -> Callable[[str], bytes]:
    def fetch(url: str) -> bytes:
        return json.dumps({"results": results}).encode("utf-8")

    return fetch


def test_maps_item_fields_into_evidence_source() -> None:
    retriever = OpenAlexEvidenceRetriever(fetcher=_fetcher_for([_item()]))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="anxiety", species="cat", intent="behavior_question")
    )

    assert len(sources) == 1
    source = sources[0]
    assert source.title == "Example feline behavior study"
    assert source.journal == "Journal of Feline Behavior"
    assert source.year == 2023
    assert source.doi == "10.9999/example"


def test_open_access_true_grants_access_depth_a() -> None:
    retriever = OpenAlexEvidenceRetriever(
        fetcher=_fetcher_for([_item(open_access={"is_oa": True})])
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="anxiety", species="cat", intent="behavior_question")
    )

    assert sources[0].access_depth == "A"


def test_excludes_retracted_publications() -> None:
    retriever = OpenAlexEvidenceRetriever(
        fetcher=_fetcher_for([_item(title="Retracted: example feline study")])
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="anxiety", species="cat", intent="behavior_question")
    )

    assert sources == []


def test_reconstructs_abstract_from_inverted_index() -> None:
    inverted_index = {"Cats": [0], "show": [1], "anxiety": [2], "signs": [3]}
    retriever = OpenAlexEvidenceRetriever(
        fetcher=_fetcher_for([_item(abstract_inverted_index=inverted_index)])
    )

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="anxiety", species="cat", intent="behavior_question")
    )

    assert sources[0].snippet == "Cats show anxiety signs"


def test_returns_empty_list_on_network_failure() -> None:
    def failing_fetch(url: str) -> bytes:
        raise OSError("network down")

    retriever = OpenAlexEvidenceRetriever(fetcher=failing_fetch)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="anxiety", species="cat", intent="behavior_question")
    )

    assert sources == []
