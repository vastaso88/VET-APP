"""Retrieved sources must concern the question (2026-10-06 test round:
"perché il mio cane mastica le scarpe?" was answered citing papers on
arthritis, EEG and blood counts)."""

from test_chat_orchestrator import FakeLLMClient, ScriptedContentLLMClient

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.relevance import (
    is_relevant,
    relevant_sources,
    topic_terms,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

ARTHRITIS = EvidenceSource(
    title="Canine Osteoarthritis Management Guidelines",
    snippet="Multimodal management of osteoarthritis pain in dogs.",
    tier="A",
    clinical_domain="clinical",
    species="dog",
)
EEG = EvidenceSource(
    title="Electroencephalography in Dogs with Idiopathic Epilepsy",
    snippet="EEG findings in a cohort of epileptic dogs.",
    clinical_domain="clinical",
    species="dog",
)
CBC = EvidenceSource(
    title="Reference Intervals for the Canine Complete Blood Count",
    snippet="Hematology reference intervals for healthy adult dogs.",
    clinical_domain="clinical",
    species="dog",
)
CHEWING = EvidenceSource(
    title="Destructive Chewing in Puppies: Causes and Management",
    snippet="Teething, boredom and separation distress as drivers of chewing on household items.",
    clinical_domain="behavior",
    species="dog",
)


class ClinicalOnlyRetriever:
    """Returns clinical papers whatever the question, like a domain-level
    retriever does."""

    def __init__(self, *sources: EvidenceSource) -> None:
        self.sources = list(sources)
        self.requests: list[EvidenceRetrievalRequest] = []

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.requests.append(request)
        return list(self.sources)


def test_topic_terms_bridge_italian_to_the_english_of_the_literature() -> None:
    terms = topic_terms("perché il mio cane mastica le scarpe quando esco?")

    assert "chew" in terms and "masti" in terms and "scarp" in terms
    # Species words are not topics.
    assert "cane" not in terms


def test_unrelated_clinical_papers_are_not_relevant_to_a_behaviour_question() -> None:
    terms = topic_terms("perché il mio cane mastica le scarpe?")

    assert not is_relevant(ARTHRITIS, terms)
    assert not is_relevant(EEG, terms)
    assert not is_relevant(CBC, terms)
    assert is_relevant(CHEWING, terms)


def test_a_paper_on_the_right_topic_is_relevant_in_either_language() -> None:
    cough = EvidenceSource(title="Small Animal Coughing: Diagnostic Approach", species="dog")
    assert is_relevant(cough, topic_terms("il mio cane tossisce da due giorni"))
    assert is_relevant(cough, topic_terms("my dog is coughing"))
    assert not is_relevant(cough, topic_terms("quante volte al giorno deve mangiare?"))


def test_sharing_only_the_species_word_is_not_relevance() -> None:
    assert not is_relevant(ARTHRITIS, topic_terms("il cane sbadiglia spesso, è stressato?"))


def test_relevant_sources_keeps_order_and_drops_the_rest() -> None:
    kept = relevant_sources([ARTHRITIS, CHEWING, EEG], "perché mastica le scarpe?")

    assert kept == [CHEWING]


def test_the_chat_does_not_cite_unrelated_sources_for_a_behaviour_question() -> None:
    # A plain answer: with no source offered, a "[1]" marker would (rightly)
    # be rejected by the citation check, which is not what is under test.
    client = ScriptedContentLLMClient("A quattro mesi mastica per i denti che spuntano.")
    retriever = ClinicalOnlyRetriever(ARTHRITIS, EEG, CBC)
    orchestrator = ChatOrchestrator(client, retriever, NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="perché il mio cane mastica le scarpe quando usciamo di casa?",
            species="Cane",
            pet_name="Birba",
        )
    )

    assert retriever.requests, "retrieval still runs; relevance decides afterwards"
    assert result.sources == []
    assert result.state == ConversationState.NO_RELEVANT_SOURCES
    assert "Reference material" not in client.requests[-1].user_prompt
    assert "Osteoarthritis" not in client.requests[-1].user_prompt


def test_a_source_about_the_question_is_still_offered_and_the_state_says_so() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(
        client, ClinicalOnlyRetriever(ARTHRITIS, CHEWING, EEG), NoopPiiAnonymizer()
    )

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="perché il mio cane mastica le scarpe?", species="Cane", pet_name="Birba"
        )
    )

    assert [source.title for source in result.sources] == [CHEWING.title]
    assert result.state == ConversationState.ADEQUATE_EVIDENCE_FOUND
    assert "Destructive Chewing" in client.requests[-1].user_prompt


def test_the_curated_catalog_still_serves_questions_it_does_cover() -> None:
    client = FakeLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    result = orchestrator.answer(
        ChatOrchestratorInput(
            user_message="il mio cane tossisce da due giorni, cosa può essere?",
            species="dog",
            pet_name="Argo",
        )
    )

    assert any("Cough" in source.title for source in result.sources)
