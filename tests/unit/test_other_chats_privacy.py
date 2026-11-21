"""Normativa's checks on the lines of other chats (plan 08, v2, 21/11/2026) before v2 is
switched on: (a) another owner and another animal are never selected; (b) the 300-character
cut and the limits of 2 conversations x (first owner line + last 2) x 72 hours; (c) a
deleted conversation is not selectable (deletion is physical:
SupabaseConversationRepository.delete removes the row);
(d) none of their text reaches the logs. Model: tests/unit/test_security_ownership.py."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.delete_conversation import (
    DeleteConversationInput,
    DeleteConversationService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

NOW = datetime.now(UTC)


def _pets() -> InMemoryPetProfileRepository:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-a1", owner_id="owner-a", name="Cicci", species="Uccelli"))
    pets.save(PetProfile(id="pet-a2", owner_id="owner-a", name="Rex", species="Cane"))
    pets.save(PetProfile(id="pet-b1", owner_id="owner-b", name="Luna", species="Gatto"))
    return pets


def _chat(owner: str, pet: str, *texts: str, hours_ago: float = 1.0) -> Conversation:
    """A conversation whose messages alternate user/assistant, one minute apart."""
    start = NOW - timedelta(hours=hours_ago)
    return Conversation(
        owner_id=owner,
        pet_id=pet,
        title="x",
        messages=[
            ChatMessage(
                role="user" if i % 2 == 0 else "assistant",
                content=text,
                created_at=start + timedelta(minutes=i),
            )
            for i, text in enumerate(texts)
        ],
    )


def _ask(
    repo: InMemoryConversationRepository, owner: str, pet: str, message: str = "che miglio?"
) -> str:
    """The prompt the model received for a new chat of `owner` on `pet` (v2 on)."""
    llm = RecordingLLMClient("Risposta di prova, concreta e breve.")
    orchestrator = ChatOrchestrator(
        llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=True
    )
    SendChatMessageService(repo, orchestrator, _pets(), recent_other_chats=True).execute(
        SendChatMessageInput(owner_id=owner, pet_id=pet, user_message=message)
    )
    (request,) = llm.requests_for("answer")
    return request.user_prompt


# --- (a) user B, another animal --------------------------------------------------------------


def test_user_b_never_sees_user_a_chats() -> None:
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a1", "SEGRETO-A feci verdi", "Vai adesso."))

    prompt = _ask(repo, "owner-b", "pet-b1")

    assert "SEGRETO-A" not in prompt


def test_a_chat_of_another_owner_on_the_same_pet_id_is_never_selected() -> None:
    # Even a record pointing at A's pet but owned by B (data error or tampering) stays out.
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-b", "pet-a1", "SEGRETO-B intruso", "ok"))

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert "SEGRETO-B" not in prompt


def test_another_animal_of_the_same_owner_is_never_selected() -> None:
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a2", "ALTRO-ANIMALE Rex zoppica", "Va visto."))

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert "ALTRO-ANIMALE" not in prompt


# --- (b) cut and limits ---------------------------------------------------------------------


def test_each_line_is_cut_at_300_characters() -> None:
    long_text = "INIZIO " + "parola " * 200 + "CODA-TAGLIATA"
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a1", long_text, "Vai adesso."))

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert "INIZIO" in prompt
    assert "CODA-TAGLIATA" not in prompt
    line = next(line for line in prompt.splitlines() if "INIZIO" in line)
    assert len(line.removeprefix("user: ")) <= 300


def test_at_most_two_conversations_first_line_and_last_two() -> None:
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a1", "CONV1-a", "CONV1-b", hours_ago=30))
    repo.save(_chat("owner-a", "pet-a1", "CONV2-a", "CONV2-b", hours_ago=20))
    repo.save(
        _chat("owner-a", "pet-a1", "CONV3-old1", "CONV3-old2", "CONV3-a", "CONV3-b", hours_ago=10)
    )

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert "CONV1" not in prompt  # the third conversation back is left out
    assert "CONV2-a" in prompt and "CONV2-b" in prompt
    assert "CONV3-a" in prompt and "CONV3-b" in prompt
    # round 4c: the owner's first line (where the case was described) and the last two
    assert "CONV3-old1" in prompt
    assert "CONV3-old2" not in prompt


@pytest.mark.parametrize(("hours_ago", "kept"), [(71.0, True), (73.0, False)])
def test_only_the_last_72_hours(hours_ago: float, kept: bool) -> None:
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a1", "FINESTRA-72", "ok", hours_ago=hours_ago))

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert ("FINESTRA-72" in prompt) is kept


# --- (c) a deleted conversation -------------------------------------------------------------


def test_a_deleted_conversation_is_not_selectable() -> None:
    repo = InMemoryConversationRepository()
    stored = repo.save(_chat("owner-a", "pet-a1", "CANCELLATA feci verdi", "Vai adesso."))
    DeleteConversationService(repo).execute(
        DeleteConversationInput(owner_id="owner-a", conversation_id=stored.id)
    )

    prompt = _ask(repo, "owner-a", "pet-a1")

    assert "CANCELLATA" not in prompt


# --- (d) logs ---------------------------------------------------------------------------------


def test_no_text_of_the_other_chats_reaches_the_logs(caplog: pytest.LogCaptureFixture) -> None:
    repo = InMemoryConversationRepository()
    repo.save(_chat("owner-a", "pet-a1", "NEI-LOG-MAI feci verdi", "NEI-LOG-MAI vai adesso"))

    with caplog.at_level(logging.DEBUG):
        prompt = _ask(repo, "owner-a", "pet-a1")

    assert "NEI-LOG-MAI" in prompt  # the lines did travel to the model...
    for record in caplog.records:  # ...and never to a log record
        assert "NEI-LOG-MAI" not in record.getMessage()
