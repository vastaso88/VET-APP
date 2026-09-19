from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.domain.knowledge.models import EvidenceSource
from packages.infrastructure.llm.retrieval.intent_routed_evidence_retriever import (
    IntentRoutedEvidenceRetriever,
)


class _FakeRetriever:
    def __init__(self, sources: list[EvidenceSource]) -> None:
        self._sources = sources
        self.calls = 0

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.calls += 1
        return self._sources


def _source(title: str) -> EvidenceSource:
    return EvidenceSource(title=title, tier="B", access_depth="C")


def test_uses_the_override_retriever_for_a_matching_intent() -> None:
    default = _FakeRetriever([_source("From default")])
    husbandry = _FakeRetriever([_source("From husbandry catalog")])
    retriever = IntentRoutedEvidenceRetriever(
        default=default, overrides={"husbandry_question": husbandry}
    )

    results = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="uvb", species="reptile_amphibian", intent="husbandry_question"
        )
    )

    assert [source.title for source in results] == ["From husbandry catalog"]
    assert husbandry.calls == 1
    assert default.calls == 0


def test_falls_back_to_the_default_retriever_for_an_unmapped_intent() -> None:
    default = _FakeRetriever([_source("From default")])
    husbandry = _FakeRetriever([_source("From husbandry catalog")])
    retriever = IntentRoutedEvidenceRetriever(
        default=default, overrides={"husbandry_question": husbandry}
    )

    results = retriever.retrieve(
        EvidenceRetrievalRequest(query="tosse", species="dog", intent="clinical_question")
    )

    assert [source.title for source in results] == ["From default"]
    assert default.calls == 1
    assert husbandry.calls == 0
