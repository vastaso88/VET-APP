"""Around the world: the travel cards (docs/product/18, docs/compliance/17 A)."""

import importlib.util
import json
from datetime import date, timedelta
from pathlib import Path
from types import ModuleType

import pytest

from packages.core.application.services.list_travel_cards import ListTravelCardsService
from packages.core.domain.travel.cards import (
    HIDDEN_AFTER_DAYS,
    OLD_AFTER_DAYS,
    TRAVEL_CARDS_FILE,
    TravelBlock,
    TravelCard,
    TravelSentence,
    TravelSource,
    load_travel_cards,
)

ROOT = Path(__file__).resolve().parents[2]
TODAY = date(2026, 11, 16)
CARD = {
    "codice": "VIA-EU-CAN",
    "paese": "EU",
    "specie": "cane",
    "tipo_viaggio": "non_commerciale",
    "titolo": "t",
    "stato": "bozza",
    "ultimo_controllo": "2026-11-16",
    "scadenza": "2027-02-14",
    "pagina_ufficiale": "https://example.com",
}


def _card(checked_on: date, status: str = "approved") -> TravelCard:
    return TravelCard(
        id="via-xx-can",
        country="XX",
        species="dog",
        title="Titolo",
        checked_on=checked_on,
        official_url="https://example.com/official",
        status=status,  # type: ignore[arg-type]
        blocks=(
            TravelBlock(
                kind="documenti",
                title="Documenti",
                sentences=(TravelSentence(text="Frase.", origins=("EU",), source_ids=("s1",)),),
            ),
        ),
        sources=(
            TravelSource(
                id="s1", citation="Fonte: x", url="https://example.com/s", checked_on=checked_on
            ),
        ),
    )


def _checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "check_viaggi", ROOT / "scripts" / "manuale" / "check_viaggi.py"
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_a_card_warns_after_90_days_and_hides_after_180() -> None:
    assert _card(TODAY - timedelta(days=OLD_AFTER_DAYS)).visibility(TODAY) == "fresh"
    assert _card(TODAY - timedelta(days=OLD_AFTER_DAYS + 1)).visibility(TODAY) == "old"
    assert _card(TODAY - timedelta(days=HIDDEN_AFTER_DAYS)).visibility(TODAY) == "old"
    assert _card(TODAY - timedelta(days=HIDDEN_AFTER_DAYS + 1)).visibility(TODAY) == "hidden"


def test_the_service_sends_the_content_of_a_fresh_card() -> None:
    service = ListTravelCardsService([_card(TODAY)], today=lambda: TODAY)

    [payload] = service.execute()

    assert payload["visibility"] == "fresh"
    assert payload["country"] == "XX" and payload["species"] == "dog"
    blocks = payload["blocks"]
    assert isinstance(blocks, list) and blocks[0]["sentences"][0]["origins"] == ["EU"]
    assert payload["sources"]


def test_a_hidden_card_keeps_only_the_link_to_the_official_source() -> None:
    old = _card(TODAY - timedelta(days=HIDDEN_AFTER_DAYS + 1))

    [payload] = ListTravelCardsService([old], today=lambda: TODAY).execute()

    assert payload["visibility"] == "hidden"
    assert payload["official_url"] == "https://example.com/official"
    assert "blocks" not in payload and "sources" not in payload


def test_drafts_are_never_loaded_unless_asked(tmp_path: Path) -> None:
    rows = [_card(TODAY).model_dump(mode="json"), _card(TODAY, "draft").model_dump(mode="json")]
    path = tmp_path / "cards.json"
    path.write_text(json.dumps(rows), encoding="utf-8")

    assert [c.status for c in load_travel_cards(path)] == ["approved"]
    assert len(load_travel_cards(path, include_drafts=True)) == 2


def test_the_missing_file_is_an_empty_set(tmp_path: Path) -> None:
    assert load_travel_cards(tmp_path / "nope.json") == []


def test_the_repository_cards_pass_the_check_and_the_export_is_up_to_date() -> None:
    checker = _checker()
    registry = json.loads((ROOT / "data/manuale/fonti.json").read_text("utf-8"))
    sources = {str(s["id"]): s for s in registry}
    errors: list[str] = []
    for path in checker.card_paths():
        card_errors, _ = checker.check_card(
            path, json.loads(path.read_text("utf-8")), sources, TODAY
        )
        errors += card_errors

    assert errors == []
    assert json.loads(TRAVEL_CARDS_FILE.read_text("utf-8")) == checker.export_cards()


@pytest.mark.parametrize(
    "text",
    ["Dai 5 mg per kg.", "Usa Frontline prima di partire.", "Fai il corso per il patentino."],
)
def test_the_check_refuses_doses_products_and_forbidden_words(text: str) -> None:
    checker = _checker()
    block = {"tipo": "farmaci_e_protezioni", "frasi": [{"testo": text, "nostro": True}]}

    errors, _ = checker.check_card(Path("x.json"), {**CARD, "blocchi": [block]}, {}, TODAY)

    assert errors


def test_a_titre_threshold_is_not_taken_for_a_dose() -> None:
    checker = _checker()
    sentence = {"testo": "Almeno 0,5 UI/ml.", "nostro": True}
    block = {"tipo": "test_sierologici", "frasi": [sentence]}

    errors, _ = checker.check_card(Path("x.json"), {**CARD, "blocchi": [block]}, {}, TODAY)

    assert errors == []


def test_a_number_of_days_blocks_the_approval_until_it_is_read_by_hand() -> None:
    checker = _checker()
    sources = {
        "s": {"semaforo": "verde", "motivo_semaforo": "licenza_aperta", "controllo_a_mano_il": None}
    }
    sentence: dict[str, object] = {
        "testo": "Aspetta 21 giorni.",
        "fonti": [{"id": "s", "punto": "p"}],
    }
    card = {**CARD, "blocchi": [{"tipo": "vaccini_obbligatori", "frasi": [sentence]}]}

    errors, warnings = checker.check_card(Path("x.json"), card, sources, TODAY)
    assert not errors and any("a mano" in w for w in warnings)

    review = {"proprietario": "2026-11-17", "chi_ha_letto": ["x"]}
    approved = {**card, "stato": "rivista", "revisione": review}
    errors, _ = checker.check_card(Path("x.json"), approved, sources, TODAY)
    assert any("a mano" in e for e in errors)

    sentence["letto_a_mano"] = {"da": "x", "il": "2026-11-17"}
    errors, _ = checker.check_card(Path("x.json"), approved, sources, TODAY)
    assert not errors


def test_a_red_source_not_read_by_hand_is_refused() -> None:
    checker = _checker()
    sources = {
        "r": {
            "semaforo": "rosso",
            "motivo_semaforo": "blocco_tecnico",
            "controllo_a_mano_il": None,
            "lettura_eseguita": "automatica",
        }
    }
    sentence = {"testo": "Serve il microchip.", "fonti": [{"id": "r", "punto": "p"}]}
    card = {**CARD, "blocchi": [{"tipo": "microchip", "frasi": [sentence]}]}

    errors, _ = checker.check_card(Path("x.json"), card, sources, TODAY)

    assert any("rossa" in e for e in errors)
