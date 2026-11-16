"""Checks the travel cards of "Around the world" in ``data/manuale/viaggi/``
(docs/product/18, docs/compliance/17 parte A).

Same shape as the health cards (``check_manuale.py``): every sentence names its source and the
exact place in it, unless it is flagged ``"nostro": true`` (at most 3 per card). On top of that:

* only dog, cat and ferret, non-commercial travel (``tipo_viaggio``);
* ``scadenza`` is ``ultimo_controllo`` + 90 days (the app warns after 90, hides after 180);
* a sentence with a number of days, weeks, hours, months, years or animals carries
  ``letto_a_mano`` (who read it in the act in force, and when) before the card can be
  approved: until then it is a draft and the check says so;
* a source on the red light may be used only if it was read by hand;
* no dose, no product or brand name, none of the words the owner must never read;
* a card is ``rivista`` or ``pubblicata`` only with the owner's date and the register of who
  verified it (``revisione.chi_ha_letto``).

Standard library only. Run: ``python scripts/manuale/check_viaggi.py``.
``--esporta`` writes data/manuale/viaggi/travel_cards.json (what the backend serves);
``--approvazione`` writes docs/product/19_schede_viaggio_da_approvare.md.
Exit code 1 if any error; warnings do not fail.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date, timedelta
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_manuale as manuale  # noqa: E402  (sibling script, not a package)

DATA = manuale.DATA
TRAVEL = DATA / manuale.TRAVEL_DIR
EXPORT_PATH = TRAVEL / "travel_cards.json"
REVIEW_DOC = manuale.ROOT / "docs" / "product" / "19_schede_viaggio_da_approvare.md"

OLD_AFTER_DAYS = 90  # packages/core/domain/travel/cards.py
SPECIES = {"cane": "dog", "gatto": "cat", "furetto": "ferret"}
ORIGINS = {"UE": "EU", "fuori_UE": "non_EU"}
MOTIVES = (
    "licenza_aperta",
    "nessuna_riserva_trovata",
    "riserva_presente",
    "blocco_tecnico",
    "non_verificata",
)
BLOCKS = {
    "documenti": "Documenti",
    "microchip": "Microchip",
    "vaccini_obbligatori": "Vaccini obbligatori",
    "test_sierologici": "Test degli anticorpi",
    "vaccini_consigliati": "Vaccini consigliati",
    "malattie_presenti": "Malattie presenti",
    "farmaci_e_protezioni": "Farmaci e protezioni",
    "comportamenti_e_norme": "Comportamenti e norme del posto",
    "rientro": "Rientro",
    "non_diffondere": "Per non diffondere malattie",
    "quando_andare_dal_veterinario": "Dal veterinario",
    "limiti": "Cosa questa scheda non copre",
}
# Numbers that only count once someone has read them in the act in force (docs/compliance/17).
TIMED_NUMBER = re.compile(
    r"\b\d+(?:[.,]\d+)?\s?(?:giorn[oi]|settiman[ae]|or[ae]|mes[ei]|ann[oi]|animali|ui/ml)\b"
    r"|\b\d+(?:[.,]\d+)?\s?(?:-|e|a)\s?\d+\s?(?:giorn[oi]|settiman[ae]|or[ae]|mes[ei])\b",
    re.IGNORECASE,
)
# The titre threshold is a laboratory value, not a dose: the dose check skips this block.
DOSE_EXEMPT_BLOCK = "test_sierologici"
# Brands and active substances of the antiparasitic and rabies products: never named.
PRODUCTS = re.compile(
    r"\b(?:frontline|nexgard|bravecto|advocate|advantix|stronghold|drontal|milbemax|simparica"
    r"|seresto|scalibor|credelio|revolution|praziquantel|milbemicina|nobivac|canvac"
    r"|eurican|versiguard|purevax)\w*",
    re.IGNORECASE,
)


def _load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def card_paths() -> list[Path]:
    return sorted(TRAVEL.glob("VIA-*.json"))


def check_card(
    path: Path, card: dict[str, Any], sources: dict[str, dict[str, Any]], today: date
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    code = str(card.get("codice", path.name))
    label = f"scheda {code}"
    for field in ("codice", "paese", "specie", "titolo", "stato", "pagina_ufficiale", "blocchi"):
        if not card.get(field):
            errors.append(f"{label}: manca '{field}'")
    country = str(card.get("paese", ""))
    if country and not (len(country) == 2 and country.isupper()):
        errors.append(f"{label}: 'paese' deve essere un codice ISO a 2 lettere (EU per la UE)")
    if card.get("specie") not in SPECIES:
        errors.append(f"{label}: specie '{card.get('specie')}' non ammessa (cane, gatto, furetto)")
    elif code != f"VIA-{country}-{str(card['specie'])[:3].upper()}":
        warnings.append(f"{label}: il codice non segue VIA-<paese>-<specie a 3 lettere>")
    if card.get("tipo_viaggio") != "non_commerciale":
        errors.append(f"{label}: tipo_viaggio deve essere 'non_commerciale' (A.1 della Normativa)")
    if card.get("stato") not in manuale.STATES:
        errors.append(f"{label}: stato '{card.get('stato')}' non ammesso")
    if not manuale._is_date(card.get("ultimo_controllo")):
        errors.append(f"{label}: ultimo_controllo non è una data AAAA-MM-GG")
    else:
        checked = date.fromisoformat(card["ultimo_controllo"])
        if card.get("scadenza") != (checked + timedelta(days=OLD_AFTER_DAYS)).isoformat():
            errors.append(
                f"{label}: scadenza deve essere ultimo_controllo + {OLD_AFTER_DAYS} giorni"
            )
        elif checked + timedelta(days=OLD_AFTER_DAYS) < today:
            warnings.append(f"{label}: scaduta il {card['scadenza']}: la app mostra l'avviso")
    review = card.get("revisione") or {}
    approved = card.get("stato") in ("rivista", "pubblicata")
    if approved and not manuale._is_date(review.get("proprietario")):
        errors.append(f"{label}: stato '{card['stato']}' senza data di revisione del proprietario")
    if approved and not review.get("chi_ha_letto"):
        errors.append(f"{label}: stato '{card['stato']}' senza il registro di chi ha verificato")

    own = 0
    used: set[str] = set()
    seen_blocks: set[str] = set()
    for block in card.get("blocchi", []):
        kind = block.get("tipo")
        if kind not in BLOCKS:
            errors.append(f"{label}: blocco '{kind}' non ammesso")
        if kind in seen_blocks:
            errors.append(f"{label}: blocco '{kind}' ripetuto")
        seen_blocks.add(str(kind))
        sentences = block.get("frasi") or []
        if not sentences:
            errors.append(f"{label}: blocco '{kind}' vuoto")
        for index, sentence in enumerate(sentences, 1):
            where = f"{label} {kind} #{index}"
            text = str(sentence.get("testo", ""))
            refs = sentence.get("fonti") or []
            if not text:
                errors.append(f"{where}: frase vuota")
            if sentence.get("nostro"):
                own += 1
            elif not refs and kind != "limiti":
                errors.append(f"{where}: frase senza fonte (un fatto, una fonte)")
            for origin in sentence.get("origine", []):
                if origin not in ORIGINS:
                    errors.append(f"{where}: origine '{origin}' non ammessa (UE, fuori_UE)")
            for ref in refs:
                sid = str(ref.get("id", ""))
                used.add(sid)
                if sid not in sources:
                    errors.append(f"{where}: fonte '{sid}' non presente in fonti.json")
                if not ref.get("punto"):
                    errors.append(f"{where}: fonte '{sid}' senza il punto esatto")
            if TIMED_NUMBER.search(text):
                hand = sentence.get("letto_a_mano") or {}
                if not (hand.get("da") and manuale._is_date(hand.get("il"))):
                    message = f"{where}: numero da verificare a mano nell'atto in vigore"
                    (errors if approved else warnings).append(message)
            if kind != DOSE_EXEMPT_BLOCK and manuale.DOSE.search(text):
                errors.append(f"{where}: sembra una dose, mai nelle schede: {text[:60]}")
            if PRODUCTS.search(text):
                errors.append(f"{where}: nome di prodotto o sostanza, mai nelle schede")
            for pattern in manuale.FORBIDDEN:
                if pattern.search(text):
                    errors.append(f"{where}: parola vietata ({pattern.pattern})")
    if own > 3:
        warnings.append(f"{label}: {own} consigli «nostri» (senza fonte): al massimo 3")
    for sid in sorted(used & set(sources)):
        source = sources[sid]
        if source.get("motivo_semaforo") not in MOTIVES:
            errors.append(f"{label}: fonte '{sid}' senza 'motivo_semaforo' valido")
        if source.get("semaforo") == "rosso" and not str(
            source.get("lettura_eseguita", "")
        ).startswith("a mano"):
            errors.append(f"{label}: fonte rossa '{sid}' non letta a mano: non si usa")
        if "controllo_a_mano_il" not in source:
            errors.append(f"{label}: fonte '{sid}' senza il campo 'controllo_a_mano_il'")
    return errors, warnings


def _sentence_sources(card: dict[str, Any]) -> list[str]:
    ids: list[str] = []
    for block in card["blocchi"]:
        for sentence in block["frasi"]:
            for ref in sentence.get("fonti", []):
                if ref["id"] not in ids:
                    ids.append(ref["id"])
    return ids


def export_cards() -> list[dict[str, Any]]:
    sources = {str(s["id"]): s for s in _load(DATA / "fonti.json")}
    records: list[dict[str, Any]] = []
    for path in card_paths():
        card = _load(path)
        ids = _sentence_sources(card)
        records.append(
            {
                "id": card["codice"].lower(),
                "country": card["paese"],
                "species": SPECIES[card["specie"]],
                "title": card["titolo"],
                "checked_on": card["ultimo_controllo"],
                "official_url": card["pagina_ufficiale"],
                "status": "approved" if card["stato"] in ("rivista", "pubblicata") else "draft",
                "blocks": [
                    {
                        "kind": block["tipo"],
                        "title": BLOCKS[block["tipo"]],
                        "sentences": [
                            {
                                "text": sentence["testo"],
                                "origins": [ORIGINS[o] for o in sentence.get("origine", [])],
                                "own": bool(sentence.get("nostro")),
                                "source_ids": [r["id"] for r in sentence.get("fonti", [])],
                            }
                            for sentence in block["frasi"]
                        ],
                    }
                    for block in sorted(
                        card["blocchi"], key=lambda b: list(BLOCKS).index(b["tipo"])
                    )
                ],
                "sources": [
                    {
                        "id": sid,
                        "citation": manuale.source_line(sources[sid]),
                        "url": sources[sid]["url"],
                        "checked_on": sources[sid]["controllata_il"],
                    }
                    for sid in ids
                ],
            }
        )
    return records


def write_export() -> int:
    records = export_cards()
    EXPORT_PATH.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + chr(10), encoding="utf-8"
    )
    for record in records:
        sentences = sum(len(b["sentences"]) for b in record["blocks"])
        print(f"{record['id']}: {sentences} frasi, {record['status']}")
    return 0


def write_review_doc() -> int:
    """The owner's approval document for the travel cards."""
    sources = {str(s["id"]): s for s in _load(DATA / "fonti.json")}
    cards = [_load(p) for p in card_paths()]
    out = [
        "# Schede di viaggio («Around the world») da approvare",
        "",
        "Generato da `python scripts/manuale/check_viaggi.py --approvazione`. "
        f"{len(cards)} schede, tutte in bozza: l'app le mostrerà solo dopo la tua approvazione.",
        "Per ogni scheda rispondimi in chat con il codice e una di queste parole: **ok**, "
        "**correggi** con cosa cambiare, oppure **togli**. Esempio: `VIA-GB-CAN ok`.",
        "",
        "**Come leggere**: ogni frase ha la fonte e il punto esatto. Le frasi segnate "
        "**[DA VERIFICARE A MANO]** contengono un numero (giorni, settimane, ore, mesi, animali) "
        "letto dalle pagine della Commissione europea o di GOV.UK, ma **non ancora controllato "
        "nel testo dell'atto in vigore** (su EUR-Lex): finché una persona non lo fa e non lo "
        "annota, la scheda non può essere approvata. Origine: **UE** = si parte da un paese UE; "
        "**fuori UE** = si parte da un paese non UE; senza etichetta vale per tutti.",
        "",
        "---",
        "",
    ]
    for card in cards:
        out.append(f"## {card['codice']} · {card['specie']} · {card['titolo']}")
        out.append("")
        out.append(
            f"*Controllata il {card['ultimo_controllo']} · scade (avviso) il {card['scadenza']}*"
        )
        out.append("")
        for block in sorted(card["blocchi"], key=lambda b: list(BLOCKS).index(b["tipo"])):
            out.append(f"**{BLOCKS[block['tipo']]}**")
            for sentence in block["frasi"]:
                tags = []
                if sentence.get("origine"):
                    tags.append("/".join(o.replace("_", " ") for o in sentence["origine"]))
                if sentence.get("nostro"):
                    tags.append("consiglio di Quokka, non della fonte")
                if TIMED_NUMBER.search(sentence["testo"]) and not sentence.get("letto_a_mano"):
                    tags.append("DA VERIFICARE A MANO")
                prefix = f"[{'; '.join(tags)}] " if tags else ""
                where = "; ".join(f"{r['id']}: {r['punto']}" for r in sentence.get("fonti", []))
                out.append(f"- {prefix}{sentence['testo']}" + (f" _({where})_" if where else ""))
            out.append("")
        ids = _sentence_sources(card)
        out.append("> " + "<br>".join(manuale.source_line(sources[i]) for i in ids))
        out.append("")
        out.append("Esito: ☐ ok  ☐ correggi  ☐ togli")
        out.append("")
        out.append("---")
        out.append("")
    REVIEW_DOC.write_text(chr(10).join(out), encoding="utf-8")
    print(f"{len(cards)} schede scritte in {REVIEW_DOC}")
    return 0


def main() -> int:
    if "--esporta" in sys.argv:
        return write_export()
    if "--approvazione" in sys.argv:
        return write_review_doc()
    sources_path = DATA / "fonti.json"
    sources = {str(s["id"]): s for s in _load(sources_path)}
    today = date.today()
    errors: list[str] = []
    warnings: list[str] = []
    cards = card_paths()
    for path in cards:
        card_errors, card_warnings = check_card(path, _load(path), sources, today)
        errors += card_errors
        warnings += card_warnings
    for path in cards:
        card = _load(path)
        if manuale._is_date(card.get("scadenza")):
            left = (date.fromisoformat(card["scadenza"]) - today).days
            if 0 <= left <= 30:
                warnings.append(
                    f"scheda {card['codice']}: scade tra {left} giorni, da ricontrollare"
                )
    for line in warnings:
        print("avviso:", line)
    for line in errors:
        print("ERRORE:", line)
    print(f"{len(cards)} schede di viaggio, {len(errors)} errori, {len(warnings)} avvisi")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
