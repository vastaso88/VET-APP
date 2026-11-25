"""Note prodotto del Cercafonti: controlli prima e dopo la lettura della pagina."""

from __future__ import annotations

from typing import Any

from scripts.sources import product_notes as P

HOSTS = {"example.com": {"uso": "fatti"}, "chiuso.example": {"uso": "no", "nota": "vieta"}}


def _spec(**kw: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "id": "x",
        "product": "Calcio Esempio",
        "maker": "Casa Esempio",
        "species": ["reptile_amphibian"],
        "words": ["calcio"],
        "says": "Una misurina da 1 g ogni 250 ml di acqua.",
        "source_kind": "manufacturer",
        "source_url": "https://example.com/calcio",
        "frase_prova": "1 g in 250 ml of water",
    }
    return {**base, **kw}


def test_valid_spec_has_no_problems() -> None:
    assert P.spec_problems(_spec(), HOSTS) == []


def test_refused_specs() -> None:
    for change in (
        {"source_kind": "forum"},
        {"source_url": "http://example.com/x"},
        {"source_url": "https://www.reddit.com/r/x"},
        {"product": "Antibiotico Esempio"},
        {"species": ["horse"]},
        {"frase_prova": "una frase " * 20},
        {"frase_prova": "nessuna cifra qui"},
        {"source_url": "https://chiuso.example/x"},
        {"source_url": "https://altro.example/x"},
        {"says": "Previene il rachitismo: 1 g in 250 ml."},
        {"says": "1 g per kg di peso in 250 ml."},
        {"says": "Solo 9,90 € in offerta: 1 g in 250 ml."},
    ):
        assert P.spec_problems(_spec(**change), HOSTS), change


def test_page_must_have_proof_phrase_and_every_figure() -> None:
    page = "Dosage: 1 g in 250 ml of water, daily."
    assert P.page_problems(_spec(), page) == []
    assert P.page_problems(_spec(says="2 g al giorno."), page)
    assert P.page_problems(_spec(frase_prova="3 g in 9 ml"), page)


def test_source_line_follows_the_normativa_wording() -> None:
    line = P.source_line(_spec(mercato="Stati Uniti"), "2026-11-25")
    assert line.startswith("Fonte: Casa Esempio, Calcio Esempio, pagina letta il 2026-11-25")
    assert line.endswith("fatti riassunti da Quokka. Etichetta per il mercato: Stati Uniti.")
    dated = P.source_line(_spec(scheda_data="2026-03-01", versione="2"), "2026-11-25")
    assert "scheda del 2026-03-01 (versione 2)" in dated
