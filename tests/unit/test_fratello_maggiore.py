"""Plan "fratello maggiore", stage 3 (2026-11-10): the more capable model
("strong" class, Claude Sonnet) writes the free part of urgencies and the
next health answer after the owner was not helped, within the plan's cap;
"Non mi ha aiutato" route; health_answer on the reply; concise answers."""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.ports.llm_client import LLMGenerationRequest
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.mark_not_helpful import (
    MarkNotHelpfulInput,
    MarkNotHelpfulService,
)
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.conversation.request_kind import RequestKind
from packages.infrastructure.llm.providers.anthropic_llm_client import AnthropicLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryLlmUsageRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ValidationError

STRONG = "claude-sonnet-5-5"
HEALTH_Q = "Toby ha la diarrea da due giorni, cosa faccio?"
EMERGENCY = "Toby ha appena mangiato il topicida e adesso trema e sbava"


def _orchestrator(
    llm: RecordingLLMClient,
    *,
    strong: str | None = STRONG,
    budget: LlmBudget | None = None,
    urgent_timeout: int = 0,
) -> ChatOrchestrator:
    return ChatOrchestrator(
        llm,
        InMemoryEvidenceRetriever(),
        NoopPiiAnonymizer(),
        strong_model=strong,
        usage_budget=budget,
        answer_models=["main"],
        urgent_answer_timeout_seconds=urgent_timeout,
    )


def _ask(
    orchestrator: ChatOrchestrator,
    message: str,
    *,
    history: tuple[tuple[str, str, bool], ...] = (),
    escalate: bool = False,
    sonnet_limit: int | None = None,
) -> ChatOrchestratorResult:
    return orchestrator.answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Toby",
            owner_id="owner-1",
            conversation_history=[
                ChatMessage(role=role, content=text, health_answer=health or None)
                for role, text, health in history
            ],
            escalate_health=escalate,
            sonnet_daily_limit=sonnet_limit,
        )
    )


def _classes(llm: RecordingLLMClient, purpose: str = "answer") -> list[str]:
    return [request.model_class for request in llm.requests_for(purpose)]


# --- the health answer and its flag ---------------------------------------------------


def test_a_health_answer_is_flagged_for_the_button_and_written_by_the_ordinary_model() -> None:
    llm = RecordingLLMClient()

    result = _ask(_orchestrator(llm), HEALTH_Q)

    assert result.health_answer is True
    assert result.escalated is False
    assert _classes(llm) == ["main"]


def test_management_is_not_a_health_answer() -> None:
    result = _ask(_orchestrator(RecordingLLMClient()), "come insegno a Toby a stare seduto?")

    assert result.health_answer is False


# --- the second try --------------------------------------------------------------------


def test_after_the_button_the_next_health_answer_is_the_strong_models() -> None:
    llm = RecordingLLMClient()

    result = _ask(_orchestrator(llm), HEALTH_Q, escalate=True)

    assert _classes(llm) == ["strong"]
    assert result.escalated is True and result.health_answer is True
    (request,) = llm.requests_for("answer")
    assert "SECOND TRY" in request.system_prompt


@pytest.mark.parametrize(
    "follow_up",
    [
        "non hai capito, ha la diarrea da due giorni!",
        "this doesn't help",
        "Toby ha ancora la diarrea da due giorni: cosa faccio?",
    ],
)
def test_dissatisfaction_or_the_same_question_again_brings_the_strong_model(
    follow_up: str,
) -> None:
    llm = RecordingLLMClient()

    _ask(
        _orchestrator(llm),
        follow_up,
        history=(("user", HEALTH_Q, False), ("assistant", "Prima risposta.", True)),
    )

    assert _classes(llm) == ["strong"]


def test_a_new_question_after_a_health_answer_stays_with_the_ordinary_model() -> None:
    llm = RecordingLLMClient()

    _ask(
        _orchestrator(llm),
        "e ogni quanto va fatto il vaccino della rabbia?",
        history=(("user", HEALTH_Q, False), ("assistant", "Prima risposta.", True)),
    )

    assert _classes(llm) == ["main"]


def test_with_the_strong_model_off_the_second_try_is_the_ordinary_models() -> None:
    llm = RecordingLLMClient()

    result = _ask(_orchestrator(llm, strong=None), HEALTH_Q, escalate=True)

    assert _classes(llm) == ["main"]
    assert result.escalated is False
    (request,) = llm.requests_for("answer")
    assert "SECOND TRY" in request.system_prompt  # still a second, more careful try


def test_the_plans_cap_reached_means_the_ordinary_model_without_a_word() -> None:
    budget = LlmBudget(
        InMemoryLlmUsageRepository(),
        budgets={"main": 10_000_000, STRONG: 10_000_000},
        default_budget=10_000_000,
    )
    llm = RecordingLLMClient()
    orchestrator = _orchestrator(llm, budget=budget)

    first = _ask(orchestrator, HEALTH_Q, escalate=True, sonnet_limit=1)
    second = _ask(orchestrator, HEALTH_Q, escalate=True, sonnet_limit=1)

    assert first.escalated is True
    assert second.escalated is False
    assert _classes(llm) == ["strong", "main"]
    assert "Sonnet" not in second.answer and "limite" not in second.answer


# --- urgencies -----------------------------------------------------------------------


def test_the_strong_model_writes_the_free_part_of_an_urgency() -> None:
    llm = RecordingLLMClient(
        by_purpose={
            "urgent_answer": "Parti adesso verso il pronto soccorso veterinario e porta la "
            "confezione del topicida: non dargli niente e non farlo vomitare."
        }
    )

    _ask(_orchestrator(llm, urgent_timeout=12), EMERGENCY)

    assert _classes(llm, "urgent_answer") == ["strong"]


def test_without_the_strong_model_the_urgency_is_written_as_before() -> None:
    llm = RecordingLLMClient(by_purpose={"urgent_answer": "Parti adesso. " * 10})

    _ask(_orchestrator(llm, strong=None, urgent_timeout=12), EMERGENCY)

    assert _classes(llm, "urgent_answer") == ["main"]


# --- the Anthropic client: same payload, other model -----------------------------------------


def test_the_strong_class_reaches_the_strong_model_through_the_same_payload() -> None:
    settings = Settings().model_copy(
        update={
            "llm_provider": "anthropic",
            "anthropic_api_key": "test-key",
            "anthropic_model_strong": STRONG,
        }
    )
    client = AnthropicLLMClient(settings, client=SimpleNamespace())
    main = LLMGenerationRequest(system_prompt="s", user_prompt="u")
    strong = main.model_copy(update={"model_class": "strong"})

    main_body: dict[str, Any] = client.payload(main, structured=True)
    strong_body: dict[str, Any] = client.payload(strong, structured=True)

    assert main_body["model"] == "claude-haiku-5-5"
    assert strong_body["model"] == STRONG
    # Everything else identical: same anonymised input, same caching, same
    # effort, and (once the activation branch is merged) the same region.
    assert {k: v for k, v in strong_body.items() if k != "model"} == {
        k: v for k, v in main_body.items() if k != "model"
    }


def test_sonnet_is_off_by_default() -> None:
    assert Settings().sonnet_escalation_enabled is False


# --- the button ----------------------------------------------------------------------


def _conversation(repository: InMemoryConversationRepository) -> tuple[Conversation, str, str]:
    health = ChatMessage(role="assistant", content="Risposta di salute.", health_answer=True)
    other = ChatMessage(role="assistant", content="Risposta di gestione.")
    conversation = repository.save(
        Conversation(
            owner_id="owner-1",
            pet_id="pet-1",
            title="Diarrea",
            messages=[ChatMessage(role="user", content=HEALTH_Q), health, other],
        )
    )
    return conversation, health.id, other.id


def test_not_helpful_marks_the_message_and_arms_the_next_health_answer() -> None:
    repository = InMemoryConversationRepository()
    conversation, health_id, _ = _conversation(repository)
    service = MarkNotHelpfulService(repository)

    service.execute(
        MarkNotHelpfulInput(
            owner_id="owner-1", conversation_id=conversation.id, message_id=health_id
        )
    )
    service.execute(  # idempotent
        MarkNotHelpfulInput(
            owner_id="owner-1", conversation_id=conversation.id, message_id=health_id
        )
    )

    stored = repository.get(conversation.id)
    assert stored is not None
    assert stored.escalate_next_health is True
    assert next(m for m in stored.messages if m.id == health_id).not_helpful is True
    assert "escalate_next_health" not in stored.public_dump()


def test_not_helpful_is_owner_scoped_and_only_for_health_answers() -> None:
    repository = InMemoryConversationRepository()
    conversation, health_id, other_id = _conversation(repository)
    service = MarkNotHelpfulService(repository)

    with pytest.raises(ValidationError, match="not found"):  # user B
        service.execute(
            MarkNotHelpfulInput(
                owner_id="owner-2", conversation_id=conversation.id, message_id=health_id
            )
        )
    for message_id in (other_id, conversation.messages[0].id, "missing"):
        with pytest.raises(ValidationError, match="not found"):
            service.execute(
                MarkNotHelpfulInput(
                    owner_id="owner-1", conversation_id=conversation.id, message_id=message_id
                )
            )


# --- concise answers -----------------------------------------------------------------


def test_the_answers_are_asked_to_be_concise_without_cutting_safety() -> None:
    for kind in (RequestKind.DIRECT, RequestKind.SYMPTOM):
        prompt = build_system_prompt(kind, may_ask=True, has_reference_material=False)
        assert "120-180 words" in prompt
        assert "never shorten a safety warning" in prompt
