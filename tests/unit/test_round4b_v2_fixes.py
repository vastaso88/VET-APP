"""Synthetic users round 4b (21/11/2026), plan 08 v2 path only (CHAT_ANSWER_V2, off in
production): a fixed guard reply continues with what to do now; a new chat knows the serious
case opened in another chat on the same animal in the last 72 hours; a pet called "Câlin"
is not a hug."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.safety.harmful_requests import (
    DOSE_CHANGE_TEXTS,
    mentions_a_child_at_risk,
    mentions_child_handling,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

_DOSE_CHANGE = "sta meglio, posso sospendere l'antibiotico che gli ha prescritto?"
_FOLLOW_UP = (
    "Con il respiro veloce e la schiuma che hai descritto, chiama il veterinario adesso o "
    "vai al pronto soccorso veterinario: se il tuo è chiuso, il servizio di guardia."
)


def _orchestrator(llm: RecordingLLMClient, *, v2: bool = True) -> ChatOrchestrator:
    return ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=v2)


def _ask(
    llm: RecordingLLMClient,
    message: str,
    *,
    v2: bool = True,
    history: list[ChatMessage] | None = None,
    other_chats: list[ChatMessage] | None = None,
) -> ChatOrchestratorResult:
    return _orchestrator(llm, v2=v2).answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Biscuit",
            conversation_history=history or [],
            recent_other_chats=other_chats or [],
        )
    )


# --- 1. a fixed guard reply continues with what to do now -------------------------------


def test_a_dose_change_refusal_is_followed_by_what_to_do_now() -> None:
    llm = RecordingLLMClient(by_purpose={"guard_follow_up": _FOLLOW_UP})
    result = _ask(llm, _DOSE_CHANGE)

    fixed = DOSE_CHANGE_TEXTS["it"].format(name="Biscuit")
    assert result.answer.startswith(fixed.strip()[:60])
    assert result.answer.rstrip().endswith(_FOLLOW_UP)
    (request,) = llm.requests_for("guard_follow_up")
    assert "FIXED TEXT ALREADY GIVEN" in request.user_prompt


def test_the_follow_up_sees_the_serious_case_said_before() -> None:
    llm = RecordingLLMClient(by_purpose={"guard_follow_up": _FOLLOW_UP})
    history = [
        ChatMessage(role="user", content="Biscuit ha la schiuma bianca e respira veloce"),
        ChatMessage(role="assistant", content="Portalo dal veterinario adesso."),
    ]
    _ask(llm, _DOSE_CHANGE, history=history)

    (request,) = llm.requests_for("guard_follow_up")
    assert "schiuma bianca" in request.user_prompt


def test_a_follow_up_with_a_dose_or_a_failure_leaves_the_fixed_text_alone() -> None:
    fixed = DOSE_CHANGE_TEXTS["it"].format(name="Biscuit").strip()
    for outcome in ("Dagli 2 compresse ogni 12 ore e chiama il veterinario.", RuntimeError("x")):
        llm = RecordingLLMClient(by_purpose={"guard_follow_up": outcome})
        result = _ask(llm, _DOSE_CHANGE)
        assert result.answer.strip() == fixed


def test_a_follow_up_that_puts_off_a_serious_case_goes_through_the_severity_check() -> None:
    llm = RecordingLLMClient(
        by_purpose={
            "guard_follow_up": "Chiama il veterinario oggi e raccontagli cosa hai visto.",
            "severity_check": json.dumps({"serious": True, "delays": True, "rewrite": _FOLLOW_UP}),
        }
    )
    result = _ask(llm, _DOSE_CHANGE)

    assert result.answer.rstrip().endswith(_FOLLOW_UP)


def test_production_keeps_the_fixed_guard_reply_alone() -> None:
    llm = RecordingLLMClient(by_purpose={"guard_follow_up": _FOLLOW_UP})
    result = _ask(llm, _DOSE_CHANGE, v2=False)

    assert _FOLLOW_UP not in result.answer
    assert llm.requests_for("guard_follow_up") == []


# --- 2. other recent chats on the same animal ------------------------------------------------


_SERIOUS_ELSEWHERE = [
    ChatMessage(role="user", content="Cicci ha le feci verdi e gli occhi socchiusi"),
    ChatMessage(role="assistant", content="Cicci va vista dal veterinario adesso."),
]


def test_a_new_chat_sees_the_serious_case_of_another_chat() -> None:
    llm = RecordingLLMClient("Ecco come scegliere il miglio giusto.")
    _ask(llm, "che miglio le compro?", other_chats=_SERIOUS_ELSEWHERE)

    (request,) = llm.requests_for("answer")
    assert "Other conversations about this animal in the last 72 hours" in request.user_prompt
    assert "feci verdi" in request.user_prompt
    assert "OTHER RECENT CONVERSATIONS" in request.system_prompt


def test_production_ignores_other_chats() -> None:
    llm = RecordingLLMClient("Ecco come scegliere il miglio giusto.")
    _ask(llm, "che miglio le compro?", v2=False, other_chats=_SERIOUS_ELSEWHERE)

    (request,) = llm.requests_for("answer")
    assert "feci verdi" not in request.user_prompt


def _service(
    repo: InMemoryConversationRepository, llm: RecordingLLMClient, *, v2: bool
) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Cicci", species="Uccelli"))
    pets.save(PetProfile(id="pet-2", owner_id="owner-1", name="Rex", species="Cane"))
    return SendChatMessageService(repo, _orchestrator(llm, v2=v2), pets, recent_other_chats=v2)


def _conversation(pet: str, text: str, hours_ago: float) -> Conversation:
    at = datetime.now(UTC) - timedelta(hours=hours_ago)
    return Conversation(
        owner_id="owner-1",
        pet_id=pet,
        title="x",
        messages=[
            ChatMessage(role="user", content=text, created_at=at),
            ChatMessage(role="assistant", content="Va vista adesso.", created_at=at),
        ],
    )


def test_the_service_passes_only_the_same_pets_chats_of_the_last_72_hours() -> None:
    repo = InMemoryConversationRepository()
    repo.save(_conversation("pet-1", "feci verdi e occhi socchiusi", hours_ago=5))
    repo.save(_conversation("pet-1", "una settimana fa perdeva piume", hours_ago=24 * 7))
    repo.save(_conversation("pet-2", "Rex zoppica da ieri", hours_ago=2))
    llm = RecordingLLMClient("Ecco come scegliere il miglio giusto.")

    _service(repo, llm, v2=True).execute(
        SendChatMessageInput(owner_id="owner-1", pet_id="pet-1", user_message="che miglio?")
    )

    (request,) = llm.requests_for("answer")
    assert "feci verdi" in request.user_prompt
    assert "perdeva piume" not in request.user_prompt  # older than 72 hours
    assert "zoppica" not in request.user_prompt  # another animal


def test_the_service_reads_no_other_chats_when_v2_is_off() -> None:
    repo = InMemoryConversationRepository()
    repo.save(_conversation("pet-1", "feci verdi e occhi socchiusi", hours_ago=5))
    llm = RecordingLLMClient("Ecco come scegliere il miglio giusto.")

    _service(repo, llm, v2=False).execute(
        SendChatMessageInput(owner_id="owner-1", pet_id="pet-1", user_message="che miglio?")
    )

    (request,) = llm.requests_for("answer")
    assert "feci verdi" not in request.user_prompt


# --- 4. a pet's name is not a word of the message ----------------------------------------


def test_a_cat_called_calin_is_not_a_hug_and_petit_is_not_a_child() -> None:
    for message in (
        "Pardon, Câlin a vomi un petit bout d'herbe ce matin, c'est normal ?",
        "Dernière petite question : Câlin griffe le canapé, comment faire ?",
    ):
        assert not mentions_child_handling(message, "Câlin")
        assert not mentions_a_child_at_risk(message, "Câlin")
    assert mentions_child_handling("mon fils tire la queue du chat", "Câlin")
    assert mentions_child_handling("les petits font des câlins au chien", "Rex")


# --- round 4c (21/11): an open case in another chat is checked even without a delay word -----


def test_with_other_chats_the_severity_check_always_runs() -> None:
    # round 4c #43: a reply on harnesses had no delay word, the trigger never fired
    llm = RecordingLLMClient(
        "Per un pastore tedesco che fa passeggiate lunghe conviene la pettorina.",
        by_purpose={
            "severity_check": json.dumps(
                {
                    "serious": True,
                    "delays": True,
                    "rewrite": "Prima di tutto: per i conati di stanotte chiama il veterinario "
                    "adesso. Per le passeggiate conviene la pettorina.",
                }
            )
        },
    )
    other = [ChatMessage(role="user", content="Argo ha conati a vuoto e la pancia dura")]
    result = _ask(llm, "meglio pettorina o collare?", other_chats=other)

    assert result.answer.startswith("Prima di tutto")
    (request,) = llm.requests_for("severity_check")
    assert "conati a vuoto" in request.user_prompt


def test_without_other_chats_a_reply_with_no_delay_is_not_checked() -> None:
    llm = RecordingLLMClient("Per un pastore tedesco conviene la pettorina.")
    _ask(llm, "meglio pettorina o collare?")

    assert llm.requests_for("severity_check") == []


# --- Normativa §20.13 point 4 (owner's yes 21/11): emergency services, never digits ---------


def test_every_v2_prompt_has_the_emergency_services_sentence_without_digits() -> None:
    llm = RecordingLLMClient("Risposta di prova, concreta e breve.")
    _ask(llm, "il cane ha morso mio figlio sulla mano e sanguina")
    (request,) = llm.requests_for("answer")
    system = request.system_prompt
    assert "emergency number of their country" in system
    assert "without any digits" in system
    assert "Never for a general malaise" in system  # case #82 stays as it is
    assert "never leaves the animal out" in system


def test_the_emergency_sentence_without_digits_reaches_the_owner_and_digits_never_do() -> None:
    sentence = "Chiama subito i soccorsi o il numero di emergenza del tuo Paese per tuo figlio."
    body = (
        " Poi separa il cane in un'altra stanza, senza sgridarlo, e scrivimi quando il bambino "
        "è al sicuro: vediamo insieme cosa è successo e cosa fare con lui."
    )
    llm = RecordingLLMClient(sentence + body)
    result = _ask(llm, "il cane ha morso mio figlio sulla mano e sanguina")
    assert sentence in result.answer

    llm = RecordingLLMClient("Chiama subito il 112 per tuo figlio." + body)
    result = _ask(llm, "il cane ha morso mio figlio sulla mano e sanguina")
    assert "112" not in result.answer
