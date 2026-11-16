"""The profile's notes and the reminders follow the record consent (Normativa,
2026-11-16), and a revocation also stops the turns already written with the
record from leaving again (Orchestrator decision, same day).

A fake provider records every request and answers with the codes it saw, so
both the request and the reply can be checked:
(i)   consent denied: no code in the request nor in the reply;
(ii)  consent granted: the codes are there;
(iii) revoked, then a new conversation: no code;
(iv)  the vet summary without consent: no note;
(v)   revoked in the same conversation: the earlier replies that carried the
      codes are not sent again, in the chat or in the vet summary.
"""

from __future__ import annotations

import re
from datetime import UTC, datetime

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.application.services.vet_summary import VetSummaryInput, VetSummaryService
from packages.core.domain.conversation.models import ChatMessage, history_without_record
from packages.core.domain.medical_record.consent_text import CURRENT_VERSION
from packages.core.domain.medical_record.models import MedicalRecordConsentRecord
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

NOTE_CODE = "CODICE-NOTA-QX7731"
REMINDER_CODE = "CODICE-REM-ZB4402"
CODES = (NOTE_CODE, REMINDER_CODE)
_CODE = re.compile(r"CODICE-(?:NOTA|REM)-[A-Z0-9]+")


class CodeEchoClient:
    """Records every request; answers with the codes found in it."""

    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        seen = sorted(set(_CODE.findall(request.system_prompt + request.user_prompt)))
        text = "Ecco cosa ti consiglio per Rex. " + (
            "Ho letto: " + ", ".join(seen) + "." if seen else "Nessun dato della cartella."
        )
        return LLMResponse(
            content=text, provider="fake", model="fake", token_count=10, finish_reason="stop"
        )

    def sent_text(self) -> str:
        return "\n".join(r.system_prompt + "\n" + r.user_prompt for r in self.requests)


def _consent(granted: bool) -> MedicalRecordConsentRecord:
    return MedicalRecordConsentRecord(
        granted=granted, version=CURRENT_VERSION, decided_at=datetime.now(UTC)
    )


class _World:
    def __init__(self, granted: bool | None) -> None:
        self.pets = InMemoryPetProfileRepository()
        self.pets.save(
            PetProfile(
                id="pet-1",
                owner_id="owner-1",
                name="Rex",
                species="Cane",
                notes=f"{NOTE_CODE}: allergico al pollo",
                medical_record_consent=_consent(granted) if granted is not None else None,
            )
        )
        reminders = InMemoryReminderRepository()
        reminders.save(
            Reminder(
                owner_id="owner-1",
                pet_id="pet-1",
                title="Antiparassitario",
                due_date=datetime.now(UTC).date(),
                notes=REMINDER_CODE,
            )
        )
        self.conversations = InMemoryConversationRepository()
        self.client = CodeEchoClient()
        self.service = SendChatMessageService(
            self.conversations,
            ChatOrchestrator(self.client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
            self.pets,
            reminder_context_retriever=ReminderContextRetriever(reminders),
        )

    def ask(self, text: str, conversation_id: str | None = None) -> tuple[str, str]:
        output = self.service.execute(
            SendChatMessageInput(
                owner_id="owner-1",
                pet_id="pet-1",
                conversation_id=conversation_id,
                user_message=text,
            )
        )
        return output.conversation.id, output.reply.content

    def set_consent(self, granted: bool) -> None:
        pet = self.pets.get("pet-1")
        assert pet is not None
        self.pets.save(pet.model_copy(update={"medical_record_consent": _consent(granted)}))

    def summary_request(self, conversation_id: str) -> str:
        client = CodeEchoClient()
        VetSummaryService(self.conversations, self.pets, client, NoopPiiAnonymizer()).execute(
            VetSummaryInput(owner_id="owner-1", conversation_id=conversation_id)
        )
        return client.sent_text()


QUESTION = "come devo gestire la sua alimentazione questa settimana?"


def test_i_consent_denied_no_code_leaves_or_comes_back() -> None:
    world = _World(granted=False)
    _, reply = world.ask(QUESTION)
    for code in CODES:
        assert code not in world.client.sent_text()
        assert code not in reply


def test_ii_consent_granted_the_codes_are_used() -> None:
    world = _World(granted=True)
    _, reply = world.ask(QUESTION)
    for code in CODES:
        assert code in world.client.sent_text()
        assert code in reply


def test_iii_revoked_then_a_new_conversation_no_code() -> None:
    world = _World(granted=True)
    world.ask(QUESTION)
    world.set_consent(False)
    world.client.requests.clear()

    _, reply = world.ask("e per i vaccini?")  # no conversation id: a new conversation
    for code in CODES:
        assert code not in world.client.sent_text()
        assert code not in reply


def test_iv_the_vet_summary_without_consent_has_no_note() -> None:
    world = _World(granted=False)
    conversation_id, _ = world.ask(QUESTION)
    sent = world.summary_request(conversation_id)
    assert NOTE_CODE not in sent
    assert "allergico al pollo" not in sent


def test_v_after_a_revocation_the_earlier_turns_are_not_sent_again() -> None:
    world = _World(granted=True)
    conversation_id, first_reply = world.ask(QUESTION)
    assert NOTE_CODE in first_reply  # the reply carries the record's content

    world.set_consent(False)
    world.client.requests.clear()
    _, reply = world.ask("e per i vaccini?", conversation_id=conversation_id)

    for code in CODES:
        assert code not in world.client.sent_text()
        assert code not in reply
    # The vet summary of the same conversation leaves them out too.
    for code in CODES:
        assert code not in world.summary_request(conversation_id)


def test_the_history_filter_drops_the_reply_and_the_question_before_it() -> None:
    messages = [
        ChatMessage(role="user", content="domanda 1"),
        ChatMessage(role="assistant", content="risposta con cartella", record_shared=True),
        ChatMessage(role="user", content="domanda 2"),
        ChatMessage(role="assistant", content="risposta senza", record_shared=False),
    ]
    kept = history_without_record(messages, conversation_had_consent=False)
    assert [m.content for m in kept] == ["domanda 2", "risposta senza"]


def test_a_reply_from_before_the_mark_counts_as_shared_when_the_conversation_had_consent() -> None:
    messages = [
        ChatMessage(role="user", content="domanda"),
        ChatMessage(role="assistant", content="risposta vecchia"),
    ]
    assert history_without_record(messages, conversation_had_consent=True) == []
    assert len(history_without_record(messages, conversation_had_consent=False)) == 2


def test_the_mark_never_reaches_the_app() -> None:
    world = _World(granted=True)
    conversation_id, _ = world.ask(QUESTION)
    stored = world.conversations.get(conversation_id)
    assert stored is not None
    assert all("record_shared" not in m for m in stored.public_dump()["messages"])
