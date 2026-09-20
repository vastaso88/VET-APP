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


def test_includes_a_reptile_enclosure_size_entry() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="dimensioni terrario geco",
            species="reptile_amphibian",
            intent="husbandry_question",
            max_results=10,
        )
    )

    assert any("enclosure size" in (source.title or "") for source in results)


def test_includes_an_aquarium_size_entry_covering_goldfish() -> None:
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="litri acquario pesci rossi", species="fish", intent="husbandry_question"
        )
    )

    assert any("goldfish" in (source.snippet or "") for source in results)


def test_aquarium_size_note_warns_against_linear_stocking_multiplication() -> None:
    # Real-world finding: asked for tank size for two goldfish, the
    # synthesizer doubled the single-fish minimum from this note — a
    # plausible-looking but unsupported extrapolation. The source itself
    # should make explicit that group stocking isn't simply additive, so
    # the model has a grounded reason not to do that regardless of prompt
    # wording alone.
    retriever = CuratedHusbandryEvidenceRetriever()

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="litri acquario pesci rossi", species="fish", intent="husbandry_question"
        )
    )

    size_note = next(source for source in results if "goldfish" in (source.snippet or ""))
    assert "does not scale by simply multiplying" in size_note.snippet


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
