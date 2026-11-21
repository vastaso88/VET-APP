"""Model steps around the note library (plan docs/llm/08 work B), for the eval only.

- understand(): species group, theme and the 2-4 facts a question needs (generic words,
  never the user's details);
- match_facts(): which good note of the cell states each needed fact;
- write_note(): a verified sentence + the passage that supports it -> one compact note in
  our own words (the passage stays in memory: the 6-word check runs in NoteLibrary.add);
- relate(): same fact / new fact / contrast between a new note and a similar one;
- notes_block(): the good notes given to the writer as <fonti_ufficiali>.
Every call goes through the eval's `call` (local claude program or an eval key), never Groq.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Sequence
from datetime import date
from pathlib import Path
from typing import Any

import library_chat as L
import note_library as N

Call = Callable[[str, str, str], str]

AUDIENCE = {"proprietari": "P", "professionisti": "PR", "ricercatori": "PR", "legge": "L"}

# closed lists (docs/product/21 §9): the model picks a code, never free words
_SPECIES_LIST = "\n".join(f"{k} = {v}" for k, v in N.SPECIES_GROUPS.items())
_THEME_LIST = "\n".join(f"{k} = {v}" for k, v in N.THEMES.items())

UNDERSTAND_SYSTEM = f"""Ti do la domanda di un proprietario di animali. Rispondi SOLO con un \
oggetto JSON:
{{"specie": "codice Sxx", "tema": "codice Txx",
 "fatti": ["2-4 fatti generali che servono per rispondere bene, ciascuno in poche parole \
(es. «il cioccolato è tossico per il cane», «quantità di cioccolato pericolosa»)"],
 "parole_en": ["4-8 parole chiave in inglese per cercare quei fatti in una guida \
(es. chocolate, theobromine, toxic)"]}}
Regole: i fatti sono generali, valgono per qualsiasi animale di quella specie: MAI nomi, età \
precise, luoghi, parole copiate dalla domanda o dettagli personali. Specie rare: il gruppo più \
vicino (axolotl -> S10, criceto -> S05, pappagallo -> S07). Nessuna specie: S00. Un caso grave \
è una domanda come le altre (di solito tema T06 o T07).
SPECIE:
{_SPECIES_LIST}
TEMI:
{_THEME_LIST}"""

MATCH_SYSTEM = """Ti do dei FATTI che servono per una risposta e delle NOTE numerate. Per ogni \
fatto indica la nota che lo afferma davvero (stesso contenuto, non solo stesso argomento), \
oppure 0 se nessuna. Rispondi SOLO con JSON: {"abbinamenti": [{"fatto": 1, "nota": 3}, ...]}"""

WRITE_SYSTEM = f"""Scrivi UNA nota di biblioteca per una chat che aiuta i proprietari di \
animali. Ti do una FRASE verificata e il PASSO della fonte che la sostiene. Rispondi SOLO con JSON:
{{"specie": "codice Sxx", "tema": "codice Txx",
 "affermazione": "il fatto, in italiano, con parole tue, al massimo 30 parole",
 "condizioni": "quando vale (specie, età, situazione); vuoto se sempre"}}
Regole:
- un solo fatto, quello che il PASSO dice davvero; nulla che il passo non dica;
- parole tue: MAI 6 o più parole di seguito uguali al passo; niente tabelle o elenchi copiati;
- nessun dato personale: niente nomi, casi, luoghi, età precise della domanda;
- niente dosi di farmaci né terapie;
- se il passo non sostiene davvero la frase: {{"affermazione": ""}}.
SPECIE:
{_SPECIES_LIST}
TEMI:
{_THEME_LIST}"""

RELATE_SYSTEM = """Confronta due note di una biblioteca sugli animali. Rispondi SOLO con JSON \
{"relazione": "uguale" | "nuovo" | "contrasto"}:
- "uguale": dicono lo stesso fatto (anche con parole diverse o più dettagli compatibili);
- "contrasto": parlano della stessa cosa ma dicono cose incompatibili;
- "nuovo": fatti diversi."""


def _code(value: Any, allowed: dict[str, str], fallback: str) -> str:
    code = str(value or "").strip().upper()
    return code if code in allowed else fallback


def _json(text: str) -> dict[str, Any]:
    return L._json(text)


def understand(call: Call, message: str, pet: str) -> dict[str, Any]:
    data = _json(call(UNDERSTAND_SYSTEM, f"Animale: {pet}\nDomanda: {message}", "capire"))
    facts = [str(f) for f in data.get("fatti") or [] if str(f).strip()][:4]
    return {
        "specie": _code(data.get("specie"), N.SPECIES_GROUPS, N.ALL_SPECIES),
        "tema": _code(data.get("tema"), N.THEMES, "T03"),
        "fatti": facts,
        "parole_en": [str(w) for w in data.get("parole_en") or [] if str(w).strip()][:8],
    }


def match_facts(call: Call) -> N.MatchFn:
    """A MatchFn for N.sufficiency(); one model call per fact (cells are small)."""

    def match(fact: str, notes: Sequence[N.Note]) -> N.Note | None:
        numbered = "\n".join(f"[{i}] {n.text}" for i, n in enumerate(notes, 1))
        data = _json(call(MATCH_SYSTEM, f"FATTI:\n[1] {fact}\n\nNOTE:\n{numbered}", "abbina"))
        for pair in data.get("abbinamenti") or []:
            if isinstance(pair, dict) and isinstance(pair.get("nota"), int):
                k: int = pair["nota"]
                if 0 < k <= len(notes):
                    return notes[k - 1]
        return None

    return match


def load_audience(library_folder: Path) -> dict[str, str]:
    """doc id -> P / PR / L from the library index ("scritto_per")."""
    path = library_folder / "indice.json"
    if not path.exists():
        return {}
    rows = json.loads(path.read_text("utf-8"))
    return {str(r["id"]): AUDIENCE.get(str(r.get("scritto_per")), "PR") for r in rows}


def source_of(doc: L.Doc, audience: dict[str, str], group: str = "a") -> N.Source:
    return N.Source(
        ente=doc.publisher or doc.reference,
        anno=doc.year or 0,
        link=doc.link,
        livello=doc.level,
        tipo=doc.kind,
        per_chi=audience.get(doc.id, "PR"),
        dominio=N.site_of(doc.link) if doc.link else doc.id.lower(),
        gruppo=group,
        indice_rivista=doc.journal_value,
    )


def write_note(
    call: Call,
    sentence: str,
    passage: L.Passage,
    source: N.Source,
    today: date,
    cell: tuple[str, str] = (N.ALL_SPECIES, "T03"),
) -> N.Note | None:
    """`cell` (the question's species and theme) is the fallback when the model gives no
    valid code."""
    data = _json(
        call(
            WRITE_SYSTEM,
            f"FRASE: {sentence}\n\nPASSO ({passage.doc.kind}, {passage.doc.title[:100]}):\n"
            f"{passage.text}",
            "nota",
        )
    )
    claim = str(data.get("affermazione") or "").strip()
    if not claim:
        return None
    return N.Note(
        specie=_code(data.get("specie"), N.SPECIES_GROUPS, cell[0]),
        tema=_code(data.get("tema"), N.THEMES, cell[1]),
        affermazione=claim,
        condizioni=str(data.get("condizioni") or "").strip(),
        fonti=[source],
        verificata_il=today.isoformat(),
    )


def relate(call: Call) -> N.RelateFn:
    def fn(new: N.Note, old: N.Note) -> N.Relation:
        data = _json(call(RELATE_SYSTEM, f"NOTA A: {new.text}\nNOTA B: {old.text}", "relaziona"))
        value = str(data.get("relazione") or "nuovo")
        return value if value in ("uguale", "contrasto") else "nuovo"  # type: ignore[return-value]

    return fn


def notes_block(notes: Sequence[N.Note]) -> str:
    """The notes the writer reads before answering (work A's `official_sources` field).
    Discordant notes are said to be so; the code writes the citations, not the model."""
    lines = []
    for note in notes:
        best = min(note.fonti, key=lambda s: s.rank)
        tag = f"{best.ente}, {best.anno}" + (
            f" (+{note.independent_sources - 1} fonti)" if note.independent_sources > 1 else ""
        )
        flag = " [FONTI DISCORDI su questo punto]" if note.discorde_con else ""
        cond = f" Vale: {note.condizioni}." if note.condizioni else ""
        lines.append(f"- {note.affermazione}{cond} ({tag}){flag}")
    return "\n".join(lines)
