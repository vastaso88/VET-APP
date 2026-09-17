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


def test_stops_once_max_results_is_reached() -> None:
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
    assert second.calls == 0
