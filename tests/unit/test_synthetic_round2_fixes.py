"""Synthetic users, round 2 (2026-11-16, .local/synthetic_users/giro2/report.md):
points 1, 2, 3, 9 and 10b of the chat.

1. The emergency first aid was the same generic block ("al caldo", no food)
   for a wound, a blocked bladder and breathing trouble.
2. Grave pictures got questions before any help ("Prima di darti
   indicazioni..."), and no reply said to press on a wound.
3. Vague behaviour pictures toward the animal or the owner ("ringhia ogni
   tanto", "fa i dispetti") got causes and advice before any question.
9. "Orlando è anche lui un gatto?" with Orlando on the account.
10b. "Non utile" under a reply that is not a health answer said "message not
   found" and read as a bug.
"""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.mark_not_helpful import (
    MarkNotHelpfulInput,
    MarkNotHelpfulService,
)
from packages.core.application.services.natural_answer_prompt import build_emergency_prompt
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.knowledge.dose_in_answer import find_dosage
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.pet_profile.species import normalize_species
from packages.core.domain.safety.clarification_fit import describes_a_grave_picture
from packages.core.domain.safety.harmful_requests import behaviour_needs_questions
from packages.core.domain.safety.triage_clarification import clarifying_question
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ValidationError


def _ask(
    message: str,
    *,
    species: str = "Cane",
    name: str = "Rex",
    sex: str | None = None,
    history: list[ChatMessage] | None = None,
    client: RecordingLLMClient | None = None,
) -> tuple[ChatOrchestratorResult, RecordingLLMClient]:
    llm = client or RecordingLLMClient()
    result = ChatOrchestrator(llm, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(
            user_message=message,
            species=species,
            pet_name=name,
            sex=sex,
            conversation_history=history or [],
        )
    )
    return result, llm


# --- 2. grave pictures: the help first, no question -----------------------------------------------


@pytest.mark.parametrize(
    "message",
    [
        "Kernel si è ferita a una zampa e sanguina parecchio, non si ferma con il panno.",
        "Artù si sforza in lettiera e fa solo poche gocce di pipì, è un maschio.",
        "Pixel si nasconde. Ormai ha più di 4 ore che non fa pipì.",
        "va nella lettiera ma non riesce a fare la pipì, non esce niente",
        "è appena caduta a terra e ha avuto una specie di convulsione, ora si riprende",
        "non respira bene, il respiro fischia e tiene la bocca aperta da stamattina",
    ],
)
def test_the_answer_already_in_the_message_makes_it_grave(message: str) -> None:
    assert describes_a_grave_picture(message)


@pytest.mark.parametrize(
    "message",
    [
        "c'è un po' di sangue sulla zampa",
        "fischia quando lo chiamo?",
        "il cane non si ferma mai",
        "gli metto poche gocce di collirio",
        "only a few drops of blood",
    ],
)
def test_ordinary_sentences_stay_ordinary(message: str) -> None:
    assert not describes_a_grave_picture(message)


def test_heavy_bleeding_gets_the_bleeding_steps_with_the_gesture_first() -> None:
    result, _ = _ask("Rex si è ferito a una zampa e sanguina parecchio, non si ferma con il panno")
    assert result.mode == "triage"
    assert "premi subito sulla ferita" in result.answer
    assert "al caldo" not in result.answer
    assert "Prima di darti indicazioni" not in result.answer


def test_a_blocked_male_cat_gets_the_urinary_steps_at_once() -> None:
    result, _ = _ask(
        "Artù si sforza in lettiera e fa solo poche gocce di pipì, è un maschio.",
        species="Gatto",
        name="Artù",
        sex="Maschio",
    )
    assert result.mode == "triage"
    assert "non aspettare per vedere se ci riesce" in result.answer
    # Doc 20: "non premere sulla pancia" and "in poche ore" have no source.
    assert "premere" not in result.answer and "poche ore" not in result.answer
    assert "al caldo" not in result.answer


def test_a_dog_that_cannot_breathe_gets_the_breathing_steps_not_warmth() -> None:
    result, _ = _ask("Rex non riesce a respirare")
    assert result.mode == "triage"
    assert "posto fresco" in result.answer and "al caldo" not in result.answer


def test_an_exotic_animal_keeps_the_steps_of_a_vet_who_knows_the_species() -> None:
    result, _ = _ask(
        "Taco non respira bene, il respiro fischia e tiene la bocca aperta da stamattina",
        species="Piccoli mammiferi",
        name="Taco",
    )
    assert result.mode == "triage"
    assert "esperto in animali esotici" in result.answer


@pytest.mark.parametrize(
    ("language", "gesture"),
    [
        ("it", "Intanto premi sulla ferita"),
        ("en", "Meanwhile press on the wound"),
        ("es", "Mientras tanto aprieta sobre la herida"),
        ("de", "Drücken Sie inzwischen"),
        ("fr", "En attendant, appuyez sur la plaie"),
    ],
)
def test_the_bleeding_question_starts_with_the_gesture(language: str, gesture: str) -> None:
    for female in (False, True):
        question = clarifying_question("bleeding_trauma", language, female=female)
        assert question is not None and question.startswith(gesture)


def test_a_little_blood_gets_the_gesture_before_the_question() -> None:
    result, _ = _ask("Rex sanguina un po' dalla zampa, si è tagliato su un sasso")
    assert result.mode == "safety_clarification"
    assert result.answer.startswith("Intanto premi sulla ferita")
    assert result.answer.rstrip().endswith("?")


def test_a_fish_is_never_asked_whether_it_ran() -> None:
    result, _ = _ask(
        "il mio pesce rosso boccheggia in superficie e respira male",
        species="Pesci",
        name="Pasquale",
    )
    assert "corsa" not in result.answer


# --- 1. the emergency prompt: the steps that fit, gesture first --------------------------------


def test_the_emergency_prompt_asks_for_the_fitting_steps_not_a_copied_block() -> None:
    prompt = build_emergency_prompt(first_aid="1) premi sulla ferita")
    assert "the most urgent gesture first" in prompt
    assert "never copy them as a block" in prompt
    assert "leave out a step that clearly does not apply" in prompt
    assert "never a step of your own" in prompt


# --- 3. vague behaviour toward the animal or the owner: questions first -------------------------


@pytest.mark.parametrize(
    "message",
    [
        "Lampo ringhia ogni tanto, non so perché",
        "Byte da qualche giorno fa i dispetti, non so cosa vuole.",
        "Bruno ist in letzter Zeit irgendwie komisch. Er knurrt manchmal.",
    ],
)
def test_a_vague_behaviour_picture_asks_first(message: str) -> None:
    assert behaviour_needs_questions(message)
    _, client = _ask(message)
    prompt = client.requests_for("answer")[-1].system_prompt
    assert "This reply ASKS FIRST" in prompt
    assert "no hypothesis the owner did not write" in prompt


@pytest.mark.parametrize(
    "message",
    [
        "perché ringhia quando mi avvicino mentre mangia?",
        "la cucciola mi morde le mani quando giochiamo",
    ],
)
def test_a_behaviour_with_its_situation_is_answered_directly(message: str) -> None:
    assert not behaviour_needs_questions(message)


def test_the_reply_to_the_questions_gets_the_case_note_and_asks_nothing_again() -> None:
    history = [
        ChatMessage(role="user", content="Lampo ringhia ogni tanto, non so perché"),
        ChatMessage(role="assistant", content="Da quanto succede? Ha mai morso?"),
    ]
    _, client = _ask("da un mese, quando passo vicino alla sua cuccia", history=history)
    prompt = client.requests_for("answer")[-1].system_prompt
    assert "This reply ASKS FIRST" not in prompt
    assert "WARNING SIGNAL IN A BEHAVIOUR CASE" in prompt


def test_an_unrelated_question_later_does_not_carry_the_behaviour_note() -> None:
    history = [
        ChatMessage(role="user", content="Lampo ringhia ogni tanto, non so perché"),
        ChatMessage(role="assistant", content="Da quanto succede?"),
        ChatMessage(role="user", content="da un mese"),
        ChatMessage(role="assistant", content="Ecco cosa puoi fare."),
    ]
    _, client = _ask("quante volte al giorno deve mangiare un cane adulto?", history=history)
    prompt = client.requests_for("answer")[-1].system_prompt
    assert "WARNING SIGNAL IN A BEHAVIOUR CASE" not in prompt


# --- 9. the owner's other animals are known by name and species ---------------------------------


def test_the_other_animals_of_the_owner_reach_the_prompt_by_name_and_species() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="p1", owner_id="o1", name="Santuzza", species="Gatto"))
    pets.save(
        PetProfile(id="p2", owner_id="o1", name="Orlando", species="Gatto", notes="FIV positivo")
    )
    pets.save(PetProfile(id="p3", owner_id="o2", name="Estraneo", species="Cane"))
    client = RecordingLLMClient()
    SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
    ).execute(
        SendChatMessageInput(
            owner_id="o1", pet_id="p1", user_message="Santuzza e Orlando giocano insieme?"
        )
    )
    user_prompt = client.requests_for("answer")[-1].user_prompt
    assert "Other animals of this owner" in user_prompt
    assert "Orlando (Gatto)" in user_prompt
    assert "FIV" not in user_prompt  # never another pet's notes
    assert "Estraneo" not in user_prompt  # never another owner's animal


# --- 9. food and water portions are not doses ----------------------------------------------------


@pytest.mark.parametrize(
    "sentence",
    [
        "Assunta può mangiare una bustina da 85 g due volte al giorno.",
        "Circa 40-50 grammi per kg di peso al giorno di cibo umido.",
        "Give her about 50 ml per kg of water a day.",
        "Poppy needs fresh pellets twice a day and a few drops of water on the leaves.",
        "Offri 2 bustine di umido al giorno.",
    ],
)
def test_a_food_or_water_portion_is_not_a_dose(sentence: str) -> None:
    assert find_dosage(sentence) is None


@pytest.mark.parametrize(
    "sentence",
    [
        "Dai 10 mg/kg di meloxicam",
        "mescola 5 mg di meloxicam nel cibo",
        "3 gocce di antibiotico nell'acqua due volte al giorno",
        "una bustina di antibiotico nel cibo due volte al giorno",
        "0,1 ml per kg nel cibo",
        "gli do 2 gocce nel cibo tre volte al giorno",
    ],
)
def test_a_medicine_in_the_food_is_still_a_dose(sentence: str) -> None:
    assert find_dosage(sentence) is not None


def test_a_fish_label_in_the_plural_is_still_a_fish() -> None:
    assert normalize_species("Pesci") == "fish"


# --- 10b. "not helpful" under a reply that is not a health answer -------------------------------


def test_not_helpful_on_a_non_health_reply_says_why() -> None:
    repository = InMemoryConversationRepository()
    conversation = Conversation(
        owner_id="o1",
        pet_id="p1",
        title="Ringhio",
        messages=[
            ChatMessage(role="user", content="ringhia"),
            ChatMessage(role="assistant", content="Da quanto succede?"),
        ],
    )
    repository.save(conversation)
    reply_id = conversation.messages[1].id

    with pytest.raises(ValidationError, match="only a health answer can be marked"):
        MarkNotHelpfulService(repository).execute(
            MarkNotHelpfulInput(owner_id="o1", conversation_id=conversation.id, message_id=reply_id)
        )
    with pytest.raises(ValidationError, match="^message not found$"):
        MarkNotHelpfulService(repository).execute(
            MarkNotHelpfulInput(owner_id="o1", conversation_id=conversation.id, message_id="nope")
        )
