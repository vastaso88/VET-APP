"""Collaudo, wave 1 (23/11/2026): replies in the wrong language, a fact of another conversation
repeated in every reply, legal obligations with no source."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from test_collaudo_ondata0_chat import _PLAIN, _WHOLE, CuttingClient, _ask

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.natural_answer_prompt import SEVERITY_CHECK_PROMPT
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.common.text_language import language_of
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.knowledge.duty_claims import (
    has_no_pet_passport,
    without_unsourced_duties,
)
from packages.core.domain.knowledge.duty_notes import DUTY_CATALOG, pinned_duty_notes
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.errors.base import ProviderError

# --- 6. the reply is in the account's language ------------------------------------------------

_IT_REPLY = (
    "Per Mango la struttura va bene, ma il punto caldo a 33 gradi è al limite. Controlla anche "
    "la parte fredda con un termometro digitale e segnala i valori, perché il peso è sceso."
)
_EN_REPLY = (
    "Mango's setup is fine, but the basking spot at 33 degrees is at the limit. Check the cool "
    "side with a digital thermometer and write down the values, because her weight went down."
)


@pytest.mark.parametrize(
    ("text", "code"),
    [
        (_IT_REPLY, "it"),
        (_EN_REPLY, "en"),
        (
            "El gecko debe tener una zona fría y una zona caliente. También hay que medir el peso "
            "cada semana y hablar con el veterinario si pierde más de lo normal.",
            "es",
        ),
        (
            "Der Gecko braucht eine warme und eine kühle Seite. Wenn das Gewicht weiter sinkt, "
            "ist es wichtig, dass Sie mit der Tierarztpraxis sprechen und die Werte notieren.",
            "de",
        ),
        (
            "Le gecko a besoin d'une zone chaude et d'une zone fraîche. Vous devez noter le poids "
            "dans un carnet et parler avec votre vétérinaire si la baisse continue.",
            "fr",
        ),
    ],
)
def test_the_language_of_a_reply_is_recognised(text: str, code: str) -> None:
    assert language_of(text) == code


@pytest.mark.parametrize("text", ["Sì.", "Briciola, Ombra, Micio, Rex e poi basta.", ""])
def test_a_short_or_unclear_text_says_nothing(text: str) -> None:
    assert language_of(text) is None


@pytest.mark.parametrize("v2", [True, False])
def test_an_italian_reply_for_an_english_account_is_translated(v2: bool) -> None:
    client = CuttingClient(answer=[(_IT_REPLY, "stop")], language_fix=[(_EN_REPLY, "stop")])
    result = _ask(client, "Is the basking spot fine?", v2=v2, name="Mango", language="en")

    assert "basking spot at 33 degrees" in result.answer
    (request,) = client.of("language_fix")
    assert "English" in request.system_prompt and request.model_class == "light"


def test_a_reply_in_the_right_language_is_not_touched() -> None:
    client = CuttingClient(answer=[(_EN_REPLY, "stop")])
    result = _ask(client, "Is the basking spot fine?", name="Mango", language="en")
    assert "basking spot at 33 degrees" in result.answer
    assert client.of("language_fix") == []


def test_a_failed_translation_keeps_the_reply() -> None:
    client = CuttingClient(answer=[(_IT_REPLY, "stop")], language_fix=[ProviderError("down")] * 2)
    assert "struttura" in _ask(client, "Is it fine?", name="Mango", language="en").answer


def test_every_non_italian_message_ends_with_the_language_and_italian_is_unchanged() -> None:
    for language, expected in (("en", "English"), ("de", "German"), ("it", None)):
        client = CuttingClient(answer=[(_EN_REPLY, "stop")])
        _ask(client, _PLAIN, name="Mango", language=language)
        (request,) = client.of("answer")
        if expected:
            assert request.user_prompt.rstrip().endswith(f"(Reply in {expected} only.)")
        else:
            assert "Reply in" not in request.user_prompt


# --- 7. a fact of another conversation is raised once -----------------------------------------


def test_another_conversation_travels_only_with_the_first_reply_of_a_new_one() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Briciola", species="Cane"))
    repo = InMemoryConversationRepository()
    at = datetime.now(UTC) - timedelta(hours=2)
    repo.save(
        Conversation(
            owner_id="owner-1",
            pet_id="pet-1",
            title="x",
            messages=[
                ChatMessage(role="user", content="ha mangiato del CIOCCOLATO", created_at=at),
                ChatMessage(role="assistant", content="Chiama subito la clinica.", created_at=at),
            ],
        )
    )
    client = CuttingClient(
        answer=[("Dormire tanto a questa età capita spesso, osservala con calma.", "stop")] * 3
    )
    orchestrator = ChatOrchestrator(
        client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer(), answer_v2=True
    )
    service = SendChatMessageService(repo, orchestrator, pets, recent_other_chats=True)
    first = service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="quante ore deve dormire?"
        )
    )
    service.execute(
        SendChatMessageInput(
            owner_id="owner-1",
            pet_id="pet-1",
            conversation_id=first.conversation.id,
            user_message="ogni quanto la devo spazzolare?",
        )
    )

    one, two = client.of("answer")
    assert "CIOCCOLATO" in one.user_prompt and "OTHER RECENT" in one.system_prompt
    assert "CIOCCOLATO" not in two.user_prompt and "OTHER RECENT" not in two.system_prompt


def test_the_check_raises_an_open_case_again_whatever_the_conversation_said() -> None:
    # Measured on 24/11/2026 (23 serious cases, two generations, two blind judges): with «is not
    # raised again» one generation in 46 lost the urgency (E008-1) and 3 of 14 of E040-2 did;
    # without it none. The repeated alarms did not increase (9 openings in 18 turns with it, 4
    # in 18 without).
    assert "is not raised again" not in SEVERITY_CHECK_PROMPT
    assert "leaves an open case unsaid" in SEVERITY_CHECK_PROMPT


# --- 8. a legal obligation needs a note ---------------------------------------------------------


@pytest.mark.parametrize(
    "sentence",
    [
        "In Italia è obbligatorio che ogni animale di compagnia abbia il microchip.",
        "Il microchip è obbligatorio per ogni animale.",
        "Dai l'antiparassitario: per legge va fatto entro 30 giorni.",
        "En Italia el microchip es obligatorio para todos los animales.",
        "A microchip is mandatory for every pet.",
        "Ein Mikrochip ist gesetzlich vorgeschrieben, also registrieren Sie ihn.",
        "La puce et la vaccination sont obligatoires, par la loi.",
        "L'assicurazione non è obbligatoria per i gatti.",
    ],
)
def test_an_obligation_with_no_note_loses_its_sentence(sentence: str) -> None:
    text = f"Osserva come mangia. {sentence}"
    assert without_unsourced_duties(text, []) == "Osserva come mangia."


@pytest.mark.parametrize(
    "sentence",
    [
        "Non ho una regola verificata sul microchip dei conigli: chiedi alla ASL.",
        "Chiedi alla ASL se è obbligatorio il microchip.",
        "The vaccination is good for him: ask the vet whether it is required.",
        "Porta il gatto dal veterinario per il vaccino.",
        "La microchippatura lo rende identificabile se si perde.",
    ],
)
def test_sentences_that_only_send_to_ask_or_give_no_obligation_stay(sentence: str) -> None:
    assert without_unsourced_duties(sentence, []) == sentence


def test_an_obligation_a_received_note_names_stays() -> None:
    leash = next(n for n in DUTY_CATALOG if "leash and muzzle" in n.title)
    sentence = "Il guinzaglio è obbligatorio nei centri abitati."
    assert without_unsourced_duties(sentence, [leash.snippet or ""]) == sentence
    chip = "Il microchip è obbligatorio per i cani."
    cut = without_unsourced_duties(f"Ciao a tutti. {chip}", [leash.snippet or ""])
    assert cut == "Ciao a tutti."


def test_the_answer_with_an_obligation_and_no_note_is_cut_end_to_end() -> None:
    reply = (
        "Per viaggiare con Copo prepara il trasportino e fallo visitare prima di partire, così "
        "sai come sta. Il microchip è obbligatorio per ogni animale di compagnia. Portagli fieno "
        "e acqua, e fermati spesso se il viaggio è lungo."
    )
    client = CuttingClient(answer=[(reply, "stop")])
    result = _ask(client, "Posso portare il mio coniglio in viaggio in Italia?", name="Copo")
    assert "obbligatorio" not in result.answer
    assert "trasportino" in result.answer and "fieno" in result.answer


@pytest.mark.parametrize(
    ("family", "breed", "has_none"),
    [
        ("dog", None, False),
        ("cat", None, False),
        ("small_mammal", "Coniglio nano", True),
        ("small_mammal", "Furetto", False),
        ("small_mammal", "Hurón", False),
        ("bird", "Canarino", True),
    ],
)
def test_the_pet_passport_is_for_dogs_cats_and_ferrets(
    family: str, breed: str | None, has_none: bool
) -> None:
    assert has_no_pet_passport(family, breed) is has_none


def test_an_animal_with_no_pet_passport_loses_the_sentence_that_speaks_of_one() -> None:
    text = "Prepara il trasportino. Dentro de la UE los conejos suelen viajar con un pasaporte."
    assert without_unsourced_duties(text, [], no_passport=True) == "Prepara il trasportino."
    assert without_unsourced_duties(text, [], no_passport=False) == text
    ask = "No tengo una regla verificada sobre el pasaporte: pregunta a tu veterinario."
    assert without_unsourced_duties(ask, [], no_passport=True) == ask


def test_a_note_on_dogs_is_never_pinned_to_a_rabbit() -> None:
    for message in (
        "voglio cedere i miei conigli, serve un annuncio?",
        "taglio delle orecchie del mio coniglio?",
    ):
        assert pinned_duty_notes(message, "small_mammal") == []
    assert [n.species for n in pinned_duty_notes("taglio delle orecchie?", "dog")] == ["dog"]


def test_abandonment_is_a_duty_for_every_animal_and_the_puppies_note_is_gone() -> None:
    for species in ("dog", "cat", "small_mammal", "bird", "fish"):
        (note,) = pinned_duty_notes("non la voglio più, la lascio in campagna", species)
        assert note.species == "other" and "any kind" in (note.snippet or "")
    for note in DUTY_CATALOG:
        assert "microchip" not in (note.snippet or "").lower() or note.species == "cat"
        assert "60 days" not in (note.snippet or "")


def test_the_prompt_states_a_duty_only_with_a_note_on_the_same_animal() -> None:
    client = CuttingClient(answer=[(_WHOLE, "stop")])
    _ask(client, _PLAIN)
    (request,) = client.of("answer")
    assert "duty note received with this request is about the SAME animal" in request.system_prompt
