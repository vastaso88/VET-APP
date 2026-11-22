"""Findings of a round are merged into cards; villain cards never carry the steps; the
coverage matrix of the 17 testers has no holes."""

from __future__ import annotations

import json
from pathlib import Path

from scripts.collaudo import persone, riassunto
from scripts.collaudo.segnalazioni import Segnalazione, aggiungi


def _item(chat: str, titolo: str, gravita: str = "fastidio", **extra: object) -> Segnalazione:
    return Segnalazione(
        chat=chat,
        giro="1",
        tipo=str(extra.pop("tipo", "funzioni")),
        gravita=gravita,
        titolo=titolo,
        cosa_succede="succede",
        funzione=str(extra.pop("funzione", "chat")),
        **extra,  # type: ignore[arg-type]
    )


def test_doubles_are_merged_with_the_highest_severity_and_every_tester() -> None:
    cards = riassunto.unisci(
        [
            _item("col-a", "La risposta sul geco è troppo lunga"),
            _item("col-b", "La risposta sul geco e' troppo lunga!", gravita="grave"),
            _item("col-a", "La risposta sul geco è troppo lunga"),
            _item("col-c", "Il pulsante Invia è nascosto", funzione="chat"),
        ]
    )
    assert len(cards) == 2
    first = cards[0]
    assert first.gravita == "grave" and first.chi == ["col-a", "col-b"] and first.volte == 3


def test_same_title_in_another_function_is_not_a_double() -> None:
    cards = riassunto.unisci(
        [
            _item("a", "Troppo lento", funzione="chat"),
            _item("b", "Troppo lento", funzione="radar_luoghi"),
        ]
    )
    assert len(cards) == 2


def test_cards_are_ordered_by_severity_and_only_15_are_highlighted() -> None:
    items = [
        _item(f"c{i}", f"Problema numero {i} diverso {i * 7}", funzione=f"f{i}") for i in range(20)
    ]
    items.append(_item("z", "Si blocca tutto", gravita="bloccante", funzione="zz"))
    cards = riassunto.unisci(items)
    assert cards[0].gravita == "bloccante"
    assert sum(card.in_evidenza for card in cards) == 15


def test_abuse_cards_on_the_page_keep_the_risk_but_never_the_steps() -> None:
    card = riassunto.unisci(
        [_item("col-villain-traffico", "Rischio", tipo="abuso", come_riprodurre=["passo segreto"])]
    )[0]
    assert card.come_riprodurre == ["passo segreto"]
    assert card.per_pagina()["come_riprodurre"] == []


def test_a_round_folder_becomes_cards_summary_and_timings(tmp_path: Path) -> None:
    folder = tmp_path / "giro-1"
    aggiungi(folder / "col-a" / "segnalazioni.jsonl", _item("col-a", "Titolo A", gravita="grave"))
    (folder / "col-b").mkdir(parents=True)
    (folder / "col-b" / "segnalazioni.jsonl").write_text("{rotto\n", encoding="utf-8")
    (folder / "col-a" / "tempi.jsonl").write_text(
        "\n".join(
            json.dumps({"metodo": "POST", "percorso": "/chat", "total_ms": ms})
            for ms in (1000, 2000, 30000)
        ),
        encoding="utf-8",
    )
    (folder / "col-a" / "risposte.jsonl").write_text(
        json.dumps({"secondi_server": 25.0, "secondi_lettura": 12.0}) + "\n", encoding="utf-8"
    )

    riassunto.scrivi("1", root=tmp_path)

    cards = json.loads((folder / "schede.json").read_text("utf-8"))
    assert [c["titolo"] for c in cards] == ["Titolo A"]
    assert "col-b/segnalazioni.jsonl:1" in (folder / "problemi.txt").read_text("utf-8")
    summary = (folder / "riassunto.md").read_text("utf-8")
    assert "oltre 20 s: 1" in summary and "POST /chat" in summary


def test_the_17_testers_cover_every_species_group_and_function_twice() -> None:
    data = persone.carica()
    assert len(data["persone"]) == 17
    assert persone.buchi(data) == []
    kinds = [p["tipo"] for p in data["persone"]]
    assert kinds.count("funzionale") == 9 and kinds.count("villain") == 2
    assert kinds.count("estetica") == 6


def test_models_follow_the_plan_and_names_start_with_col() -> None:
    data = persone.carica()
    for item in data["persone"]:
        assert item["chat"].startswith("col-")
        expected = "opus" if item["chat"] == "col-est-artdirector" else "sonnet"
        assert item["modello"] == expected and item["sforzo"] == "high"


def test_villain_material_is_not_in_the_repository_data() -> None:
    raw = persone.PERSONE_FILE.read_text(encoding="utf-8").lower()
    assert "copione" not in raw.replace("i copioni dei villain non stanno qui", "")
    for item in persone.carica()["persone"]:
        if item["tipo"] == "villain":
            assert set(item) <= {
                "chat",
                "tipo",
                "lingua",
                "profilo",
                "funzioni",
                "account_extra",
                "animali",
                "modello",
                "sforzo",
            }
