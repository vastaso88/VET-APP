"""Prototype: the chat answers from a library of original source texts (plan doc 07).

Outside the app, for measurement only: nothing here is imported by the production path.

Four steps, the same for every question, urgencies included:

1. reader   - a light model call turns the question into JSON: species group, topic,
              danger yes/no, vague yes/no, search words in English and Italian (no
              personal data);
2. search   - keyword search (BM25, SQLite FTS5 in memory; no external embedding service)
              over passages of the library, then the 4-6 best passages ordered by the
              source hierarchy of doc 21; optionally a model call picks the relevant
              ones first ("rerank");
3. writer   - free prose of ~150-180 words only from the passages, with placeholders
              [n] tied to a passage; the code turns them into asterisks and writes the
              citation from the passage's metadata (never the model);
4. checker  - every sentence must rest on a cited passage; unsupported sentences and
              any therapy (drugs, surgery, clinical procedures) are removed, or the
              answer is rewritten once.

Nothing useful in the library (owner decisions 17/11/2026): the chat says so and offers
an answer from general knowledge; only if the owner accepts, `general_answer` writes
it, labelled as not coming from a verified source, without asterisks.

Citations (Normativa, docs/compliance/20): written by the code; the first time a source
appears in a conversation the citation is complete, later it is not repeated; the
caller keeps the list "Fonti di questa conversazione". Doses never pass: the existing
deterministic net (`without_dose_sentences`) runs last on every reply.
"""

from __future__ import annotations

import json
import re
import sqlite3
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from packages.core.application.services.safety_gate import SafetyGate
from packages.core.domain.knowledge.dose_in_answer import without_dose_sentences

# (system, user, purpose) -> text of the model's reply
Call = Callable[[str, str, str], str]

PASSAGE_CHARS = 1000
CURRENT_YEAR = 2026
OLD_AFTER_YEARS = 15
TYPE_RANK = {
    "legge": 0,
    "ordinanza ministeriale": 0,
    "guida ufficiale": 1,
    "regolamento": 0,
    "decreto": 0,
    "linea guida": 1,
    "rassegna sistematica": 2,
    "rassegna": 2,
    "studio": 3,
    "caso clinico": 4,
    "manuale": 5,
}
SKIPPED_SECTIONS = re.compile(
    r"^\s*(?:\d+\.?\s*)?(references?|bibliograf\w*|literature cited|acknowledge?ments?|"
    r"funding|conflicts? of interest|author contributions?|data availability|"
    r"supplementary|abbreviations|institutional review|informed consent|"
    r"materials? and methods|methods|statistical analys\w*)\b",
    re.IGNORECASE,
)
SPECIES_GROUPS = (
    "cane",
    "gatto",
    "coniglio",
    "piccoli mammiferi",
    "furetto",
    "uccelli",
    "rettili",
    "anfibi",
    "pesci",
    "altro",
)
LANGUAGE = {"it": "italiano", "en": "inglese", "es": "spagnolo", "de": "tedesco", "fr": "francese"}
STARS = ("*", "**", "***")
# Repealed acts quoted inside other texts (editorial notes): such passages never reach the
# writer, so a repealed rule is not cited under the name of the law that quotes it.
REPEALED = re.compile(r"\b320\s*/\s*1954\b|\bD\.?\s*P\.?\s*R\.?\s*(?:n\.\s*)?320\b", re.IGNORECASE)
STOPWORDS = frozenset(
    "the and with for from that this are was not but can its dog dogs cat cats animal animals "
    "pet pets del della dei delle che con per non una uno gli nel nella sul sulla cane gatto "
    "animale animali".split()
)
NO_SOURCE_MARK = "NESSUNA_FONTE"
# Fixed texts: Normativa proposals (docs/compliance/20 §12-14), awaiting the owner's yes;
# the Italian is theirs, the other languages are drafts of this prototype.
# No danger, nothing useful in the library: the notice with the offer of an answer from
# the AI's general knowledge.
OFFER = {
    "it": "Non ho trovato una fonte su questo tra quelle che ho a disposizione (leggi, enti "
    "pubblici, articoli scientifici ad accesso aperto). Se hai dubbi, rivolgiti a un veterinario "
    "o a un altro specialista; in caso di emergenza chiama subito il tuo veterinario o la "
    "clinica più vicina. Se vuoi, posso comunque risponderti con le conoscenze generali "
    "dell'intelligenza artificiale: non sono verificate su fonti e possono essere incomplete o "
    "sbagliate.",
    "en": "I haven't found a source on this among those available to me (laws, public bodies, "
    "open-access scientific articles). If in doubt, contact a vet or another specialist; in an "
    "emergency call your vet or the nearest clinic straight away. If you like, I can still "
    "answer from the general knowledge of artificial intelligence: it is not checked against "
    "sources and may be incomplete or wrong.",
    "es": "No he encontrado una fuente sobre esto entre las que tengo a mi disposición (leyes, "
    "organismos públicos, artículos científicos de acceso abierto). Si tienes dudas, acude a un "
    "veterinario o a otro especialista; en caso de emergencia llama enseguida a tu veterinario o "
    "a la clínica más cercana. Si quieres, puedo responderte igualmente con los conocimientos "
    "generales de la inteligencia artificial: no están verificados en fuentes y pueden ser "
    "incompletos o erróneos.",
    "de": "Ich habe dazu keine Quelle unter denen gefunden, die mir zur Verfügung stehen "
    "(Gesetze, Behörden, frei zugängliche wissenschaftliche Artikel). Wenden Sie sich im "
    "Zweifel an eine Tierärztin, einen Tierarzt oder eine andere Fachperson; im Notfall rufen "
    "Sie sofort Ihre Tierarztpraxis oder die nächste Klinik an. Wenn Sie möchten, kann ich "
    "trotzdem aus dem allgemeinen Wissen der künstlichen Intelligenz antworten: Es ist nicht "
    "an Quellen geprüft und kann unvollständig oder falsch sein.",
    "fr": "Je n'ai pas trouvé de source à ce sujet parmi celles dont je dispose (lois, "
    "organismes publics, articles scientifiques en accès libre). En cas de doute, adressez-vous "
    "à un vétérinaire ou à un autre spécialiste ; en cas d'urgence, appelez tout de suite votre "
    "vétérinaire ou la clinique la plus proche. Si vous le souhaitez, je peux tout de même vous "
    "répondre avec les connaissances générales de l'intelligence artificielle : elles ne sont "
    "pas vérifiées sur des sources et peuvent être incomplètes ou erronées.",
}
# Put by the code on every answer from general knowledge.
GENERAL_LABEL = {
    "it": "Risposta dalle conoscenze generali dell'IA, senza fonti verificate: può essere "
    "incompleta o sbagliata. Non è una visita né una diagnosi.",
    "en": "Answer from the AI's general knowledge, without verified sources: it may be "
    "incomplete or wrong. It is not an examination or a diagnosis.",
    "es": "Respuesta basada en los conocimientos generales de la IA, sin fuentes verificadas: "
    "puede ser incompleta o errónea. No es una consulta ni un diagnóstico.",
    "de": "Antwort aus dem allgemeinen Wissen der KI, ohne geprüfte Quellen: Sie kann "
    "unvollständig oder falsch sein. Sie ist keine Untersuchung und keine Diagnose.",
    "fr": "Réponse issue des connaissances générales de l'IA, sans sources vérifiées : elle peut "
    "être incomplète ou erronée. Ce n'est ni une consultation ni un diagnostic.",
}
# Danger or urgency (reader or rule-based gate): the answer opens with this, independent of
# the sources, and no general-knowledge offer is made.
URGENT_OPENING = {
    "it": "Questa situazione può essere urgente. Non aspettare: contatta subito un veterinario. "
    "Quokka non può valutare il tuo animale.",
    "en": "This situation may be urgent. Don't wait: contact a vet straight away. Quokka cannot "
    "assess your animal.",
    "es": "Esta situación puede ser urgente. No esperes: contacta enseguida con un veterinario. "
    "Quokka no puede valorar a tu animal.",
    "de": "Diese Situation kann dringend sein. Warten Sie nicht: Wenden Sie sich sofort an eine "
    "Tierarztpraxis. Quokka kann Ihr Tier nicht beurteilen.",
    "fr": "Cette situation peut être urgente. N'attendez pas : contactez tout de suite un "
    "vétérinaire. Quokka ne peut pas évaluer votre animal.",
}
# A person hurt or at risk (prototype wording; the Normativa asked for "pronto soccorso o
# numero di emergenza").
PERSON_URGENT = {
    "it": "Se una persona è ferita o in pericolo, vai al pronto soccorso o chiama il 112.",
    "en": "If a person is hurt or in danger, go to A&E or call your emergency number.",
    "es": "Si una persona está herida o en peligro, ve a urgencias o llama al 112.",
    "de": "Wenn ein Mensch verletzt oder in Gefahr ist, gehen Sie in die Notaufnahme oder "
    "rufen Sie 112 an.",
    "fr": "Si une personne est blessée ou en danger, allez aux urgences ou appelez le 112.",
}
# The part of an answer without a source.
NO_SOURCE_URGENT = {
    "it": "Su questo non ho una fonte da citarti.",
    "en": "On this I have no source to cite.",
    "es": "Sobre esto no tengo una fuente que citarte.",
    "de": "Dazu habe ich keine Quelle, die ich nennen kann.",
    "fr": "Sur ce point, je n'ai pas de source à vous citer.",
}
NO_SOURCE_PLAIN = {
    "it": "Non ho una fonte su questo; se hai dubbi, rivolgiti a un veterinario o a uno "
    "specialista.",
    "en": "I have no source on this; if in doubt, contact a vet or a specialist.",
    "es": "No tengo una fuente sobre esto; si tienes dudas, acude a un veterinario o a un "
    "especialista.",
    "de": "Dazu habe ich keine Quelle; wenden Sie sich im Zweifel an eine Tierarztpraxis oder "
    "eine Fachperson.",
    "fr": "Je n'ai pas de source à ce sujet ; en cas de doute, adressez-vous à un vétérinaire ou "
    "à un spécialiste.",
}
HEALTH_NOTE = {
    "it": "Per la salute del tuo animale decide il veterinario.",
    "en": "Your vet decides about your animal's health.",
    "es": "Sobre la salud de tu animal decide el veterinario.",
    "de": "Über die Gesundheit Ihres Tieres entscheidet die Tierärztin oder der Tierarzt.",
    "fr": "Pour la santé de votre animal, c'est le vétérinaire qui décide.",
}
# From memory the model never names bodies, authors, studies, guidelines or links
# (Normativa): a sentence that does is dropped by the code.
_NAMED_SOURCE = re.compile(
    r"https?://|www\.|\bet al\b|\b(?:19|20)\d\d\b|\bstud(?:i|y|ies|ie|ios|e)\b|"
    r"\bstudio\b(?! veterinari)|"
    r"\bricerc\w+|\bresearch\w*|\blinee? guida\b|\bguidelines?\b|\bleitlinie\w*|"
    r"\bdirectrices?\b|\brecommandations?\b|\bsecondo (?:l[ao]|gli|i)\b|\baccording to\b|"
    r"\buniversit\w+|\bministe\w+",
    re.IGNORECASE,
)
_NAMED_BODY = re.compile(r"\b(?:WSAVA|AAHA|AVMA|RSPCA|ASPCA|Defra|FECAVA|ISFM|EFSA|OMS|WHO|FDA)\b")
LEGAL_KINDS = frozenset({"legge", "ordinanza ministeriale", "regolamento", "decreto"})
NORMATTIVA_NOTE = "Normattiva (testo non ufficiale e gratuito; fa fede la GU)"


# --- library -----------------------------------------------------------------------


@dataclass(frozen=True)
class Doc:
    id: str
    reference: str
    level: int
    kind: str
    year: int
    journal_value: float
    species: tuple[str, ...]
    topics: tuple[str, ...]
    language: str
    license: str
    title: str
    publisher: str
    link: str
    abstract_only: bool
    # e.g. an ordinance whose term may have expired: never presented as law in force
    warning: str = ""
    # the library's own source line for laws ("Normattiva, testo non ufficiale; ...")
    source_line: str = ""
    # "IT", "UE", "UK-Galles", "internazionale (articolo)" (library field "paese")
    country: str = ""

    @property
    def foreign(self) -> bool:
        """A public body or a law of another country (not Italy, not the EU)."""
        c = self.country.strip().upper()
        return bool(c) and c not in ("IT", "UE", "EU") and not c.startswith("INTERNAZIONALE")

    @property
    def italian_or_eu_law(self) -> bool:
        return self.kind in LEGAL_KINDS and self.country.strip().upper() in ("IT", "UE", "EU")

    @property
    def full_citation(self) -> str:
        """The complete citation, written by the code from the metadata (Normativa,
        docs/compliance/20 §16: a foreign source carries its country)."""
        # the library's own note (e.g. "in vigore come modificata ... prorogata ogni anno")
        note = f" Nota sulla vigenza: {self.warning}" if self.warning else ""
        if self.foreign:
            note += f" Fonte di un altro Paese ({self.country}): non è una norma italiana."
        legal = self.kind in LEGAL_KINDS
        if legal and self.source_line:
            return f"{self.reference}, {self.title}. {self.source_line.rstrip('.')}.{note}"
        if legal and "normattiva" in f"{self.publisher} {self.link}".lower():
            return f"{self.reference}, {self.title}. {NORMATTIVA_NOTE}.{note}"
        if legal:
            return f"{self.reference}, {self.title}. {self.publisher}.{note}"
        parts = [self.reference, f"«{self.title}»" if self.title else ""]
        parts += [self.publisher, f"licenza {self.license}" if self.license else "", self.link]
        return ", ".join(p for p in parts if p) + "." + note


@dataclass(frozen=True)
class Passage:
    pid: str
    doc: Doc
    section: str
    text: str


def _first_number(value: Any) -> float:
    match = re.search(r"\d+(?:[.,]\d+)?", str(value or ""))
    return float(match.group(0).replace(",", ".")) if match else 0.0


def _as_tuple(value: Any) -> tuple[str, ...]:
    if isinstance(value, str):
        value = re.split(r"[,;]", value)
    # "piccoli-mammiferi" in the library cards, "piccoli mammiferi" in the reader
    return tuple(str(v).strip().lower().replace("-", " ") for v in (value or ()) if str(v).strip())


def _sections(data: dict[str, Any]) -> list[tuple[str, str]]:
    if isinstance(data.get("sezioni"), list):
        return [(str(s.get("titolo") or ""), str(s.get("testo") or "")) for s in data["sezioni"]]
    # one text: a short line followed by a blank line or a paragraph is a heading
    sections: list[tuple[str, str]] = []
    title, body = "", list[str]()
    raw = data.get("testo")
    text = "\n\n".join(map(str, raw)) if isinstance(raw, list) else str(raw or "")
    for block in re.split(r"\n\s*\n", text):
        block = block.strip()
        if not block:
            continue
        if len(block) < 90 and "\n" not in block and not block.endswith((".", ":", ";")):
            if body:
                sections.append((title, "\n\n".join(body)))
            title, body = block, []
        else:
            body.append(block)
    if body:
        sections.append((title, "\n\n".join(body)))
    return sections


def _chunks(text: str) -> list[str]:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    out: list[str] = []
    current = ""
    for paragraph in paragraphs:
        # a paragraph longer than a passage is cut at sentence ends
        pieces = [paragraph]
        if len(paragraph) > PASSAGE_CHARS * 1.5:
            pieces, piece = [], ""
            for sentence in re.split(r"(?<=[.!?])\s+", paragraph):
                if piece and len(piece) + len(sentence) > PASSAGE_CHARS:
                    pieces.append(piece)
                    piece = ""
                piece = f"{piece} {sentence}".strip()
            if piece:
                pieces.append(piece)
        for piece in pieces:
            if current and len(current) + len(piece) > PASSAGE_CHARS:
                out.append(current)
                current = ""
            current = f"{current}\n\n{piece}".strip()
    if current:
        out.append(current)
    return out


def load_library(folder: Path, only: set[str] | None = None) -> list[Passage]:
    """Every card of the folder (or only the file names in `only`, e.g. those listed in the
    library's indice.json, when texts of a batch still in progress sit in the folder),
    except "solo_abstract" ones: abstracts of articles that are not open never reach the
    model (Normativa, 17/11/2026); their metadata could only be a "per approfondire"
    reference, never the proof of a fact."""
    passages: list[Passage] = []
    for path in sorted(folder.glob("*.json")):
        if path.name == "indice.json" or (only is not None and path.name not in only):
            continue
        data = json.loads(path.read_text("utf-8"))
        if not isinstance(data, dict):
            continue
        abstract_only = bool(data.get("solo_abstract"))
        if abstract_only:
            continue
        # A government text whose licence line is only on the site is admitted
        # (Normativa, docs/compliance/20 §17; doc 21 §2: "non coincidono" = contradict).
        doc = Doc(
            id=str(data.get("id") or path.stem),
            reference=str(data.get("riferimento_breve") or data.get("id") or path.stem),
            level=int(_first_number(data.get("livello")) or 4),
            kind=str(data.get("tipo") or "studio").lower(),
            year=int(_first_number(data.get("anno"))),
            journal_value=_first_number(data.get("valore_rivista")),
            species=_as_tuple(data.get("specie")),
            topics=_as_tuple(data.get("temi")),
            language=str(data.get("lingua") or "en"),
            license=str(data.get("licenza") or ""),
            title=str(data.get("titolo") or ""),
            publisher=str(data.get("rivista_o_ente") or data.get("rivista") or ""),
            link=str(data.get("doi") or data.get("url") or ""),
            abstract_only=abstract_only,
            warning=str(data.get("avvertenza_vigenza") or ""),
            source_line=str(data.get("riga_fonte") or ""),
            country=str(data.get("paese") or ""),
        )
        n = 0
        for title, body in _sections(data):
            if SKIPPED_SECTIONS.match(title):
                continue
            for chunk in _chunks(body):
                if REPEALED.search(chunk):
                    continue  # e.g. L. 281/1991's notes quoting the repealed DPR 320/1954
                n += 1
                passages.append(Passage(f"{doc.id}#{n}", doc, title, chunk))
    return passages


def hierarchy_key(doc: Doc) -> tuple[int, int, int, float, int]:
    """Doc 21 §1: level first; a text older than 15 years goes under the newer ones of
    its level; then the kind (reviews before single studies before case reports);
    the journal's citation index breaks ties between studies; then the newest year."""
    old = 1 if doc.year and doc.year < CURRENT_YEAR - OLD_AFTER_YEARS else 0
    return (doc.level, old, TYPE_RANK.get(doc.kind, 3), -doc.journal_value, -doc.year)


class LibraryIndex:
    def __init__(self, passages: Sequence[Passage]) -> None:
        self.passages = list(passages)
        self.db = sqlite3.connect(":memory:", check_same_thread=False)
        self.db.execute(
            "create virtual table p using fts5(body, title, "
            "tokenize='porter unicode61 remove_diacritics 2')"
        )
        self.db.executemany(
            "insert into p(rowid, body, title) values (?, ?, ?)",
            [
                (i, x.text, f"{x.doc.title} {x.section} {' '.join(x.doc.topics)}")
                for i, x in enumerate(self.passages)
            ],
        )

    def search(self, words: Sequence[str], group: str, k: int = 15) -> list[tuple[Passage, float]]:
        # single words joined by OR: whole expressions as phrases almost never match
        # (17/11 test: "dog xylitol ingestion" found nothing, "xylitol" the right text)
        terms = sorted(
            {
                f'"{t}"'
                for word in words
                for t in re.findall(r"\w{3,}", word.lower())
                if t not in STOPWORDS
            }
        )
        if not terms:
            return []
        rows = self.db.execute(
            "select rowid, bm25(p, 1.0, 0.5) from p where p match ? order by 2 limit 200",
            (" OR ".join(terms),),
        ).fetchall()
        hits = [(self.passages[r], -score) for r, score in rows]
        wanted = [h for h in hits if _species_fits(h[0].doc, group)]
        return (wanted or hits)[:k]


def _species_fits(doc: Doc, group: str) -> bool:
    if not doc.species or "tutti" in doc.species or not group or group == "altro":
        return True
    aliases = {
        "piccoli mammiferi": (
            "piccoli mammiferi",
            "coniglio",
            "cavia",
            "cincillà",
            "criceto",
            "roditori",
            "furetto",
            "ratto",
            "topo",
            "gerbillo",
            "degu",
        ),
        "coniglio": ("coniglio", "piccoli mammiferi"),
        "furetto": ("furetto", "piccoli mammiferi"),
        "uccelli": ("uccelli", "uccello", "pappagalli", "cocorita", "calopsite", "canarino"),
        "rettili": (
            "rettili",
            "tartaruga",
            "testuggine",
            "pogona",
            "serpenti",
            "geco",
            "camaleonte",
        ),
        "anfibi": ("anfibi", "axolotl"),
        "pesci": ("pesci", "pesce", "acquario", "betta"),
    }
    names = aliases.get(group, (group,))
    return any(any(n in s for n in names) for s in doc.species)


def select(hits: Sequence[tuple[Passage, float]], n: int = 5) -> list[Passage]:
    """Without the model: the passages close to the best match (BM25), then the
    hierarchy decides the order; at most two passages of the same document."""
    if not hits:
        return []
    best = hits[0][1]
    close = [p for p, score in hits if score >= best * 0.5]
    close.sort(key=lambda p: hierarchy_key(p.doc))
    chosen: list[Passage] = []
    for passage in close:
        if sum(c.doc.id == passage.doc.id for c in chosen) < 2:
            chosen.append(passage)
        if len(chosen) == n:
            break
    return chosen


# --- model steps -------------------------------------------------------------------

READER_SYSTEM = """Leggi il messaggio di un proprietario di animali e rispondi SOLO con un \
oggetto JSON, senza testo attorno:
{"gruppo": uno tra GRUPPI, "tema": "2-5 parole in italiano", \
"pericolo": true se la salute o la vita dell'animale possono essere in pericolo adesso \
(possibile urgenza veterinaria), altrimenti false, \
"comportamento_pericoloso": true se l'animale ha un comportamento pericoloso verso persone o \
altri animali (morde, attacca, ferisce), altrimenti false, \
"vaga": true solo se senza 2-3 domande non si può dire nulla di utile (sintomo senza \
contesto, "sta male", "è strano"), altrimenti false, \
"domande": se vaga, 2-3 domande brevi nella lingua del proprietario, altrimenti [], \
"persona": true se una persona è stata ferita o è in pericolo (morso, graffio profondo, \
aggressione), altrimenti false, \
"salute": true se la domanda riguarda la salute dell'animale (sintomi, malattie, cure), \
altrimenti false, \
"parole_en": 4-8 parole o brevi espressioni di ricerca in inglese tecnico (nomi di specie, \
segni, malattie, gesti), "parole_it": 3-6 parole di ricerca in italiano}
GRUPPI = cane, gatto, coniglio, piccoli mammiferi, furetto, uccelli, rettili, anfibi, pesci, \
altro.
Le parole di ricerca non contengono MAI nomi propri, luoghi, e-mail, numeri di telefono o altri \
dati personali: solo specie, segni e temi."""

RERANK_SYSTEM = """Ti do una domanda di un proprietario e dei passi numerati presi da testi \
ufficiali e scientifici. Scegli da 2 a 6 passi che contengono informazioni utili a un \
PROPRIETARIO per rispondere a QUESTA domanda per QUESTA specie (non terapie o procedure che \
fa il veterinario). Rispondi SOLO con un oggetto JSON: {"scelti": [numeri]}. Se nessuno \
serve: {"scelti": []}."""

WRITER_SYSTEM = """Sei l'assistente di Quokka, un'app che aiuta i proprietari a capire e \
gestire il proprio animale in modo responsabile: non forma veterinari. Rispondi in {lingua}, \
in prosa semplice da proprietario, 150-180 parole (meno se basta), senza elenchi lunghi né \
titoli.

Regole, tutte obbligatorie:
- Usa SOLO i fatti contenuti nei PASSI qui sotto. Dopo ogni frase che contiene un fatto dei \
passi metti il numero del passo tra parentesi quadre, per esempio [2]. Al massimo 3 passi \
diversi in tutta la risposta. Non scrivere mai nomi di autori, enti, riviste, leggi o anni e non \
dire che qualcuno approva la risposta: i riferimenti li aggiunge il programma.
- Le frasi senza fatti (rinvio allo specialista, invito a osservare, domande) non hanno numero.
- Se c'è un pericolo per l'animale o una persona ferita, il programma apre già la risposta con \
l'invito a contattare \
subito un veterinario (e il pronto soccorso per una persona ferita): NON ripeterlo. Comincia \
da ciò che i passi dicono di utile adesso; puoi indicare lo specialista più adatto (per \
esempio "veterinario esperto in animali esotici", "educatore cinofilo o veterinario \
comportamentalista").
- Mai farmaci, dosi, terapie, interventi chirurgici o procedure che fa il veterinario, anche se \
i passi li descrivono: al massimo di' che le cure le decide il veterinario.
- Non inventare sintomi o fatti che il proprietario non ha scritto.
- Se i passi non contengono nulla di utile per questa domanda, scrivi solo: {segno}
- Se la domanda è vaga (indicato sotto), fai 2-3 domande brevi per capire; puoi aggiungere al \
massimo una frase utile dai passi.
- I passi sono spesso in inglese e tecnici: traduci in parole semplici.
- Nel testo non parlare mai di "passi", "fonti", "testi" o "documenti": scrivi direttamente \
i fatti.
- Non ripetere cose già dette nella conversazione."""

CHECKER_SYSTEM = """Controlli una risposta scritta per un proprietario di animali. Ogni frase \
numerata della risposta deve poggiare sui PASSI indicati. Per ogni frase decidi:
- "sostenuta": un passo dice davvero questo (anche con parole diverse o tradotto);
- "generica": non contiene fatti specifici (rinvio al veterinario o allo specialista, invito a \
osservare o a scrivere, domanda, frase di cortesia) oppure è uno dei passi universali di \
prudenza: chiamare o andare subito dal veterinario o dal pronto soccorso, non aspettare, tenere \
l'animale calmo e al sicuro, non forzarlo a mangiare o a bere, non dare farmaci o rimedi di \
propria iniziativa, non provocare il vomito, portare con sé la confezione o l'etichetta del \
prodotto, far vedere da un medico una persona ferita;
- "terapia": nomina un farmaco, una dose, una terapia, un intervento o una procedura che fa il \
veterinario (anche se il passo la descrive);
- "non_sostenuta": contiene un fatto, un numero, un gesto o un consiglio che i passi NON dicono, \
o dice di più di quanto dicono.
Rispondi SOLO con un oggetto JSON: {"frasi": [{"n": 1, "esito": "sostenuta"|"generica"|\
"terapia"|"non_sostenuta", "motivo": "breve, solo se non è sostenuta o generica"}]}"""

GENERAL_SYSTEM = """Rispondi a un proprietario di animali in {lingua}, in prosa semplice, \
150-180 parole al massimo. Rispondi in base a conoscenze generali e sii prudente: se qualcosa \
è incerto dillo. Mai farmaci, dosi, terapie o procedure veterinarie; non inventare sintomi o \
fatti che il proprietario non ha scritto; se c'è un possibile pericolo, dillo per primo e \
indica a quale specialista rivolgersi. Niente asterischi né riferimenti a fonti."""

REMOVED_VERDICTS = ("non_sostenuta", "terapia")


@dataclass
class Turn:
    user: str
    assistant: str
    cited: list[str] = field(default_factory=list)


@dataclass
class LibraryAnswer:
    text: str
    reader: dict[str, Any]
    candidates: list[str]
    chosen: list[str]
    draft: str
    verdicts: list[dict[str, Any]]
    removed: list[dict[str, str]]
    rewritten: bool
    cited: list[str]
    offered_general: bool
    danger: bool = False
    # who saw the danger: "lettore" (the model reading the question), "regole" (the
    # production safety gate), both, or neither
    danger_by: list[str] = field(default_factory=list)
    # fixed sentence added for the part without a source: "", "urgente" or "semplice"
    no_source_note: str = ""


def _json(text: str) -> dict[str, Any]:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return {}
    try:
        data = json.loads(match.group(0))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _passages_block(passages: Sequence[Passage]) -> str:
    return "\n\n".join(
        f"[{i}] ({p.doc.kind}, livello {p.doc.level}; {p.doc.title[:120]})"
        + (
            f"\nNOTA SULLA VIGENZA (rispettala: non presentare come in vigore ciò che la nota "
            f"dice superato o abrogato): {p.doc.warning}"
            if p.doc.warning
            else ""
        )
        + f"\n{p.text}"
        for i, p in enumerate(passages, 1)
    )


def _history_block(history: Sequence[Turn]) -> str:
    if not history:
        return ""
    return (
        "CONVERSAZIONE FINORA:\n"
        + "\n\n".join(f"Proprietario: {t.user}\nAssistente: {t.assistant}" for t in history)
        + "\n\n"
    )


_SENTENCE = re.compile(r"(?<=[.!?])\s+(?=\S)|\n+")


def sentences(text: str) -> list[str]:
    return [s.strip() for s in _SENTENCE.split(text) if s.strip()]


def read(call: Call, message: str, pet: str, history: Sequence[Turn]) -> dict[str, Any]:
    user = f"Animale: {pet}\n\n{_history_block(history)}MESSAGGIO: {message}"
    data = _json(call(READER_SYSTEM, user, "reader"))
    if data.get("gruppo") not in SPECIES_GROUPS:
        data["gruppo"] = "altro"
    return data


def rerank(call: Call, message: str, pet: str, hits: Sequence[Passage]) -> list[Passage]:
    if not hits:
        return []
    user = f"Animale: {pet}\nDomanda: {message}\n\nPASSI:\n{_passages_block(hits)}"
    picked = _json(call(RERANK_SYSTEM, user, "rerank")).get("scelti") or []
    chosen = [hits[i - 1] for i in picked if isinstance(i, int) and 0 < i <= len(hits)]
    chosen.sort(key=lambda p: hierarchy_key(p.doc))
    return chosen[:6]


def render(
    draft: str, passages: Sequence[Passage], already_cited: Sequence[str]
) -> tuple[str, list[str]]:
    """[n] placeholders -> one asterisk mark per source (at most 3) and the complete
    citation at the end; a source already cited in this conversation keeps neither
    (the caller's "Fonti di questa conversazione" list has it). Returns the text and
    the doc ids cited for the first time."""
    # "[1]", "[1][2]", "[1], [2]" and "[2, 1]"
    group = re.compile(r"\s*(?:\[\d+(?:\s*,\s*\d+)*\](?:\s*,?\s*)?)+")
    # One source per group of placeholders ("[1][2]" -> one mark): the first one already
    # cited in this answer, else the first that can still be added. Text and notes are
    # built from the same choice (20/11: a second source of a group got a note but no mark).
    order: list[Passage] = []
    marks: list[str] = []
    for match in group.finditer(draft):
        candidates = [
            passages[int(n) - 1]
            for n in re.findall(r"\d+", match.group(0))
            if 0 < int(n) <= len(passages)
        ]
        chosen = next(
            (p for p in candidates if any(o.doc.id == p.doc.id for o in order)), None
        ) or next(
            (p for p in candidates if p.doc.id not in already_cited and len(order) < len(STARS)),
            None,
        )
        if chosen is not None and all(o.doc.id != chosen.doc.id for o in order):
            order.append(chosen)
        ids_now = [o.doc.id for o in order]
        marks.append(
            STARS[ids_now.index(chosen.doc.id)]
            if chosen is not None and chosen.doc.id in ids_now
            else ""
        )
    ids = [p.doc.id for p in order]
    pending = iter(marks)
    body = group.sub(lambda m: next(pending) + " ", draft)
    body = re.sub(r" +([.,;:!?])", r"\1", body)
    body = re.sub(r"[ \t]+\n", "\n", re.sub(r" {2,}", " ", body)).strip()
    if order:
        body += "\n\n" + "\n".join(f"{STARS[i]} {p.doc.full_citation}" for i, p in enumerate(order))
    return body, ids


def write(
    call: Call,
    message: str,
    pet: str,
    language: str,
    passages: Sequence[Passage],
    reader: dict[str, Any],
    history: Sequence[Turn],
    feedback: str = "",
) -> str:
    system = WRITER_SYSTEM.replace("{lingua}", LANGUAGE.get(language, "italiano")).replace(
        "{segno}", NO_SOURCE_MARK
    )
    vague = bool(reader.get("vaga")) and not history
    notes = [
        f"Pericolo per l'animale: {'sì' if reader.get('pericolo') else 'no'}. "
        f"Persona ferita o in pericolo: {'sì' if reader.get('persona') else 'no'}. "
        "Comportamento pericoloso verso persone o animali: "
        f"{'sì' if reader.get('comportamento_pericoloso') else 'no'}.",
        f"Domanda vaga: {'sì' if vague else 'no'}.",
    ]
    if vague and reader.get("domande"):
        notes.append("Domande suggerite: " + " | ".join(map(str, reader["domande"])))
    if feedback:
        notes.append(
            "RISCRITTURA: la versione precedente conteneva frasi senza appoggio nei passi o "
            "terapie. Togli o correggi queste frasi:\n" + feedback
        )
    user = (
        f"Animale: {pet}\n\n{_history_block(history)}MESSAGGIO: {message}\n\n"
        + "\n".join(notes)
        + f"\n\nPASSI:\n{_passages_block(passages) or '(nessun passo trovato)'}"
    )
    return call(system, user, "writer").strip()


def check(call: Call, draft: str, passages: Sequence[Passage]) -> list[dict[str, Any]]:
    items = sentences(draft)
    numbered = "\n".join(f"{i}. {s}" for i, s in enumerate(items, 1))
    user = f"PASSI:\n{_passages_block(passages)}\n\nRISPOSTA, FRASE PER FRASE:\n{numbered}"
    verdicts = _json(call(CHECKER_SYSTEM, user, "checker")).get("frasi") or []
    by_n = {int(v["n"]): v for v in verdicts if isinstance(v, dict) and str(v.get("n")).isdigit()}
    return [
        {
            "sentence": s,
            "verdict": str(by_n.get(i, {}).get("esito") or "sostenuta"),
            "reason": str(by_n.get(i, {}).get("motivo") or ""),
        }
        for i, s in enumerate(items, 1)
    ]


def _danger(reader: dict[str, Any], message: str, species: str) -> list[str]:
    """Who sees which danger: "animale" (reader), "regole" (the production safety gate,
    animal emergencies), "persona" (a person hurt or at risk), "comportamento"
    (dangerous behaviour towards people or animals). Any of them: no general-knowledge
    offer; the urgent openings only for the animal and for a person."""
    by = []
    if reader.get("pericolo"):
        by.append("animale")
    if SafetyGate().evaluate(message, species):
        by.append("regole")
    if reader.get("persona"):
        by.append("persona")
    if reader.get("comportamento_pericoloso"):
        by.append("comportamento")
    return by


def answer(
    call: Call,
    index: LibraryIndex,
    *,
    message: str,
    pet: str,
    species: str,
    language: str,
    history: Sequence[Turn],
    use_rerank: bool,
) -> LibraryAnswer:
    """Danger (reader or rule-based gate): fixed urgent opening, then what the library
    supports, "Su questo non ho una fonte da citarti." for the rest, never the offer.
    No danger: what the library supports, the fixed no-source sentence for the rest;
    nothing at all -> the notice with the offer of a general-knowledge answer."""
    reader = read(call, message, pet, history)
    danger_by = _danger(reader, message, species)
    danger = bool(danger_by)
    vague = bool(reader.get("vaga")) and not history
    words = [*map(str, reader.get("parole_en") or []), *map(str, reader.get("parole_it") or [])]
    hits = index.search(words, str(reader.get("gruppo") or ""))
    candidates = [p.pid for p, _ in hits]
    chosen = rerank(call, message, pet, [p for p, _ in hits]) if use_rerank else select(hits)
    draft = write(call, message, pet, language, chosen, reader, history) if chosen else ""
    usable = bool(chosen) and NO_SOURCE_MARK not in draft
    verdicts = check(call, draft, chosen) if usable else []
    removed = [v for v in verdicts if v["verdict"] in REMOVED_VERDICTS]
    rewritten = False
    factual = [v for v in verdicts if v["verdict"] != "generica"]
    if removed and factual and len(removed) * 3 >= len(factual):
        rewritten = True
        feedback = "\n".join(f"- {v['sentence']} ({v['reason']})" for v in removed)
        draft = write(call, message, pet, language, chosen, reader, history, feedback)
        verdicts = check(call, draft, chosen)
        removed = removed + [v for v in verdicts if v["verdict"] in REMOVED_VERDICTS]
    removed_rows = [
        {"sentence": v["sentence"], "reason": v["reason"], "verdict": v["verdict"]} for v in removed
    ]
    supported = any(v["verdict"] == "sostenuta" for v in verdicts)
    unsupported_removed = any(v["verdict"] == "non_sostenuta" for v in verdicts)
    base: dict[str, Any] = {
        "reader": reader,
        "candidates": candidates,
        "chosen": [p.pid for p in chosen],
        "draft": draft,
        "verdicts": verdicts,
        "removed": removed_rows,
        "rewritten": rewritten,
        "danger": danger,
        "danger_by": danger_by,
    }
    if not danger and not supported and not vague:
        return LibraryAnswer(
            text=OFFER.get(language, OFFER["it"]), cited=[], offered_general=True, **base
        )
    body, cited, note = "", list[str](), ""
    if supported or vague:
        kept = " ".join(v["sentence"] for v in verdicts if v["verdict"] not in REMOVED_VERDICTS)
        text = (kept or draft).replace(NO_SOURCE_MARK, "").strip()
        body, cited = render(text, chosen, [d for t in history for d in t.cited])
        # A sentence the checker removed is invisible to the owner: a fixed "su questo
        # non ho una fonte" after it would point at nothing (17/11 test). Counted only.
        note = "tolte_senza_frase" if unsupported_removed else ""
    elif danger:
        note = "urgente"
        body = NO_SOURCE_URGENT.get(language, NO_SOURCE_URGENT["it"])
    openings = []
    if "animale" in danger_by or "regole" in danger_by:
        openings.append(URGENT_OPENING.get(language, URGENT_OPENING["it"]))
    if "persona" in danger_by:
        openings.append(PERSON_URGENT.get(language, PERSON_URGENT["it"]))
    if openings:
        body = f"{' '.join(openings)}\n\n{body}".strip()
    return LibraryAnswer(
        text=without_dose_sentences(body),
        cited=cited,
        offered_general=False,
        no_source_note=note,
        **base,
    )


def general_answer(
    call: Call,
    *,
    message: str,
    pet: str,
    species: str,
    language: str,
    history: Sequence[Turn],
    reader: dict[str, Any],
) -> dict[str, Any]:
    """Only after the owner accepted the offer, valid for this one question: the model
    from memory, labelled by the code, without asterisks or named sources (sentences
    naming bodies, authors, studies, guidelines or links are dropped), no doses; danger
    checked again on the answer (the urgent opening goes first if the gate finds it);
    a health question closes with "Per la salute del tuo animale decide il veterinario"."""
    system = GENERAL_SYSTEM.replace("{lingua}", LANGUAGE.get(language, "italiano"))
    user = f"Animale: {pet}\n\n{_history_block(history)}MESSAGGIO: {message}"
    raw = call(system, user, "generale").strip().replace("*", "")
    lines, dropped = [], []
    for line in raw.split("\n"):  # line by line, so lists keep their shape
        kept = []
        for sentence in re.split(r"(?<=[.!?])\s+", line):
            if _NAMED_SOURCE.search(sentence) or _NAMED_BODY.search(sentence):
                dropped.append(sentence)
            else:
                kept.append(sentence)
        if kept or not line.strip():
            lines.append(" ".join(kept))
    text = without_dose_sentences(re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip())
    after = SafetyGate().evaluate(text, species)
    if reader.get("salute"):
        text += " " + HEALTH_NOTE.get(language, HEALTH_NOTE["it"])
    if after:
        text = f"{URGENT_OPENING.get(language, URGENT_OPENING['it'])}\n\n{text}"
    label = GENERAL_LABEL.get(language, GENERAL_LABEL["it"])
    return {"text": f"{label}\n\n{text}", "dropped_named": dropped, "danger_after": after}
