"""Seconda lettura di pertinenza (passo fisso, Normativa 22/11).

Un altro modello legge i testi già scaricati e dice, per ogni fonte, quali specie e temi tratta
davvero e se è adatta a un proprietario. Non tocca i diritti (le classi V/VR/G/R/N restano della
griglia) e non contatta siti: lavora solo sui testi salvati dal Fetcher. Vie ammesse, in ordine:
un secondo modello dello stesso fornitore già in uso; l'API a pagamento di Google (chiave solo in
variabile d'ambiente); a mano, a lotti piccoli.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from scripts.sources.store import Store

MAX_CHARS = 5500
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
_PHONE = re.compile(r"(?<!\w)(?:\+?\d[\d ()./-]{7,}\d)(?!\w)")

INSTRUCTIONS = (
    "Ti do un file con documenti numerati: pagine pubbliche di enti ufficiali, già scaricate. "
    "Lavora SOLO sul testo: non aprire siti, non cercare, non inventare (se il testo non lo dice, "
    "scrivi non indicato). Per OGNI documento rispondi con una riga JSON: "
    '{"n": numero, "specie": [codici S che il testo nomina davvero], "temi": [codici T che il '
    'testo tratta davvero], "per_proprietari": true/false, "adatto": true/false, "perche": '
    '"una frase in italiano semplice"}. Specie: S01 cani, S02 gatti, S03 conigli, S04 cavie e '
    "cincillà, S05 piccoli roditori, S06 furetti, S07 uccelli da gabbia, S08 rettili, S09 "
    "testuggini e tartarughe, S10 anfibi, S11 pesci d'acqua dolce, S12 acquario marino. Temi: "
    "T01 alimentazione, T02 ambiente e alloggio, T03 cura quotidiana, T04 comportamento e "
    "convivenza, T05 prevenzione, T06 segni di malattia e quando andare dal veterinario, T07 "
    "cose tossiche e pericolose, T08 cuccioli e anziani, T09 riproduzione, T10 viaggi, T11 "
    "doveri e leggi, T12 fine vita. adatto = false se la pagina è per produttori, ricercatori o "
    "autorità locali, è solo un indice di link, è troppo generica o non parla della specie. "
    "Niente farmaci o dosi. Rispondi solo con le righe JSON."
)


def scrub(text: str) -> str:
    """Toglie indirizzi e-mail e numeri di telefono (il pacchetto non deve contenere recapiti)."""
    return _PHONE.sub("[NUMERO]", _EMAIL.sub("[EMAIL]", text))


def reviewed_ids(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    data: dict[str, Any] = json.loads(path.read_text("utf-8"))
    return data


def prepare_batches(
    store: Store, pages: Path, out_dir: Path, reviewed_path: Path, size: int = 20
) -> list[str]:
    """Scrive i lotti (file di testo + mappa numero→id) per le fonti non ancora riviste."""
    done = reviewed_ids(reviewed_path)
    todo = [
        sid
        for sid, src in sorted(store.load().items())
        if src["stato"] == "in_uso"
        and src["classe"] in ("V", "VR")
        and src["livello"] != "legge"
        and sid not in done
        and (pages / f"{sid}.txt").exists()
    ]
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for start in range(0, len(todo), size):
        chunk = todo[start : start + size]
        number = start // size + 1
        parts, mapping = [], {}
        data = store.load()
        for n, sid in enumerate(chunk, 1):
            body = " ".join((pages / f"{sid}.txt").read_text("utf-8").split())[:MAX_CHARS]
            src = data[sid]
            head = f"=== DOCUMENTO {n:02d} ===\nTitolo: {src['titolo']}\nEnte: {src['ente']}"
            parts.append(f"{head}\n\n{scrub(body)}\n")
            mapping[f"{n:02d}"] = sid
        name = f"lotto_{number:02d}"
        (out_dir / f"{name}.txt").write_text("\n".join(parts), "utf-8")
        (out_dir / f"{name}.json").write_text(json.dumps(mapping, indent=1), "utf-8")
        written.append(name)
    (out_dir / "ISTRUZIONI.txt").write_text(INSTRUCTIONS, "utf-8")
    return written


def compare(
    store: Store, mapping: dict[str, str], answers: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Confronta le risposte con le etichette attuali: restituisce solo i disaccordi."""
    data = store.load()
    out: list[dict[str, Any]] = []
    for answer in answers:
        sid = mapping.get(f"{int(answer['n']):02d}")
        if not sid or sid not in data:
            continue
        src = data[sid]
        flags = []
        if answer.get("adatto") is False or answer.get("per_proprietari") is False:
            flags.append("non adatta o non per proprietari")
        extra = sorted(set(answer.get("specie", [])) - set(src["specie"]))
        missing = sorted(set(src["specie"]) - set(answer.get("specie", [])))
        if missing:
            flags.append(f"specie dichiarate ma non nel testo: {', '.join(missing)}")
        if flags:
            out.append({
                "id": sid, "titolo": src["titolo"], "flags": flags, "specie_extra": extra,
                "perche_lettore": answer.get("perche", ""),
            })  # fmt: skip
    return out


def mark_reviewed(
    reviewed_path: Path, mapping: dict[str, str], flagged: list[dict[str, Any]]
) -> None:
    done = reviewed_ids(reviewed_path)
    flagged_ids = {f["id"]: f for f in flagged}
    for sid in mapping.values():
        done[sid] = {"disaccordo": flagged_ids.get(sid)}
    reviewed_path.write_text(json.dumps(done, ensure_ascii=False, indent=1), "utf-8")
