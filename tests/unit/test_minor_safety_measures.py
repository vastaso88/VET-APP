"""Measures for 14-17 accounts (2026-11-16, docs/compliance/08 point 57;
Anthropic's rules for products minors may use, docs/compliance/14 §1).

1. Words about ending one's life or self-harm: a fixed, warm reply with the
   official helplines, before any other check and with no model call.
2. The harmful-content rule in the shared prompt, and the teenager note for a
   declared 14-17 account (``account_age``).
"""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest
from llm_fakes import RecordingLLMClient
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.age.models import AccountAge
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.safety.harmful_requests import (
    SELF_HARM_TEXTS,
    UNDER_18_HELP_LINE,
    expresses_hopelessness,
    expresses_self_harm,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def _ask(
    message: str,
    *,
    client: RecordingLLMClient | ScriptedContentLLMClient | None = None,
    language: str = "it",
    owner_is_minor: bool = False,
    **fields: object,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient | ScriptedContentLLMClient]:
    llm = client or RecordingLLMClient()
    result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Argo",
            language=language,
            owner_is_minor=owner_is_minor,
            **fields,  # type: ignore[arg-type]
        )
    )
    return result, llm


# --- 1. self-harm ---------------------------------------------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "da quando Argo è morto vorrei farla finita",
        "non voglio più vivere",
        "a volte penso al suicidio",
        "voglio farmi del male",
        "I want to kill myself",
        "I've been self-harming again",
        "quiero morir, ya no puedo",
        "ich will nicht mehr leben",
        "j'ai envie de me tuer",
    ],
)
def test_words_of_self_harm_are_recognised_in_five_languages(message: str) -> None:
    assert expresses_self_harm(message)


@pytest.mark.parametrize(
    "message",
    [
        "il cane potrebbe farmi del male quando mangia?",
        "mi sono fatto male alla mano durante la passeggiata",
        "voglio farla finita con le pulci",
        "my dog could hurt me when I take his bone",
        "il cane mi fa morire dal ridere",
        "non ha senso che abbai così tanto, no?",
    ],
)
def test_ordinary_sentences_are_not_self_harm(message: str) -> None:
    assert not expresses_self_harm(message)


def test_self_harm_gets_the_fixed_reply_with_helplines_and_no_model_call() -> None:
    result, client = _ask("Argo è morto e non voglio più vivere")

    assert client.requests == []  # the words never leave for a provider
    assert result.ai_generated is False
    assert result.model == "self-harm-guard"
    assert result.answer == SELF_HARM_TEXTS["it"]
    assert "02 2327 2327" in result.answer and "112" in result.answer
    assert "19696" not in result.answer  # adults get the adults' line


def test_self_harm_comes_before_a_pending_clarifying_question() -> None:
    result, client = _ask(
        "non importa, voglio morire",
        awaiting_safety_clarification=True,
        safety_clarification_category="bleeding",
    )
    assert client.requests == []
    assert result.model == "self-harm-guard"


def test_a_declared_minor_also_gets_the_under_18_line() -> None:
    result, _ = _ask("vorrei farla finita", owner_is_minor=True)
    assert result.answer.endswith(UNDER_18_HELP_LINE["it"])
    assert "19696" in result.answer


def test_a_child_writing_gets_the_under_18_line_without_a_declared_age() -> None:
    result, _ = _ask("ho 13 anni e voglio morire")
    assert "19696" in result.answer


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_the_self_harm_reply_exists_in_every_language_with_the_same_numbers(
    language: str,
) -> None:
    text = SELF_HARM_TEXTS[language]
    assert "02 2327 2327" in text and "112" in text
    assert "19696" in UNDER_18_HELP_LINE[language]
    assert "{" not in text  # no placeholder left unfilled


def test_no_weight_suggestion_is_added_to_the_self_harm_reply() -> None:
    result, _ = _ask("non mangio più niente, voglio morire")
    assert result.answer == SELF_HARM_TEXTS["it"]


# --- strong distress: the opening line now carries the helpline --------------------------


def test_distress_without_self_harm_keeps_the_model_after_the_opening_with_the_helpline() -> None:
    grief = "Argo è morto ieri e niente ha più senso, nemmeno alzarmi"
    assert expresses_hopelessness(grief) and not expresses_self_harm(grief)

    result, client = _ask(grief, client=ScriptedContentLLMClient("Mi dispiace tanto per Argo."))

    assert result.answer.startswith("Quello che scrivi lo prendo sul serio.")
    assert "02 2327 2327" in result.answer
    prompt = client.requests[-1].system_prompt
    assert "never add another phone number" in prompt
    assert "no advice on the person's own health" in prompt


def test_distress_of_a_declared_minor_adds_the_under_18_line_to_the_opening() -> None:
    result, _ = _ask(
        "Argo è morto e niente ha più senso",
        owner_is_minor=True,
        client=ScriptedContentLLMClient("Mi dispiace tanto per Argo."),
    )
    assert "19696" in result.answer.split("Mi dispiace tanto")[0]


# --- 2. the prompt ---------------------------------------------------------------------


def test_the_shared_prompt_carries_the_harmful_content_rule_for_everyone() -> None:
    prompt = build_system_prompt(RequestKind.DIRECT, may_ask=False, has_reference_material=False)
    assert "Never sexual content, never help to hurt a person or an animal" in prompt


def test_the_teenager_note_goes_only_to_a_declared_minor() -> None:
    _, adult = _ask("come insegno ad Argo a non tirare al guinzaglio?")
    _, teen = _ask("come insegno ad Argo a non tirare al guinzaglio?", owner_is_minor=True)

    assert "THE ACCOUNT BELONGS TO A TEENAGER" not in adult.requests[-1].system_prompt
    assert "THE ACCOUNT BELONGS TO A TEENAGER" in teen.requests[-1].system_prompt


def test_the_send_service_reads_the_declared_age_on_every_turn() -> None:
    today = datetime.now(UTC).date()
    ages = InMemoryAccountAgeRepository()
    ages.create(
        AccountAge(
            owner_id="teen-1",
            birth_date=date(today.year - 15, 1, 1),
            declared_at=datetime.now(UTC),
        )
    )
    ages.create(
        AccountAge(
            owner_id="adult-1",
            birth_date=date(today.year - 40, 1, 1),
            declared_at=datetime.now(UTC),
        )
    )
    pets = InMemoryPetProfileRepository()
    for owner in ("teen-1", "adult-1"):
        pets.save(PetProfile(id=f"pet-{owner}", owner_id=owner, name="Argo", species="Cane"))
    client = RecordingLLMClient()
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        account_age_repository=ages,
    )

    for owner in ("teen-1", "adult-1"):
        service.execute(
            SendChatMessageInput(
                owner_id=owner,
                pet_id=f"pet-{owner}",
                user_message="come insegno ad Argo a non tirare al guinzaglio?",
            )
        )

    teen_prompt, adult_prompt = (r.system_prompt for r in client.requests[-2:])
    assert "THE ACCOUNT BELONGS TO A TEENAGER" in teen_prompt
    assert "THE ACCOUNT BELONGS TO A TEENAGER" not in adult_prompt
