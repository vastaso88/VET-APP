"""Plan docs/llm/08, work B: Quokka answers, the library verifies and cites (prototype).

Outside the app, for measurement only. After Quokka's answer:

1. extract  - a light model call marks the sentences with a checkable fact (an obligation or
              a law, a number, "is toxic", "is an emergency", a specific claim about care or
              health) and gives search words for each; everything else is left alone;
2. search   - keyword search (library_chat.LibraryIndex) for each such sentence;
3. judge    - one model call decides, sentence by sentence: SUPPORTED by a passage, or
              CONTRADICTED by a passage, or NO TEXT;
4. apply    - supported: an asterisk and the citation written by the code (complete the first
              time, never repeated in the conversation); contradicted by a LEVEL 1 source
              (law, public-body guide): the sentence is rewritten from the source, with the
              asterisk; contradicted by a study: ignored (a study may only confirm; enforced
              here in code, whatever the model says); no text: the sentence stays as it is.
              Nothing is ever removed.
5. once per conversation, the line saying what the asterisks mean (Normativa to write it).

Variant 2 adds `official_passages`: the level 1 passages relevant to the question, read by the
writer before answering (the app's ChatOrchestratorInput.official_sources). Studies are never
given to the writer.
"""

from __future__ import annotations

import re
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any

import library_chat as L

# The transparency line, once per conversation in the assistant's first message:
# Normativa's text (docs/compliance/20 §16, proposal awaiting the owner's yes); never
# "verificata", "validata" or "controllata da esperti". Other languages: drafts of the
# Chat session for the translation review.
VERIFIED_LINE = {
    "it": "Rispondo con un'intelligenza artificiale e posso sbagliare. Le frasi con "
    "l'asterisco* le ho trovate in una fonte che ti indico (controllo automatico: la fonte può "
    "non valere per il tuo caso). Le altre vengono dalle conoscenze generali dell'IA e possono "
    "essere incomplete o sbagliate. Non sostituisco il veterinario.",
    "en": "I answer with artificial intelligence and I can be wrong. I found the sentences with "
    "an asterisk* in a source that I show you (automatic check: the source may not apply to "
    "your case). The others come from the AI's general knowledge and may be incomplete or "
    "wrong. I do not replace the vet.",
    "es": "Respondo con una inteligencia artificial y puedo equivocarme. Las frases con "
    "asterisco* las he encontrado en una fuente que te indico (control automático: la fuente "
    "puede no valer para tu caso). Las demás proceden de los conocimientos generales de la IA "
    "y pueden ser incompletas o erróneas. No sustituyo al veterinario.",
    "de": "Ich antworte mit einer künstlichen Intelligenz und kann mich irren. Die Sätze mit "
    "Sternchen* habe ich in einer Quelle gefunden, die ich dir nenne (automatischer Abgleich: "
    "die Quelle passt vielleicht nicht zu deinem Fall). Die übrigen stammen aus dem "
    "allgemeinen Wissen der KI und können unvollständig oder falsch sein. Ich ersetze nicht "
    "die Tierärztin oder den Tierarzt.",
    "fr": "Je réponds avec une intelligence artificielle et je peux me tromper. Les phrases "
    "avec un astérisque* viennent d'une source que je t'indique (contrôle automatique : la "
    "source peut ne pas valoir pour ton cas). Les autres viennent des connaissances générales "
    "de l'IA et peuvent être incomplètes ou fausses. Je ne remplace pas le vétérinaire.",
}

EXTRACT_SYSTEM = """Ti do la risposta di una chat a un proprietario di animali, frase per \
frase, e i dati dell'animale. Segna SOLO le frasi che contengono un fatto controllabile su \
una fonte: un obbligo o una regola di legge, un numero (misure, tempi, temperature, quantità \
di cibo o acqua, età), "è tossico / pericoloso", "è un'urgenza", un'affermazione specifica su \
salute, alimentazione, cura o comportamento della specie. NON segnare: domande, frasi di \
empatia, inviti generici ("rivolgiti al veterinario", "osservalo"), consigli ovvi, riassunti. \
Per ogni frase segnata dai 3-6 parole di ricerca in inglese tecnico e 2-4 in italiano (specie, \
sostanza, segno, norma), mai nomi propri, e il "tipo": "legge" se la frase dice un obbligo, \
un divieto o una responsabilità legale, altrimenti "fatto". Rispondi SOLO con un oggetto JSON:
{"gruppo": uno tra cane, gatto, coniglio, piccoli mammiferi, furetto, uccelli, rettili, anfibi, \
pesci, altro, "frasi": [{"n": 3, "tipo": "fatto", "parole_en": ["..."], "parole_it": ["..."]}]}"""

JUDGE_SYSTEM = """Verifichi frasi di una risposta per un proprietario di animali contro passi di \
testi ufficiali e scientifici. Per ogni frase numerata ti do alcuni passi candidati, con il \
tipo e il livello della fonte (livello 1 = legge o guida di un ente pubblico; livello 3 = \
studio scientifico). Per ogni frase decidi:
- "sostenuta": un passo dice davvero la stessa cosa (anche con altre parole o in un'altra \
lingua). Lo stesso argomento non basta: deve dire quel fatto. Indica il passo.
- "contraddetta": un passo dice chiaramente il contrario o un valore diverso. Indica il \
passo e, SOLO se il passo è di livello 1, scrivi "riscrittura": la frase corretta, nella \
stessa lingua e nello stesso tono, che dice solo ciò che il passo dice (la minima modifica).
- "nessuna": nessun passo sostiene o contraddice la frase.
Regole: una legge vale solo per il suo Paese: per un proprietario in Italia una legge o una \
guida di un altro Paese su obblighi legali non sostiene né contraddice la frase (le guide \
straniere sulla cura dell'animale valgono come conoscenza, non come obbligo). Un singolo \
studio su animali diversi o in condizioni diverse non contraddice una frase generale. Nel \
dubbio: "nessuna".
Rispondi SOLO con un oggetto JSON: {"verdetti": [{"n": 3, "esito": "sostenuta"|"contraddetta"\
|"nessuna", "passo": "3.2", "riscrittura": "solo se contraddetta da livello 1"}]}"""


@dataclass
class Verified:
    text: str
    cited: list[str]
    claims: int
    supported: int
    corrections: list[dict[str, str]] = field(default_factory=list)
    ignored_study_contradictions: int = 0
    # a legal claim with only a foreign source or a study behind it (no asterisk, no fix)
    ignored_foreign_or_study: int = 0
    verdicts: list[dict[str, Any]] = field(default_factory=list)


_SENTENCE = re.compile(r"(?<=[.!?])\s+(?=\S)")


def _units(text: str) -> list[str]:
    """The answer cut into sentences, keeping line breaks as their own units so that
    lists and paragraphs come back as they were."""
    out: list[str] = []
    for line in re.split(r"(\n+)", text):
        if not line:
            continue
        if line.startswith("\n"):
            out.append(line)
        else:
            out.extend(s for s in _SENTENCE.split(line) if s)
    return out


_FIXED_KEYS = ("person_hurt_line",)  # the urgent opening was removed (owner, 20/11)
_FIXED: set[str] | None = None


def _fixed_sentences() -> set[str]:
    """The app's fixed texts (legal urgent opening, 112 line) in every language: written by
    the code, never checked nor marked with an asterisk."""
    global _FIXED
    if _FIXED is None:
        _FIXED = set()
        try:
            from packages.core.domain.localization import translate
        except ImportError:  # run without the repository root on the path
            return _FIXED
        for language in ("it", "en", "es", "de", "fr"):
            for key in _FIXED_KEYS:
                _FIXED.update(" ".join(u.split()) for u in _units(translate(key, language)))
    return _FIXED


def _numbered(units: Sequence[str]) -> tuple[str, dict[int, int]]:
    lines, index = [], {}
    n = 0
    fixed = _fixed_sentences()
    for i, unit in enumerate(units):
        if unit.startswith("\n") or not unit.strip() or " ".join(unit.split()) in fixed:
            continue
        n += 1
        index[n] = i
        lines.append(f"{n}. {unit.strip()}")
    return "\n".join(lines), index


def verify(
    call: L.Call,
    index: L.LibraryIndex,
    *,
    answer: str,
    pet: str,
    language: str,
    already_cited: Sequence[str],
    first_reply: bool,
) -> Verified:
    units = _units(answer)
    numbered, where = _numbered(units)
    if not where:
        return Verified(answer, [], 0, 0)
    extracted = L._json(call(EXTRACT_SYSTEM, f"Animale: {pet}\n\nRISPOSTA:\n{numbered}", "estrai"))
    group = str(extracted.get("gruppo") or "altro")
    claims = [
        c
        for c in extracted.get("frasi") or []
        if isinstance(c, dict) and isinstance(c.get("n"), int) and c["n"] in where
    ]
    kinds = {int(c["n"]): str(c.get("tipo") or "fatto") for c in claims}
    candidates: dict[int, list[L.Passage]] = {}
    blocks = []
    for claim in claims:
        words = [*map(str, claim.get("parole_en") or []), *map(str, claim.get("parole_it") or [])]
        hits = [p for p, _ in index.search(words, group, k=5)]
        if not hits:
            continue
        candidates[claim["n"]] = hits
        passages = "\n".join(
            f"[{claim['n']}.{k}] ({p.doc.kind}, livello {p.doc.level}, "
            f"paese {p.doc.country or '?'}; "
            f"{p.doc.title[:100]}){' NOTA: ' + p.doc.warning if p.doc.warning else ''}\n"
            f"{p.text}"
            for k, p in enumerate(hits, 1)
        )
        blocks.append(f"FRASE {claim['n']}: {units[where[claim['n']]].strip()}\n{passages}")
    result = Verified(answer, [], len(claims), 0)
    if not blocks:
        return _finish(result, units, {}, [], already_cited, language, first_reply)
    judged = L._json(call(JUDGE_SYSTEM, f"Animale: {pet}\n\n" + "\n\n".join(blocks), "verifica"))
    used: list[L.Passage] = []
    marks: dict[int, int] = {}  # unit index -> position in `used` (1-based)
    for v in judged.get("verdetti") or []:
        if not isinstance(v, dict) or not isinstance(v.get("n"), int):
            continue
        n, outcome = v["n"], str(v.get("esito") or "nessuna")
        found = candidates.get(n)
        match = re.fullmatch(rf"{n}\.(\d+)", str(v.get("passo") or "").strip())
        if not found or not match or not 0 < int(match.group(1)) <= len(found):
            continue
        passage = found[int(match.group(1)) - 1]
        result.verdicts.append(
            {"n": n, "esito": outcome, "passo": passage.pid, "livello": passage.doc.level}
        )
        legal_claim = kinds.get(n) == "legge"
        if legal_claim and not passage.doc.italian_or_eu_law:
            # Normativa §16: an obligation is confirmed or corrected only by an Italian or
            # EU law; a foreign guide or a study says nothing on it (enforced here).
            result.ignored_foreign_or_study += 1
            continue
        if outcome == "contraddetta":
            rewrite = str(v.get("riscrittura") or "").strip()
            if passage.doc.level != 1 or not rewrite:
                # a study may only confirm, never correct (plan 08, enforced here)
                result.ignored_study_contradictions += 1
                continue
            original = units[where[n]]
            units[where[n]] = rewrite
            result.corrections.append(
                {"prima": original.strip(), "dopo": rewrite, "passo": passage.pid}
            )
        elif outcome != "sostenuta":
            continue
        if all(u.pid != passage.pid for u in used):
            used.append(passage)
        marks[where[n]] = next(k for k, u in enumerate(used, 1) if u.pid == passage.pid)
        result.supported += 1
    return _finish(result, units, marks, used, already_cited, language, first_reply)


def _finish(
    result: Verified,
    units: list[str],
    marks: dict[int, int],
    used: list[L.Passage],
    already_cited: Sequence[str],
    language: str,
    first_reply: bool,
) -> Verified:
    for i, k in marks.items():
        unit = units[i].rstrip()
        # the placeholder goes before the final punctuation, render() places the mark
        tail = re.search(r"[.!?…:;]+$", unit)
        units[i] = (
            (unit[: tail.start()] + f" [{k}]" + unit[tail.start() :])
            if tail
            else (unit + f" [{k}]")
        )
    body = "".join(u if u.startswith("\n") else (u + " ") for u in units)
    body = re.sub(r" +\n", "\n", body).strip()
    rendered, cited = L.render(body, used, already_cited)
    if first_reply:
        line = VERIFIED_LINE.get(language, VERIFIED_LINE["it"])
        head, sep, notes = rendered.partition("\n\n*")
        rendered = f"{head}\n\n{line}" + (f"\n\n*{notes}" if sep else "")
    result.text = rendered
    result.cited = cited
    return result


def official_passages(
    call: L.Call, index_level1: L.LibraryIndex, *, message: str, pet: str
) -> tuple[str, list[str]]:
    """Variant 2: the level 1 passages relevant to the question (laws, public-body guides),
    for the writer to read before answering. Studies never. Empty when none is relevant."""
    reader = L.read(call, message, pet, [])
    words = [*map(str, reader.get("parole_en") or []), *map(str, reader.get("parole_it") or [])]
    hits = [p for p, _ in index_level1.search(words, str(reader.get("gruppo") or ""), k=10)]
    chosen = L.rerank(call, message, pet, hits)[:4] if hits else []
    if not chosen:
        return "", []
    block = "\n\n".join(
        f"[{i}] ({p.doc.kind}; {p.doc.title[:100]})"
        + (f"\nNOTA SULLA VIGENZA: {p.doc.warning}" if p.doc.warning else "")
        + f"\n{p.text}"
        for i, p in enumerate(chosen, 1)
    )
    return block, [p.pid for p in chosen]
