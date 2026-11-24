"""Collaudo T10: the notice on the photos that are not read is said once, and fits the photo."""

from __future__ import annotations

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.conversation.photo_notice import notice_for, without_repeated_notice
from packages.core.domain.localization import translate
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

_BODY = "Per un Labrador la ciotola va bene se Rex mangia senza spingere il muso contro i bordi."


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_the_clause_on_documents_comes_only_when_a_document_is_named(language: str) -> None:
    full = translate("photo_reading_off", language)
    short = notice_for("guarda questa foto della ciotola di Rex", full)
    assert short != full and full.startswith(short[:-1]) and short.endswith(".")
    assert ";" not in short.rsplit(":", 1)[-1]
    for message in ("ecco la foto del libretto", "here is the test report", "el informe", "Befund"):
        assert notice_for(message, full) == full
    assert notice_for("", full) == full  # a photo alone


@pytest.mark.parametrize(
    "sentence",
    [
        "I can't see photos, so I can't judge the bowl from the picture.",
        "Non posso vedere la foto, quindi non so dirti.",
        "No puedo ver la imagen, así que no puedo valorarla.",
        "Ich kann das Bild nicht sehen.",
        "Je ne peux pas voir la photo.",
    ],
)
def test_the_repeated_sentence_goes_and_the_rest_stays(sentence: str) -> None:
    assert without_repeated_notice(f"{sentence} {_BODY}") == _BODY


def test_a_reply_that_is_only_that_sentence_is_kept() -> None:
    only = "Non posso vedere la foto."
    assert without_repeated_notice(only) == only


@pytest.mark.parametrize(
    "sentence",
    [
        "Non posso vedere la foto, ma se sanguina portalo subito dal veterinario.",
        "I can't see the photo, but a swollen eye needs a vet today.",
        "No puedo ver la imagen, pero si respira mal ve al veterinario ahora.",
        "Ich kann das Bild nicht sehen, aber bei Blut rufen Sie sofort den Tierarzt an.",
        "Je ne peux pas voir la photo, mais si elle saigne, appelez le vétérinaire maintenant.",
    ],
)
def test_a_sentence_that_also_gives_advice_is_never_cut(sentence: str) -> None:
    assert without_repeated_notice(f"{sentence} {_BODY}") == f"{sentence} {_BODY}"


def test_a_sentence_on_the_sight_of_the_animal_is_left_alone() -> None:
    text = "Un gatto anziano a volte non vede bene di notte. Lascia una luce accesa in corridoio."
    assert without_repeated_notice(text) == text


def test_the_reply_says_it_once() -> None:
    client = RecordingLLMClient(f"Non posso vedere la foto, quindi non so dirti. {_BODY}")
    answer = (
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
        .answer(
            ChatOrchestratorInput(
                user_message="guarda questa foto della ciotola di Rex, è troppo grande?",
                species="Cane",
                pet_name="Rex",
                photo_reading_off=True,
            )
        )
        .answer
    )
    assert answer.lower().count("posso vedere") == 1 and _BODY in answer
    assert "libretto" not in answer
