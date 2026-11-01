"""Curated "understand the species" notes (repositioning, docs/product/11 §4 2.4)."""

from __future__ import annotations

import pytest

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.infrastructure.llm.retrieval.curated_awareness_evidence_retriever import (
    AWARENESS_CATALOG,
    CuratedAwarenessEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)

FAMILIES = ("dog", "cat", "small_mammal", "bird", "reptile_amphibian", "fish", "other")


def test_there_is_one_note_per_species_family_with_the_four_themes() -> None:
    assert sorted(source.species for source in AWARENESS_CATALOG) == sorted(FAMILIES)
    for source in AWARENESS_CATALOG:
        assert source.tier == "D" and source.access_depth == "D"
        assert source.clinical_domain == "behavior"
        assert "pending vet review" in source.title
        if source.species != "other":
            for theme in ("Ethology", "Needs", "Stress signs", "Common mistakes"):
                assert theme in (source.snippet or ""), (source.species, theme)


@pytest.mark.parametrize("family", FAMILIES)
def test_the_note_of_the_requested_family_is_served(family: str) -> None:
    results = CuratedAwarenessEvidenceRetriever().retrieve(
        EvidenceRetrievalRequest(
            query="perché lo fa", species=family, intent="behavior_question", max_results=3
        )
    )

    assert len(results) == 1
    assert results[0].species == family


def test_an_unknown_species_falls_back_to_the_general_note() -> None:
    results = CuratedAwarenessEvidenceRetriever().retrieve(
        EvidenceRetrievalRequest(
            query="perché lo fa", species="furetto", intent="behavior_question"
        )
    )

    assert [source.species for source in results] == ["other"]


def test_the_dog_note_never_explains_behaviour_as_dominance() -> None:
    dog = next(source for source in AWARENESS_CATALOG if source.species == "dog")

    assert "rejected by ESVCE and AVSAB" in (dog.snippet or "")
    assert "reward-based" in (dog.snippet or "")


def test_the_in_memory_backend_serves_the_notes_for_everyday_questions() -> None:
    results = InMemoryEvidenceRetriever().retrieve(
        EvidenceRetrievalRequest(
            query="perché il gatto impasta con le zampe?",
            species="cat",
            intent="everyday_question",
            max_results=5,
        )
    )

    assert any("understanding the cat" in source.title for source in results)
