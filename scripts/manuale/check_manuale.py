"""Checks the owner-awareness cards in ``data/manuale/`` (docs/product/13, 15).

Rules enforced (docs/product/13 §2, §3):

* every sentence of a card names at least one source and the exact place in it, unless it
  is flagged ``"nostro": true`` (Quokka's own advice, shown as such, at most 3 per card);
* every source named exists in ``fonti.json`` and carries who/year/where/when checked;
* a source "read as summary only" is flagged, not silently trusted;
* no word the owner must never read in a public text (docs/product/11 §3);
* a card is ``rivista`` or ``pubblicata`` only with the owner's review date;
* cards past their expiry date are reported.

Standard library only. Run: ``python scripts/manuale/check_manuale.py``.
Exit code 1 if any error; warnings do not fail. ``--righe`` prints the "Fonte" lines.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "manuale"

STATES = ("bozza", "fonti_controllate", "rivista", "pubblicata")
OPEN_HOW = ("testo_completo", "solo_riassunto", "solo_scheda_bibliografica")
SOURCE_TYPES = (
    "linea_guida",
    "guida_ufficiale",
    "posizione",
    "studio",
    "revisione",
    "norma",
    "manuale",
    "scheda_ente",
)
BLOCKS = (
    "in_breve",
    "cosa_sapere",
    "cosa_osservare",
    "quando_andare_dal_veterinario",
    "cosa_non_fare",
    "limiti",
)
CHAT_SUMMARY_MAX = 1600

# docs/product/11 §3.1 (same patterns as scripts/eval/chat_quality/scenarios_awareness.py).
FORBIDDEN = tuple(
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"(?<!in )(?<!nel )(?<!del )cors[oi]",
        r"\bformazione\b",
        r"\blezion[ei]\b",
        r"\battestat\w*",
        r"\bpatentin\w*",
        r"\bpromozione\b",
        r"veterinario virtuale",
        r"come un veterinario",
        r"\bsuperare (?:un |l')esam[ei]\b",
    )
)
# Doses are never part of a card (docs/product/13 §2.1).
DOSE = re.compile(r"\b\d+(?:[.,]\d+)?\s?(?:mg|ml|mcg|µg|ui|iu)\b(?:\s?/\s?kg)?", re.IGNORECASE)


def _load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _is_date(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


def check_sources(sources: list[dict[str, Any]]) -> tuple[dict[str, dict[str, Any]], list[str]]:
    errors: list[str] = []
    by_id: dict[str, dict[str, Any]] = {}
    for src in sources:
        sid = str(src.get("id", ""))
        label = f"fonte {sid or '?'}"
        if not sid or sid in by_id:
            errors.append(f"{label}: id mancante o duplicato")
            continue
        by_id[sid] = src
        for field in ("ente_autori", "titolo", "url", "controllata_il", "come_aperta", "tipo"):
            if not src.get(field):
                errors.append(f"{label}: manca '{field}'")
        if not isinstance(src.get("anno"), int):
            errors.append(f"{label}: manca l'anno (numero)")
        if src.get("livello") not in (1, 2, 3):
            errors.append(f"{label}: 'livello' deve essere 1, 2 o 3")
        if src.get("tipo") and src["tipo"] not in SOURCE_TYPES:
            errors.append(f"{label}: tipo '{src['tipo']}' non ammesso")
        if src.get("come_aperta") and src["come_aperta"] not in OPEN_HOW:
            errors.append(f"{label}: come_aperta '{src['come_aperta']}' non ammesso")
        if src.get("controllata_il") and not _is_date(src["controllata_il"]):
            errors.append(f"{label}: controllata_il non è una data AAAA-MM-GG")
        if src.get("tipo") in ("studio", "revisione") and not (src.get("doi") or src.get("pmid")):
            errors.append(f"{label}: uno studio ha bisogno di DOI o PMID")
        if src.get("semaforo") not in ("verde", "giallo", "rosso"):
            errors.append(f"{label}: manca 'semaforo' (verde, giallo, rosso)")
        if not src.get("riserva_estrazione_automatica"):
            errors.append(f"{label}: manca 'riserva_estrazione_automatica'")
        rights = src.get("diritti")
        if not isinstance(rights, dict) or not rights.get("stato"):
            errors.append(f"{label}: manca diritti.stato")
    return by_id, errors


def check_card(
    path: Path, card: dict[str, Any], sources: dict[str, dict[str, Any]], today: date
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    code = str(card.get("codice", path.name))
    label = f"scheda {code}"
    for field in ("codice", "specie", "area", "argomento", "titolo", "stato", "blocchi"):
        if not card.get(field):
            errors.append(f"{label}: manca '{field}'")
    if card.get("stato") not in STATES:
        errors.append(f"{label}: stato '{card.get('stato')}' non ammesso")
    if not _is_date(card.get("ultimo_controllo")):
        errors.append(f"{label}: ultimo_controllo non è una data AAAA-MM-GG")
    if _is_date(card.get("scadenza")) and date.fromisoformat(card["scadenza"]) < today:
        warnings.append(f"{label}: scaduta il {card['scadenza']}")
    review = card.get("revisione") or {}
    if card.get("stato") in ("rivista", "pubblicata") and not _is_date(review.get("proprietario")):
        errors.append(f"{label}: stato '{card['stato']}' senza data di revisione del proprietario")
    summary = card.get("riassunto_per_chat", "")
    if not summary:
        errors.append(f"{label}: manca riassunto_per_chat")
    elif len(summary) > CHAT_SUMMARY_MAX:
        errors.append(
            f"{label}: riassunto_per_chat di {len(summary)} caratteri (max {CHAT_SUMMARY_MAX})"
        )

    texts: list[str] = [str(card.get("titolo", "")), str(summary)]
    used: set[str] = set()
    own = sum(
        1
        for block in card.get("blocchi", [])
        for sent in block.get("frasi", [])
        if sent.get("nostro")
    )
    if own > 3:
        warnings.append(f"{label}: {own} consigli «nostri» (senza fonte): meglio al massimo 3")
    for block in card.get("blocchi", []):
        kind = block.get("tipo")
        if kind not in BLOCKS:
            errors.append(f"{label}: blocco '{kind}' non ammesso")
        sentences = block.get("frasi") or []
        if not sentences:
            errors.append(f"{label}: blocco '{kind}' vuoto")
        for index, sentence in enumerate(sentences, 1):
            where = f"{label} {kind} #{index}"
            text = str(sentence.get("testo", ""))
            texts.append(text)
            refs = sentence.get("fonti") or []
            if not text:
                errors.append(f"{where}: frase vuota")
            if not refs and kind != "limiti" and not sentence.get("nostro"):
                errors.append(f"{where}: frase senza fonte")
            for ref in refs:
                sid = str(ref.get("id", ""))
                used.add(sid)
                if sid not in sources:
                    errors.append(f"{where}: fonte '{sid}' non presente in fonti.json")
                if not ref.get("punto"):
                    errors.append(f"{where}: fonte '{sid}' senza il punto esatto (sezione/pagina)")
                elif sid in sources and sources[sid].get("come_aperta") != "testo_completo":
                    warnings.append(
                        f"{where}: '{sid}' letta solo come {sources[sid].get('come_aperta')}"
                    )

    for text in texts:
        for pattern in FORBIDDEN:
            if pattern.search(text):
                errors.append(f"{label}: parola vietata ({pattern.pattern}) in: {text[:60]}")
        if DOSE.search(text):
            errors.append(f"{label}: sembra una dose, mai nelle schede: {text[:60]}")

    worst = max((int(sources[s]["livello"]) for s in used if s in sources), default=0)
    if card.get("livello_schede") not in (None, worst):
        warnings.append(
            f"{label}: livello dichiarato {card.get('livello_schede')}, "
            f"ma le fonti arrivano a {worst}"
        )
    return errors, warnings


def source_line(source: dict[str, Any]) -> str:
    """The "Fonte" line shown under a card (docs/compliance/13 §6)."""
    where = ", ".join(
        part
        for part in (
            str(source.get("ente_autori", "")),
            str(source.get("titolo", "")),
            str(source.get("rivista", "")),
            str(source.get("anno", "")),
            f"https://doi.org/{source['doi']}" if source.get("doi") else str(source.get("url", "")),
        )
        if part
    )
    line = (
        f"Fonte: {where}. Riassunto di Quokka, verificato il {source.get('controllata_il', '?')}."
    )
    state = str(source.get("diritti", {}).get("stato", ""))
    if state.startswith("cc_by"):
        line += " Licenza CC BY; modificato da Quokka."
    return line


def print_source_lines() -> int:
    """``--righe``: the "Fonte" lines of every card, from the source registry."""
    sources = {str(s["id"]): s for s in _load(DATA / "fonti.json")}
    for path in sorted(p for p in DATA.glob("*/*.json") if p.parent.name != "_schema"):
        card = _load(path)
        ids: list[str] = []
        for block in card.get("blocchi", []):
            for sentence in block.get("frasi", []):
                for ref in sentence.get("fonti", []):
                    if ref["id"] not in ids:
                        ids.append(ref["id"])
        print(f"## {card['codice']} {card['titolo']}")
        for sid in ids:
            print("-", source_line(sources[sid]))
    return 0


def main() -> int:
    if "--righe" in sys.argv:
        return print_source_lines()
    sources_path = DATA / "fonti.json"
    if not sources_path.exists():
        print("data/manuale/fonti.json non trovato")
        return 1
    sources, errors = check_sources(_load(sources_path))
    warnings: list[str] = []
    cards = sorted(p for p in DATA.glob("*/*.json") if p.parent.name != "_schema")
    today = date.today()
    for path in cards:
        card_errors, card_warnings = check_card(path, _load(path), sources, today)
        errors += card_errors
        warnings += card_warnings
    unused = set(sources)
    for path in cards:
        for block in _load(path).get("blocchi", []):
            for sentence in block.get("frasi", []):
                for ref in sentence.get("fonti", []):
                    unused.discard(str(ref.get("id", "")))
    for sid in sorted(unused):
        warnings.append(f"fonte {sid}: nessuna scheda la usa")
    for line in warnings:
        print("avviso:", line)
    for line in errors:
        print("ERRORE:", line)
    print(
        f"{len(cards)} schede, {len(sources)} fonti, {len(errors)} errori, {len(warnings)} avvisi"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
