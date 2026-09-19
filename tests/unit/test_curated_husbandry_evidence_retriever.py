from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.curated_husbandry_evidence_retriever import (
    CuratedHusbandryEvidenceRetriever,
)


def test_returns_husbandry_sources_matching_the_requested_species() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="uvb geco", species="reptile_amphibian", intent="husbandry_question"
        )
    )

    assert results
    assert all(source.species == "reptile_amphibian" for source in results)
    assert all(source.clinical_domain == "husbandry" for source in results)


def test_does_not_return_sources_for_an_unrelated_species() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(query="qualsiasi cosa", species="dog", intent="husbandry_question")
    )

    assert results == []


def test_returns_bird_enrichment_sources_for_bird_species() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="gabbia pappagallo", species="bird", intent="husbandry_question"
        )
    )

    assert results
    assert all(source.species == "bird" for source in results)


def test_respects_max_results() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="uvb", species="reptile_amphibian", intent="husbandry_question", max_results=1
        )
    )

    assert len(results) == 1
