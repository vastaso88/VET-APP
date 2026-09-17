import json
from collections.abc import Callable

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.pubmed_evidence_retriever import PubMedEvidenceRetriever


def _summary(pmid: str, **overrides: object) -> dict[str, object]:
    base: dict[str, object] = {
        "title": "Example Canine Study",
        "source": "J Vet Med",
        "pubdate": "2022 Jun",
        "pubtype": ["Journal Article"],
        "articleids": [{"idtype": "doi", "value": "10.1234/example"}],
    }
    base.update(overrides)
    return base


def _fetcher_for(
    idlist: list[str], summaries: dict[str, dict[str, object]]
) -> Callable[[str], bytes]:
    def fetch(url: str) -> bytes:
        if "esearch.fcgi" in url:
            return json.dumps({"esearchresult": {"idlist": idlist}}).encode("utf-8")
        payload = {"result": {"uids": idlist, **summaries}}
        return json.dumps(payload).encode("utf-8")

    return fetch


def test_maps_summary_fields_into_evidence_source() -> None:
    fetcher = _fetcher_for(["111"], {"111": _summary("111")})
    retriever = PubMedEvidenceRetriever(fetcher=fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert len(sources) == 1
    source = sources[0]
    assert source.title == "Example Canine Study"
    assert source.journal == "J Vet Med"
    assert source.year == 2022
    assert source.doi == "10.1234/example"
    assert source.pmid == "111"
    assert source.source_url == "https://pubmed.ncbi.nlm.nih.gov/111/"


def test_excludes_retracted_publications() -> None:
    fetcher = _fetcher_for(
        ["111"], {"111": _summary("111", pubtype=["Journal Article", "Retracted Publication"])}
    )
    retriever = PubMedEvidenceRetriever(fetcher=fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []


def test_deduplicates_by_doi() -> None:
    fetcher = _fetcher_for(
        ["111", "222"],
        {
            "111": _summary("111"),
            "222": _summary("222", title="Same paper, different PMID entry"),
        },
    )
    retriever = PubMedEvidenceRetriever(fetcher=fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert len(sources) == 1


def test_classifies_systematic_review_as_tier_a() -> None:
    fetcher = _fetcher_for(
        ["111"], {"111": _summary("111", pubtype=["Systematic Review"])}
    )
    retriever = PubMedEvidenceRetriever(fetcher=fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources[0].tier == "A"


def test_returns_empty_list_on_network_failure() -> None:
    def failing_fetch(url: str) -> bytes:
        raise OSError("network down")

    retriever = PubMedEvidenceRetriever(fetcher=failing_fetch)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []


def test_returns_empty_list_when_search_finds_nothing() -> None:
    fetcher = _fetcher_for([], {})
    retriever = PubMedEvidenceRetriever(fetcher=fetcher)

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert sources == []
