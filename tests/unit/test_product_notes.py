"""The amounts of a product that is not a medicine come only from its label or its maker
(owner, 25/11/2026). Invented products: nothing here is a real label."""

from __future__ import annotations

import pytest
from test_collaudo_ondata0_chat import CuttingClient, _ask

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.domain.knowledge import product_notes as module
from packages.core.domain.knowledge.dose_in_answer import (
    find_dosage,
    unsourced_supplement,
    without_unsourced_supplements,
)
from packages.core.domain.knowledge.product_notes import (
    PRODUCT_NOTES,
    ProductNote,
    product_notes_block,
    product_notes_for,
)
from packages.core.domain.safety.dosage_request import is_dosage_request


def _note(**kw: object) -> ProductNote:
    data: dict[str, object] = {
        "product": "Calcio Esempio",
        "maker": "Casa Esempio",
        "species": ("reptile_amphibian",),
        "words": ("calcio", "calcium"),
        "says": "Spolverare gli insetti a ogni pasto per i giovani, due volte a settimana.",
        "source_kind": "label",
        "source_url": "https://example.com/calcio",
        "read_on": "2026-11-25",
    }
    return ProductNote(**{**data, **kw})  # type: ignore[arg-type]


def test_every_note_in_the_list_is_usable() -> None:
    assert [n.product for n in PRODUCT_NOTES if n.problem()] == []


@pytest.mark.parametrize(
    "change",
    [
        {"source_kind": "forum"},
        {"source_url": "https://www.reddit.com/r/geckos"},
        {"source_url": "https://forum.example.com/x"},
        {"source_url": "http://example.com/x"},
        {"product": "Antibiotico Esempio"},
        {"says": "Due compresse di paracetamolo al giorno."},
        {"species": ()},
        {"words": ()},
    ],
)
def test_a_note_without_a_certain_source_or_on_a_medicine_is_refused(
    change: dict[str, object],
) -> None:
    assert _note(**change).problem()


def test_a_note_is_found_by_the_words_of_the_message_and_the_species() -> None:
    notes = [_note()]
    assert product_notes_for("quanto calcio do al geco?", "reptile_amphibian", notes)
    assert not product_notes_for("quanto calcio do al geco?", "dog", notes)
    assert not product_notes_for("quanto spesso lo lavo?", "reptile_amphibian", notes)
    block = product_notes_block(notes)
    assert "https://example.com/calcio" in block and "due volte a settimana" in block
    assert product_notes_block([]) == ""


_REPLY = (
    "Il calcio serve alle ossa di Mango. Spolvera i grilli due volte a settimana, con poca "
    "polvere. Gli insetti vanno nutriti bene prima di darli."
)


def _answer(
    monkeypatch: pytest.MonkeyPatch, notes: tuple[ProductNote, ...], reply: str = _REPLY
) -> tuple[str, str]:
    monkeypatch.setattr(module, "PRODUCT_NOTES", notes)
    monkeypatch.setattr(
        "packages.core.application.services.chat_orchestrator.product_notes_for",
        lambda message, family: product_notes_for(message, family, notes),
    )
    client = CuttingClient(answer=[(reply, "stop")])
    result = _ask(
        client,
        "Ogni quanto devo dare il calcio al mio geco leopardino?",
        name="Mango",
        species="Rettili e anfibi",
    )
    return str(result.answer), str(client.of("answer")[0].user_prompt)


def test_without_a_note_the_amount_is_cut_and_the_rest_stays(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    answer, prompt = _answer(monkeypatch, ())
    assert "due volte a settimana" not in answer
    assert "serve alle ossa" in answer and "nutriti bene" in answer
    assert "PRODUCT NOTES" not in prompt


def test_with_a_note_the_amount_of_the_label_is_said(monkeypatch: pytest.MonkeyPatch) -> None:
    answer, prompt = _answer(monkeypatch, (_note(),))
    assert "due volte a settimana" in answer
    assert "PRODUCT NOTES" in prompt and "https://example.com/calcio" in prompt


def test_the_owners_own_amount_is_not_cut() -> None:
    owner = "Gli do un cucchiaino di calcio a ogni pasto, va bene?"
    assert unsourced_supplement("Un cucchiaino di calcio a ogni pasto.", allowed_text=owner) is None
    assert unsourced_supplement("Due cucchiaini di calcio.", allowed_text="") is not None


def test_medicines_stay_as_they_were() -> None:
    assert find_dosage("Dagli 5 mg/kg di meloxicam.")
    assert find_dosage("Due compresse di Finadyne ogni 12 ore.", supplements=False)
    assert find_dosage("Il multivitaminico una volta a settimana.", supplements=False) is None
    assert find_dosage("Il multivitaminico una volta a settimana.") is not None


def test_a_line_cut_keeps_the_layout() -> None:
    text = (
        "Il calcio serve.\n\n1. Spolvera i grilli ogni giorno con calcio.\n"
        "2. Nutri bene gli insetti."
    )
    assert without_unsourced_supplements(text) == "Il calcio serve.\n\n2. Nutri bene gli insetti."


@pytest.mark.parametrize(
    "message",
    [
        "Posso dare l'olio di salmone a Rex? Quanti ml al giorno?",
        "quante capsule di omega 3 al giorno?",
        "how many mg of vitamin C does my guinea pig need?",
        "how many milligrams of vitamin C does my guinea pig need?",
        "quanti millilitri di olio di pesce gli do?",
        "wie viele Tropfen Lachsöl am Tag?",
        "¿cuántas gotas de vitamina C le doy?",
        "combien de gouttes de vitamine C par jour ?",
    ],
)
def test_a_supplement_is_not_a_dose_request(message: str) -> None:
    assert not is_dosage_request(message)
    assert not ChatOrchestrator._is_dosage_request(message.lower())


@pytest.mark.parametrize(
    "message",
    [
        "quante gocce di vitamina K per il topicida?",
        "quanti ml di gluconato di calcio gli inietto?",
        "quante compresse di tachipirina e quante vitamine gli do?",
        "quanti mg/kg di vitamina D?",
        "how many tablets of wormer, and the vitamins?",
        "quante gocce di antibiotico con l'integratore?",
    ],
)
def test_a_medicine_beside_it_is_still_a_dose_request(message: str) -> None:
    assert is_dosage_request(message)
    assert ChatOrchestrator._is_dosage_request(message.lower())


def test_a_reply_that_is_only_the_figure_never_goes_out() -> None:
    client = CuttingClient(answer=[("Spolvera il calcio due volte a settimana.", "stop")])
    result = _ask(
        client,
        "ogni quanto spolvero il calcio sui grilli?",
        species="Rettili e anfibi",
        name="Geko",
    )
    assert "due volte" not in result.answer
