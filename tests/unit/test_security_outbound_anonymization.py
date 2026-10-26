"""Security regression (audit 2026-10-26, finding LLM-F2): every prompt
that leaves the system for the model provider is anonymized first, the
literature-search keyword helper included."""

from __future__ import annotations

from typing import Any

from llm_fakes import RecordingLLMClient

from packages.core.application.ports.evidence_retriever import EvidenceRetrievalRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.domain.knowledge.models import EvidenceSource
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer

KEYWORDS = '{"keywords": ["dog", "lameness"]}'


class _Retriever:
    def __init__(self) -> None:
        self.requests: list[EvidenceRetrievalRequest] = []

    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        self.requests.append(request)
        return []


def test_the_keyword_helper_never_sees_the_owners_contact_details() -> None:
    client = RecordingLLMClient(by_purpose={"evidence_query": KEYWORDS})
    orchestrator = ChatOrchestrator(
        client,
        _Retriever(),
        RuleBasedPiiAnonymizer(),
        evidence_query_normalizer=EvidenceQueryNormalizer(client),
    )

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message=(
                "Rex zoppica da due giorni dopo le passeggiate. Scrivetemi a "
                "mario.rossi@example.com o al 333 1234567, sono Mario Rossi"
            ),
            species="Cane",
            pet_name="Rex",
            owner_names=["Mario Rossi"],
        )
    )

    outbound: list[Any] = [r for r in client.requests if r.purpose == "evidence_query"]
    assert outbound, "the keyword helper was expected to run for a clinical question"
    for request in outbound:
        assert "mario.rossi@example.com" not in request.user_prompt
        assert "333 1234567" not in request.user_prompt
        assert "Mario Rossi" not in request.user_prompt
    for request in client.requests:
        assert "mario.rossi@example.com" not in request.user_prompt
