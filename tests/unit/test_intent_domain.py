import json

import pytest

from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.crossref_evidence_retriever import (
    CrossrefEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.europe_pmc_evidence_retriever import (
    EuropePmcEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.intent_domain import domain_from_intent
from packages.infrastructure.llm.retrieval.openalex_evidence_retriever import (
    OpenAlexEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.pubmed_evidence_retriever import (
    PubMedEvidenceRetriever,
)

INTENT_DOMAINS = [
    ("clinical_question", "clinical"),
    ("nutrition_question", "nutrition"),
    ("behavior_question", "behavior"),
    ("preventive_care", "preventive"),
    ("anything_else", "general"),
    ("", "general"),
]


def _crossref_fetch(url: str) -> bytes:
    item = {
        "title": ["Example study"],
        "container-title": ["Journal"],
        "published": {"date-parts": [[2021, 5]]},
        "DOI": "10.5678/example",
        "URL": "https://doi.org/10.5678/example",
    }
    return json.dumps({"message": {"items": [item]}}).encode("utf-8")


def _europe_pmc_fetch(url: str) -> bytes:
    result = {
        "id": "12345",
        "source": "MED",
        "pmid": "12345",
        "doi": "10.1234/example",
        "title": "Example Study",
        "journalInfo": {"journal": {"title": "Journal"}},
        "pubYear": "2022",
        "pubTypeList": {"pubType": ["Journal Article"]},
        "abstractText": "Abstract.",
    }
    return json.dumps({"resultList": {"result": [result]}}).encode("utf-8")


def _openalex_fetch(url: str) -> bytes:
    item = {
        "title": "Example study",
        "type": "article",
        "publication_year": 2023,
        "doi": "https://doi.org/10.9999/example",
        "primary_location": {"source": {"display_name": "Journal"}},
        "open_access": {"is_oa": False},
        "id": "https://openalex.org/W123",
    }
    return json.dumps({"results": [item]}).encode("utf-8")


def _pubmed_fetch(url: str) -> bytes:
    if "esearch.fcgi" in url:
        return json.dumps({"esearchresult": {"idlist": ["111"]}}).encode("utf-8")
    summary = {
        "title": "Example Study",
        "source": "J Vet Med",
        "pubdate": "2022 Jun",
        "pubtype": ["Journal Article"],
        "articleids": [{"idtype": "doi", "value": "10.1234/example"}],
    }
    return json.dumps({"result": {"uids": ["111"], "111": summary}}).encode("utf-8")


def _adapters() -> list[tuple[str, EvidenceRetriever]]:
    return [
        ("crossref", CrossrefEvidenceRetriever(fetcher=_crossref_fetch)),
        ("europe_pmc", EuropePmcEvidenceRetriever(fetcher=_europe_pmc_fetch)),
        ("openalex", OpenAlexEvidenceRetriever(fetcher=_openalex_fetch)),
        ("pubmed", PubMedEvidenceRetriever(fetcher=_pubmed_fetch)),
    ]


@pytest.mark.parametrize(("intent", "expected"), INTENT_DOMAINS)
def test_shared_mapping(intent: str, expected: str) -> None:
    assert domain_from_intent(intent) == expected


@pytest.mark.parametrize(("intent", "expected"), INTENT_DOMAINS)
@pytest.mark.parametrize("name", ["crossref", "europe_pmc", "openalex", "pubmed"])
def test_every_adapter_labels_sources_with_the_shared_mapping(
    name: str, intent: str, expected: str
) -> None:
    retriever = dict(_adapters())[name]

    sources = retriever.retrieve(EvidenceRetrievalRequest(query="q", species="dog", intent=intent))

    assert len(sources) == 1
    assert sources[0].clinical_domain == expected
