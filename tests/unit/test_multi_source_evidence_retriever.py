from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.domain.knowledge.models import EvidenceSource
from packages.infrastructure.llm.retrieval.multi_source_evidence_retriever import (
    MultiSourceEvidenceRetriever,
)


class _FakeSource:
    def __init__(self, sources: list[EvidenceSource]) -> None:
        self._sources = sources
        self.calls = 0

    def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.calls += 1
        return self._sources


def _source(**overrides: object) -> EvidenceSource:
    base: dict[str, object] = dict(title="Example", tier="B", access_depth="C")
    base.update(overrides)
    return EvidenceSource.model_validate(base)


def test_combines_results_from_every_source() -> None:
    first = _FakeSource([_source(title="From source A", doi="10.1/a")])
    second = _FakeSource([_source(title="From source B", doi="10.1/b")])
    retriever = MultiSourceEvidenceRetriever([first, second])

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert {source.title for source in sources} == {"From source A", "From source B"}
    assert first.calls == 1
    assert second.calls == 1


def test_deduplicates_the_same_paper_found_by_two_sources() -> None:
    first = _FakeSource([_source(title="Same paper via source A", doi="10.1/shared")])
    second = _FakeSource([_source(title="Same paper via source B", doi="10.1/shared")])
    retriever = MultiSourceEvidenceRetriever([first, second])

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert len(sources) == 1
    assert sources[0].title == "Same paper via source A"


def test_a_failing_source_does_not_block_the_others() -> None:
    class BrokenSource:
        def retrieve(self, request_data: EvidenceRetrievalRequest) -> list[EvidenceSource]:
            return []

    working = _FakeSource([_source(title="Still found this one")])
    retriever = MultiSourceEvidenceRetriever([BrokenSource(), working])

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(query="cough", species="dog", intent="clinical_question")
    )

    assert len(sources) == 1


def test_trims_to_max_results_but_still_queries_every_source() -> None:
    first = _FakeSource(
        [_source(title="A1", doi="10.1/a1"), _source(title="A2", doi="10.1/a2")]
    )
    second = _FakeSource([_source(title="B1", doi="10.1/b1")])
    retriever = MultiSourceEvidenceRetriever([first, second])

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="cough", species="dog", intent="clinical_question", max_results=2
        )
    )

    assert len(sources) == 2
    # Real-world finding: a source queried first used to be able to
    # "starve" the others just by returning enough matches to fill
    # max_results, even when its matches were weaker than what a later
    # source would have found — every source must be queried regardless.
    assert second.calls == 1


def test_a_stronger_match_from_a_later_source_is_not_crowded_out_by_a_weaker_one() -> None:
    weak_first = _FakeSource(
        [
            _source(title="Weak C1", tier="C", doi="10.1/c1"),
            _source(title="Weak C2", tier="C", doi="10.1/c2"),
        ]
    )
    strong_second = _FakeSource([_source(title="Strong A1", tier="A", doi="10.1/a1")])
    retriever = MultiSourceEvidenceRetriever([weak_first, strong_second])

    sources = retriever.retrieve(
        EvidenceRetrievalRequest(
            query="cough", species="dog", intent="clinical_question", max_results=2
        )
    )

    assert "Strong A1" in {source.title for source in sources}
