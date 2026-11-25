"""Model steps around the note library (plan docs/llm/08 work B), for the eval only.

- understand(): species group, theme and the 1-2 facts a question needs (generic words,
  never the user's details);
- match_facts(): which good note of the cell states each needed fact;
- write_note(): a verified sentence + the passage that supports it -> one compact note in
  our own words (the passage stays in memory: the 6-word check runs in NoteLibrary.add);
- relate(): same fact / new fact / contrast between a new note and a similar one;
- notes_block(): the good notes given to the writer as <fonti_ufficiali>.
Every call goes through the eval's `call` (local claude program or an eval key).
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

MAX_FACTS = 2  # test 2 report §4, proposal 2 (was 4)
# note codes -> the library index's species groups
INDEX_GROUP = {
    "S00": "altro",
    "S01": "cane",
    "S02": "gatto",
    "S03": "coniglio",
    "S04": "piccoli mammiferi",
    "S05": "piccoli mammiferi",
    "S06": "furetto",
    "S07": "uccelli",
    "S08": "rettili",
    "S09": "rettili",
    "S10": "anfibi",
    "S11": "pesci",
    "S12": "pesci",
}
AUDIENCE = {"proprietari": "P", "professionisti": "PR", "ricercatori": "PR", "legge": "L"}

# closed lists (docs/product/21 §9): the model picks a code, never free words
_SPECIES_LIST = "\n".join(f"{k} = {v}" for k, v in N.SPECIES_GROUPS.items())
_THEME_LIST = "\n".join(f"{k} = {v}" for k, v in N.THEMES.items())

UNDERSTAND_SYSTEM = f"""Ti do la domanda di un proprietario di animali. Rispondi SOLO con un \
oggetto JSON:
{{"specie": "codice Sxx", "tema": "codice Txx",
 "fatti": ["1-2 fatti generali, i più importanti per rispondere bene, ciascuno in poche \
parole (es. «il cioccolato è tossico per il cane», «quantità di cioccolato pericolosa»)"],
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
- la stessa forza del passo ("può", "a volte", "dovrebbe" restano tali), le stesse \
condizioni, la stessa specie; ogni numero con l'effetto a cui il passo lo lega; un \
"considerando" non è una regola in vigore;
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
    facts = [str(f) for f in data.get("fatti") or [] if str(f).strip()][:MAX_FACTS]
    return {
        "specie": _code(data.get("specie"), N.SPECIES_GROUPS, N.ALL_SPECIES),
        "tema": _code(data.get("tema"), N.THEMES, "T03"),
        "fatti": facts,
        "parole_en": [str(w) for w in data.get("parole_en") or [] if str(w).strip()][:8],
    }


def match_all(call: Call) -> N.MatchManyFn:
    """Every fact against the cell in one model call (test 2 report §4, proposal 4)."""

    def match(facts: Sequence[str], notes: Sequence[N.Note]) -> dict[str, N.Note]:
        if not facts or not notes:
            return {}
        listed = "\n".join(f"[{i}] {f}" for i, f in enumerate(facts, 1))
        numbered = "\n".join(f"[{i}] {n.text}" for i, n in enumerate(notes, 1))
        data = _json(call(MATCH_SYSTEM, f"FATTI:\n{listed}\n\nNOTE:\n{numbered}", "abbina"))
        found: dict[str, N.Note] = {}
        for pair in data.get("abbinamenti") or []:
            if not isinstance(pair, dict):
                continue
            f, k = pair.get("fatto"), pair.get("nota")
            if isinstance(f, int) and isinstance(k, int) and 0 < f <= len(facts):
                if 0 < k <= len(notes):
                    found[facts[f - 1]] = notes[k - 1]
        return found

    return match


FACTS_TO_PASSAGES_SYSTEM = """Ti do dei FATTI che una biblioteca non ha ancora e dei PASSI \
numerati appena letti da fonti ammesse. Per ogni fatto indica il passo che lo afferma davvero \
(ogni parte del fatto è nel passo), oppure 0. Rispondi SOLO con JSON: \
{"abbinamenti": [{"fatto": 1, "passo": 2}, ...]}"""


def facts_to_passages(
    call: Call, facts: Sequence[str], passages: Sequence[L.Passage]
) -> dict[str, L.Passage]:
    """Proposal 3 of the test 2 report: notes are written for the facts the question needed,
    from the passages read for it, not only from the sentences that got an asterisk."""
    if not facts or not passages:
        return {}
    listed = "\n".join(f"[{i}] {f}" for i, f in enumerate(facts, 1))
    numbered = "\n\n".join(f"[{i}] {p.text}" for i, p in enumerate(passages, 1))
    data = _json(
        call(FACTS_TO_PASSAGES_SYSTEM, f"FATTI:\n{listed}\n\nPASSI:\n{numbered}", "fatti_passi")
    )
    found: dict[str, L.Passage] = {}
    for pair in data.get("abbinamenti") or []:
        if not isinstance(pair, dict):
            continue
        f, k = pair.get("fatto"), pair.get("passo")
        if isinstance(f, int) and isinstance(k, int) and 0 < f <= len(facts):
            if 0 < k <= len(passages):
                found[facts[f - 1]] = passages[k - 1]
    return found


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


ADMIT_SYSTEM_MILD = """Controlli una nota di biblioteca prima che entri in una chat per \
proprietari di animali. Ti do la NOTA e il PASSO della fonte da cui è scritta. Respingi la \
nota SOLO se dice PIÙ di quanto dice il passo, in uno di questi modi:
- più forte: "può", "a volte", "è stato riportato", "dovrebbe" del passo diventano "è", \
"sempre", "va fatto";
- più larga: toglie una condizione o un limite che restringe (solo se, solo per, quando, se non \
trattata), oppure il passo parla di una specie e la nota non la dice o ne dice un'altra;
- un numero legato a un effetto diverso da quello del passo;
- il ragionamento del passo invertito;
- una regola in vigore ricavata da un "considerando" o da una premessa di un atto;
- un esempio, una causa o un consiglio che il passo non dice.
NON respingere per una nota più cauta del passo ("può" dove il passo dice "è"), per un \
dettaglio omesso che non toglie un limite, per parole diverse con lo stesso senso.
Rispondi SOLO con JSON {"entra": true|false, "motivo": "breve"}"""


# Measured 21/11 on 195 notes judged blind by Opus (new writer): strict + Haiku admits 98%
# faithful notes and loses 27% of the good ones; the mild rule 89% / 9%; Sonnet no better.
ADMIT_SYSTEM = """Controlli una nota di biblioteca prima che entri in una chat per \
proprietari di animali. Ti do la NOTA e il PASSO della fonte da cui è scritta. La nota entra \
solo se dice ciò che il passo dice, senza cambiare nulla di questo:
- la forza: "può", "a volte", "è stato riportato", "dovrebbe" restano tali (mai "è", "sempre");
- le condizioni e i limiti (solo se, solo per, quando);
- la specie, la razza, l'età di cui parla il passo (se il passo parla del cane, la nota dice cane);
- ogni numero con l'effetto a cui il passo lo lega (una dose per un effetto non vale per un altro);
- il ragionamento del passo (mai invertito);
- un "considerando" o una premessa di un atto non è una regola in vigore: mai "è vietato" da lì;
- nessun esempio, causa o consiglio che il passo non dica.
Omettere un dettaglio va bene se non cambia il senso. Una nota più cauta del passo va bene.
Rispondi SOLO con JSON {"entra": true|false, "motivo": "breve"}"""


def admit(
    call: Call, note: N.Note, passage_text: str, system: str | None = None
) -> tuple[bool, str]:
    """Test 2 (21/11): notes that changed the source's strength, conditions, species or
    numbers reached the library; each note is now checked against its passage before it
    is kept (after the answer: no wait for the owner)."""
    system = system or ADMIT_SYSTEM
    data = _json(call(system, f"NOTA: {note.text}\n\nPASSO:\n{passage_text}", "ammissione"))
    return data.get("entra") is True, str(data.get("motivo") or "")


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
