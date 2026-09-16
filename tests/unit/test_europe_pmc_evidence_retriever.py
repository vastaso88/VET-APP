import json

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.europe_pmc_evidence_retriever import (
    EuropePmcEvidenceRetriever,
)


def _fetcher_for(payload: dict, *, captured_urls: list[str] | None = None):
    def fetch(url: str) -> bytes:
        if captured_urls is not None:
            captured_urls.append(url)
        return json.dumps(payload).encode("utf-8")

    return fetch


def _result(**overrides) -> dict:
    base = {
        "id": "12345",
        "source": "MED",
        "pmid": "12345",
        "doi": "10.1234/example",
        "title": "Example Study",
        "journalInfo": {"journal": {"title": "Journal of Examples"}},
        "pubYear": "2022",
        "pubTypeList": {"pubType": ["Journal Article"]},
        "abstractText": "An informative abstract.",
    }
    base.update(overrides)
    return base


def test_maps_result_fields_into_evidence_source() -> None:
    payload = {"resultList": {"result": [_result()]}}
    retriever = EuropePmcEvidenceRetriever(fetcher=_fetcher_for(payload))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="il cane tossisce", species="dog", intent="clinical_question"
        )
    )

    assert len(sources) == 1
    source = sources[0]
    assert source.title == "Example Study"
    assert source.journal == "Journal of Examples"
    assert source.year == 2022
    assert source.doi == "10.1234/example"
    assert source.pmid == "12345"
    assert source.species == "dog"
    assert source.clinical_domain == "clinical"
    assert source.snippet == "An informative abstract."
    assert source.source_url == "https://europepmc.org/article/MED/12345"


def test_tier_reflects_publication_type() -> None:
    payload = {
        "resultList": {
            "result": [
                _result(id="1", pmid="1", doi="10.1/a", pubTypeList={"pubType": ["Guideline"]}),
                _result(
                    id="2",
                    pmid="2",
                    doi="10.1/b",
                    pubTypeList={"pubType": ["Systematic Review"]},
                ),
                _result(
                    id="3",
                    pmid="3",
                    doi="10.1/c",
                    pubTypeList={"pubType": ["Randomized Controlled Trial"]},
                ),
                _result(id="4", pmid="4", doi="10.1/d", pubTypeList={"pubType": ["Case Reports"]}),
            ]
        }
    }
    retriever = EuropePmcEvidenceRetriever(fetcher=_fetcher_for(payload))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="cough", species="dog", intent="clinical_question", max_results=4
        )
    )

    tiers = {source.doi: source.tier for source in sources}
    assert tiers["10.1/a"] == "A"
    assert tiers["10.1/b"] == "A"
    assert tiers["10.1/c"] == "B"
    assert tiers["10.1/d"] == "C"


def test_retracted_publications_are_never_returned() -> None:
    payload = {
        "resultList": {
            "result": [_result(pubTypeList={"pubType": ["Retracted Publication"]})]
        }
    }
    retriever = EuropePmcEvidenceRetriever(fetcher=_fetcher_for(payload))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []


def test_deduplicates_by_doi() -> None:
    payload = {
        "resultList": {
            "result": [
                _result(id="1"),
                _result(id="2"),  # same doi/pmid as the first
            ]
        }
    }
    retriever = EuropePmcEvidenceRetriever(fetcher=_fetcher_for(payload))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert len(sources) == 1


def test_respects_max_results() -> None:
    payload = {
        "resultList": {
            "result": [
                _result(id=str(i), pmid=str(i), doi=f"10.1/{i}") for i in range(10)
            ]
        }
    }
    retriever = EuropePmcEvidenceRetriever(fetcher=_fetcher_for(payload))

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="cough", species="dog", intent="clinical_question", max_results=3
        )
    )

    assert len(sources) == 3


def test_network_failure_returns_empty_list_instead_of_raising() -> None:
    def failing_fetcher(url: str) -> bytes:
        raise TimeoutError("simulated network failure")

    retriever = EuropePmcEvidenceRetriever(fetcher=failing_fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []


def test_malformed_response_returns_empty_list_instead_of_raising() -> None:
    retriever = EuropePmcEvidenceRetriever(fetcher=lambda url: b"not json")

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []


def test_query_translates_known_italian_terms_to_english() -> None:
    captured_urls: list[str] = []
    payload = {"resultList": {"result": []}}
    retriever = EuropePmcEvidenceRetriever(
        fetcher=_fetcher_for(payload, captured_urls=captured_urls)
    )

    retriever.retrieve(
        EvidenceRetrievalRequest(
            query="Il mio cane tossisce da due giorni", species="dog", intent="clinical_question"
        )
    )

    assert captured_urls
    assert "cough" in captured_urls[0]
    assert "canine" in captured_urls[0] or "dog" in captured_urls[0]


def test_query_falls_back_to_intent_terms_when_no_keyword_matches() -> None:
    captured_urls: list[str] = []
    payload = {"resultList": {"result": []}}
    retriever = EuropePmcEvidenceRetriever(
        fetcher=_fetcher_for(payload, captured_urls=captured_urls)
    )

    retriever.retrieve(
        EvidenceRetrievalRequest(
            query="qualcosa di strano oggi", species="cat", intent="nutrition_question"
        )
    )

    assert captured_urls
    assert "nutrition" in captured_urls[0]
