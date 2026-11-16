"""The owner's test of 2026-11-16 (anonymised): a dog that stands between the
guests and the children and sometimes growls.

What went wrong: the fixed sentence about small children, pulled tails and
tight hugs opened BOTH replies (a child word plus "ringhia", even "non
ringhia"); the first reply explained motives nobody had stated and asked
"since when" only at the end; the second contradicted the first and never
named a veterinarian expert in behaviour.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient
from test_chat_orchestrator import ScriptedContentLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.domain.conversation.models import ChatMessage
from packages.core.domain.safety.harmful_requests import (
    CHILD_NEVER_ALONE,
    mentions_a_child_at_risk,
    mentions_a_warning_signal,
    mentions_child_handling,
    warning_toward_others,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

FIRST = (
    "Rex si mette sempre in mezzo tra gli ospiti e i miei figli. A volte, accucciato, "
    "ringhia un pochino, perché sa che non voglio. Dopo un po' di distrazione smette, ma con "
    "gli ospiti ha sempre questo atteggiamento, anche con una persona che viene ogni "
    "settimana. Cosa posso fare?"
)
SECOND = (
    "Con i bambini non ringhia, secondo me li vuole proteggere. Con gli ospiti è lui ad "
    "avvicinarsi per abbaiare; se lo riprendo smette e si accuccia, ma non molla "
    "l'atteggiamento."
)
ASKED = (
    "Il ringhio è un avviso da rispettare, mai da punire. Per ora, quando ci sono ospiti, "
    "tienilo dove un adulto lo vede. 1. Quanti anni hanno i tuoi figli? 2. Da quanto succede? "
    "3. Cosa fa esattamente quando arriva qualcuno? 4. Ha mai morso o pizzicato?"
)


def _ask(
    message: str,
    *,
    history: list[ChatMessage] | None = None,
    client: RecordingLLMClient | ScriptedContentLLMClient | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient | ScriptedContentLLMClient]:
    llm = client or RecordingLLMClient()
    result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message,
            species="Cane",
            pet_name="Rex",
            conversation_history=history or [],
        )
    )
    return result, llm


# --- the detectors -------------------------------------------------------------------------------


def test_the_first_message_is_a_warning_toward_others_but_no_child_handling() -> None:
    assert warning_toward_others(FIRST)
    assert mentions_a_child_at_risk(FIRST)  # children and a growl: the note, adapted
    assert not mentions_child_handling(FIRST)  # no tail, no hug: no fixed sentence


def test_a_signal_the_owner_rules_out_is_not_there() -> None:
    assert not mentions_a_warning_signal(SECOND)
    assert not mentions_a_child_at_risk(SECOND)
    for message in (
        "non ha mai ringhiato a nessuno",
        "non li ha mai morsi",
        "he has never growled at the kids",
        "il ne grogne pas",
    ):
        assert not mentions_a_warning_signal(message), message


@pytest.mark.parametrize(
    "message",
    [
        "perché ringhia quando mi avvicino mentre mangia?",  # a classic, answered directly
        "la cucciola mi morde le mani quando giochiamo, come glielo faccio capire?",  # play
    ],
)
def test_classic_cases_are_not_asked_first(message: str) -> None:
    assert not warning_toward_others(message)


def test_the_fixed_child_sentence_still_comes_for_the_gestures_it_speaks_of() -> None:
    assert mentions_child_handling("mia figlia di 3 anni le tira la coda e la prende per il collo")
    assert mentions_child_handling("mio figlio di 8 anni lo abbraccia forte e ha ringhiato")


# --- turn 1: ask first, no fixed block -----------------------------------------------------------


def test_the_first_turn_asks_first_without_the_fixed_child_block() -> None:
    result, client = _ask(FIRST, client=ScriptedContentLLMClient(ASKED))

    assert not result.answer.startswith("Prima di tutto")
    assert CHILD_NEVER_ALONE["it"][:40] not in result.answer
    prompt = client.requests[-1].system_prompt
    assert "This reply ASKS FIRST" in prompt
    assert "how old the children are" in prompt
    assert "No causes, no motives" in prompt
    assert "answer first and ask" not in prompt.split("This reply ASKS FIRST")[1]
    assert "Answer first; then you may ask ONE context question" not in prompt
    assert "A CHILD IS INVOLVED" in prompt
    # The questions are an anamnesis: the owner's answer continues the case.
    assert result.awaiting_anamnesis is True


# --- turn 2: build on the answers, stay consistent, name the specialist ---------------------------


def test_the_second_turn_answers_consistently_and_names_the_behaviour_vet() -> None:
    history = [
        ChatMessage(role="user", content=FIRST),
        ChatMessage(role="assistant", content=ASKED),
    ]
    result, client = _ask(SECOND, history=history)

    prompt = client.requests[-1].system_prompt
    assert "This reply ASKS FIRST" not in prompt  # asked once
    assert "WARNING SIGNAL IN A BEHAVIOUR CASE" in prompt
    assert "Stay consistent with your earlier replies" in prompt
    assert "never state a motive" in prompt
    assert "veterinario esperto in comportamento" in prompt
    assert "A CHILD IS INVOLVED" not in prompt  # "non ringhia" with the children
    assert not result.answer.startswith("Prima di tutto")


def test_the_fixed_child_sentence_is_never_repeated_in_a_conversation() -> None:
    message = "mia figlia di 3 anni le tira la coda, ma giocano, è normale no?"
    first, _ = _ask(message, client=ScriptedContentLLMClient("Non è un gioco per lui."))
    assert first.answer.startswith("Prima di tutto: un bambino piccolo")

    history = [
        ChatMessage(role="user", content=message),
        ChatMessage(role="assistant", content=first.answer),
    ]
    follow_up = "e se mia figlia le tira le orecchie?"
    assert mentions_child_handling(follow_up)  # it would trigger the sentence again
    again, _ = _ask(
        follow_up,
        history=history,
        client=ScriptedContentLLMClient("Vale lo stesso."),
    )
    assert "Prima di tutto: un bambino piccolo" not in again.answer


def test_a_puppy_nipping_in_play_gets_neither_the_questions_nor_the_warning_note() -> None:
    client = RecordingLLMClient()
    _ask("la cucciola mi morde le mani quando giochiamo, come glielo faccio capire?", client=client)
    prompt = client.requests_for("answer")[-1].system_prompt
    assert "This reply ASKS FIRST" not in prompt
    assert "WARNING SIGNAL IN A BEHAVIOUR CASE" not in prompt


# --- profile data are read, never asked ---------------------------------------------------------


def test_the_full_profile_reaches_the_prompt_and_the_rule_forbids_asking_it() -> None:
    client = RecordingLLMClient(ASKED)
    ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=FIRST,
            species="Cane",
            pet_name="Rex",
            breed="Meticcio",
            age_years=6,
            sex="Maschio",
            is_sterilized=True,
            weight_label="22 kg",
        )
    )
    request = client.requests_for("answer")[-1]
    for fact in ("Breed: Meticcio", "Age: 6 years", "Sex: Maschio", "Weight: 22 kg"):
        assert fact in request.user_prompt, fact
    assert "neutered" in request.user_prompt.lower()
    assert "Never ask what the pet's profile already says" in request.system_prompt
    assert "This reply ASKS FIRST" in request.system_prompt


# --- length: a second pass past the tolerance ---------------------------------------------------

LONG = " ".join(["Una frase utile per il proprietario di Rex."] * 40)  # 320 words
SHORT = "Il ringhio è un avviso. 1. Quanti anni hanno i figli? 2. Da quanto succede?"
PLAIN = "come insegno a Rex a stare sul tappeto quando suonano?"


def test_a_long_answer_is_shortened_by_a_light_pass_before_the_checks() -> None:
    client = RecordingLLMClient(by_purpose={"answer": LONG, "shorten": SHORT})
    result, _ = _ask(PLAIN, client=client)

    shorten = client.requests_for("shorten")
    assert len(shorten) == 1
    assert shorten[0].model_class == "light"
    assert shorten[0].user_prompt == LONG
    assert result.answer.startswith(SHORT)


def test_a_short_answer_gets_no_second_pass() -> None:
    client = RecordingLLMClient(by_purpose={"answer": SHORT})
    _ask(PLAIN, client=client)
    assert client.requests_for("shorten") == []


@pytest.mark.parametrize("outcome", [RuntimeError("down"), "", LONG + " ancora"])
def test_a_failed_or_useless_shortening_keeps_the_long_answer(outcome: str | Exception) -> None:
    client = RecordingLLMClient(by_purpose={"answer": LONG, "shorten": outcome})
    result, _ = _ask(PLAIN, client=client)
    assert result.answer.startswith(LONG[:80])


def test_a_long_message_keeps_its_longer_answer() -> None:
    client = RecordingLLMClient(by_purpose={"answer": LONG})
    long_message = "Ti scrivo diversi punti su Rex. " + "Un dettaglio in più sulla casa. " * 25
    _ask(long_message, client=client)
    assert client.requests_for("shorten") == []
