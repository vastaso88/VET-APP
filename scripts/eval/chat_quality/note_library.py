"""Library of compact notes that grows from verified answers (plan docs/llm/08, work B).

One note = one fact, written in our own words for the model: species group, theme, claim,
conditions, sources (body or authors, year, link, level, written for whom), verification
date, score, expiry. Only facts found in a passage of a white-list source and confirmed by
the checker enter; never what the model "remembers", never user data.

Rules enforced here (Normativa docs/compliance/20 §18):
- groups: (a) open or official sites, no cap; (b) rights reserved without explicit bans, at
  most 1% of the site's pages and in any case 50 notes (20 when the size is unknown), alarm
  at half the cap; (c) asks for a permission or forbids automated/commercial use: zero;
- no run of 6 or more words identical to the source, checked while the passage is in memory
  (the passage is never stored);
- no user data (contact details, numbers, names, words copied from the question);
- all notes of a site can be removed at once (a site asks: within 3 days);
- 12-month expiry; an expired note no longer counts as sufficient and is re-read.
Nothing here calls a provider: the model steps (relation between two notes, note writing)
are passed in as functions, so the rules are tested without a model.
"""

from __future__ import annotations

import json
import re
import uuid
from collections.abc import Callable, Iterable, Sequence
from dataclasses import asdict, dataclass, field
from datetime import date, timedelta
from pathlib import Path
from typing import Literal

# The grid of docs/product/21 §9 (closed lists: searches are built only from these codes).
SPECIES_GROUPS = {
    "S00": "tutte le specie",
    "S01": "cani",
    "S02": "gatti",
    "S03": "conigli",
    "S04": "cavie e cincillà",
    "S05": "piccoli roditori (criceti, ratti, topi, gerbilli, degu)",
    "S06": "furetti",
    "S07": "uccelli da gabbia (pappagalli, cocorite, calopsiti, canarini)",
    "S08": "rettili (lucertole, gechi, camaleonti, serpenti)",
    "S09": "testuggini e tartarughe",
    "S10": "anfibi (axolotl, rane, tritoni)",
    "S11": "pesci d'acqua dolce",
    "S12": "acquario marino",
}
THEMES = {
    "T01": "alimentazione",
    "T02": "ambiente e alloggio",
    "T03": "cura quotidiana",
    "T04": "comportamento e convivenza",
    "T05": "prevenzione",
    "T06": "segni per cui andare dal veterinario",
    "T07": "cose tossiche e pericolose",
    "T08": "cuccioli e anziani",
    "T09": "riproduzione",
    "T10": "viaggi",
    "T11": "doveri e leggi",
    "T12": "fine vita",
}
ALL_SPECIES = "S00"
LEGAL_KINDS = frozenset(
    {
        "legge",
        "decreto",
        "regolamento",
        "regolamento ue",
        "ordinanza",
        "ordinanza ministeriale",
        "codice",
        "atto ufficiale",
        "direttiva",
    }
)
REVIEW_KINDS = frozenset({"rassegna", "revisione sistematica", "meta-analisi", "review"})
EXPIRY_DAYS = 182  # owner decision 2026-11-20: notes expire after 6 months
MAX_RUN = 6  # Normativa §18: no identical sequence of 6 or more words
CAP_B_MAX, CAP_B_UNKNOWN, CAP_B_SHARE = 50, 20, 0.01

Relation = Literal["uguale", "nuovo", "contrasto"]
Outcome = Literal["creata", "unita", "gia_presente", "sostituita", "discorde", "scartata"]


@dataclass(frozen=True)
class Source:
    ente: str  # body or authors
    anno: int
    link: str
    livello: int  # 1 law or public body, 2 scientific society, 3 study, 4 manual/private body
    tipo: str  # "legge", "guida ufficiale", "rassegna", "studio", ...
    per_chi: str  # "P" owners, "PR" professionals, "L" law
    dominio: str
    gruppo: str = "a"  # Normativa §18 group of the site
    indice_rivista: float = 0.0

    @property
    def rank(self) -> int:
        """Plan 08: law, then official guide, then scientific society, then review, then
        single study; manuals and private bodies last. Lower is better."""
        kind = self.tipo.lower()
        if kind in LEGAL_KINDS:
            return 0
        if self.livello == 1:
            return 1
        if self.livello == 2:
            return 2
        if kind in REVIEW_KINDS:
            return 3
        if self.livello == 3:
            return 4
        return 5


@dataclass
class Note:
    specie: str
    tema: str
    affermazione: str
    condizioni: str
    fonti: list[Source]
    verificata_il: str  # ISO date
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])
    stato: Literal["attiva", "archiviata"] = "attiva"
    discorde_con: list[str] = field(default_factory=list)
    sostituita_da: str | None = None
    archiviata_il: str | None = None
    motivo_archivio: str | None = None
    non_utile: int = 0  # "non mi è stata utile": lowers priority, sends to re-check

    @property
    def scadenza(self) -> str:
        return (date.fromisoformat(self.verificata_il) + timedelta(days=EXPIRY_DAYS)).isoformat()

    def expired(self, today: date) -> bool:
        return today.isoformat() >= self.scadenza

    @property
    def independent_sources(self) -> int:
        return len({s.dominio or s.ente for s in self.fonti})

    def score_key(self) -> tuple[int, int, int, int, float]:
        """Plan 08 score, lower is better: (1) best source level, (2) independent sources
        that agree, (3) written for owners, (4) most recent year, (5) journal citation
        index as the last tie-break."""
        return (
            min(s.rank for s in self.fonti),
            -self.independent_sources,
            0 if any(s.per_chi == "P" for s in self.fonti) else 1,
            -max(s.anno for s in self.fonti),
            -max(s.indice_rivista for s in self.fonti),
        )

    def good(self, today: date) -> bool:
        """Enough to answer without reading: law, official guide, or two agreeing sources;
        active, not expired, not flagged as unhelpful."""
        if self.stato != "attiva" or self.expired(today) or self.non_utile > 0:
            return False
        return min(s.rank for s in self.fonti) <= 1 or self.independent_sources >= 2

    @property
    def text(self) -> str:
        return f"{self.affermazione} {self.condizioni}".strip()


# --- checks while the source passage is still in memory -------------------------------

_WORD = re.compile(r"\w+", re.UNICODE)


def _words(text: str) -> list[str]:
    return [w.lower() for w in _WORD.findall(text)]


def longest_common_run(a: str, b: str) -> int:
    """Length in words of the longest identical word sequence shared by a and b."""
    x, y = _words(a), _words(b)
    if not x or not y:
        return 0
    best = 0
    previous = [0] * (len(y) + 1)
    for i in range(1, len(x) + 1):
        current = [0] * (len(y) + 1)
        xi = x[i - 1]
        for j in range(1, len(y) + 1):
            if xi == y[j - 1]:
                current[j] = previous[j - 1] + 1
                if current[j] > best:
                    best = current[j]
        previous = current
    return best


_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")
_PHONE = re.compile(r"(?:\+\d{1,3}[\s.-]?)?(?:\d[\s.-]?){8,}")
_URL = re.compile(r"https?://\S+|www\.\S+", re.IGNORECASE)


def user_data_problems(note: Note, forbidden: Sequence[str]) -> list[str]:
    """No user data in a note (plan 08, gate "nessuna nota con dati dell'utente"):
    contact details, long numbers (phone, microchip), links, names given by the user,
    and no 6-word run copied from the user's message."""
    text = note.text
    problems = []
    if _EMAIL.search(text):
        problems.append("e-mail")
    if _PHONE.search(text):
        problems.append("numero lungo (telefono o microchip)")
    if _URL.search(text):
        problems.append("indirizzo web nel testo della nota")
    lowered = f" {' '.join(_words(text))} "
    for item in forbidden:
        if not item.strip():
            continue
        if len(_words(item)) <= 3:  # a name: must not appear as a word
            if f" {' '.join(_words(item))} " in lowered:
                problems.append("nome dato dall'utente")
        elif longest_common_run(text, item) >= MAX_RUN:
            problems.append("parole copiate dalla domanda")
    return problems


# --- white list and per-site caps ------------------------------------------------------


@dataclass(frozen=True)
class Site:
    dominio: str
    gruppo: str  # "a", "b", "c"
    pagine_stimate: int | None = None

    @property
    def cap(self) -> int | None:
        if self.gruppo == "a":
            return None
        if self.gruppo != "b":
            return 0
        if not self.pagine_stimate:
            return CAP_B_UNKNOWN
        return min(CAP_B_MAX, int(self.pagine_stimate * CAP_B_SHARE))


def site_of(link: str) -> str:
    host = re.sub(r"^https?://", "", link.strip().lower()).split("/")[0]
    return host.removeprefix("www.")


# --- the library ---------------------------------------------------------------------


@dataclass
class AddResult:
    outcome: Outcome
    note_id: str | None = None
    reason: str = ""
    other_ids: list[str] = field(default_factory=list)
    alarm: str = ""


RelateFn = Callable[[Note, Note], Relation]


def _content_words(text: str) -> set[str]:
    return {w for w in _words(text) if len(w) > 3}


class NoteLibrary:
    def __init__(self, sites: Iterable[Site] = ()) -> None:
        self.notes: dict[str, Note] = {}
        self.sites = {s.dominio: s for s in sites}
        self.counts: dict[str, int] = {}

    # persistence (one JSON file; the eval keeps it under .local/)
    def save(self, path: Path) -> None:
        data = {
            "notes": [asdict(n) for n in self.notes.values()],
            "sites": [asdict(s) for s in self.sites.values()],
            "counts": self.counts,
        }
        path.write_text(json.dumps(data, ensure_ascii=False, indent=1), "utf-8")

    @classmethod
    def load(cls, path: Path) -> NoteLibrary:
        data = json.loads(path.read_text("utf-8"))
        library = cls(Site(**s) for s in data.get("sites") or [])
        for raw in data.get("notes") or []:
            raw = dict(raw)
            raw["fonti"] = [Source(**s) for s in raw.get("fonti") or []]
            note = Note(**raw)
            library.notes[note.id] = note
        library.counts = dict(data.get("counts") or {})
        return library

    def _count(self, outcome: str) -> None:
        self.counts[outcome] = self.counts.get(outcome, 0) + 1

    def active(self, specie: str | None = None, tema: str | None = None) -> list[Note]:
        return [
            n
            for n in self.notes.values()
            if n.stato == "attiva"
            and (specie is None or n.specie == specie)
            and (tema is None or n.tema == tema)
        ]

    def site_count(self, domain: str) -> int:
        return sum(1 for n in self.active() if any(s.dominio == domain for s in n.fonti))

    def _site_allows(self, source: Source) -> tuple[bool, str]:
        site = self.sites.get(source.dominio) or Site(source.dominio, source.gruppo)
        cap = site.cap
        if cap is None:
            return True, ""
        used = self.site_count(source.dominio)
        if used >= cap:
            return False, f"tetto di {cap} note raggiunto per {source.dominio}"
        alarm = f"{source.dominio}: {used + 1} note su {cap}" if used + 1 >= cap / 2 else ""
        return True, alarm

    def similar(self, note: Note, k: int = 5, threshold: float = 0.25) -> list[Note]:
        """Notes of the same cell sharing enough content words (Jaccard)."""
        words = _content_words(note.text)
        if not words:
            return []
        scored = []
        for other in self.active(note.specie, note.tema):
            theirs = _content_words(other.text)
            overlap = len(words & theirs) / max(1, len(words | theirs))
            if overlap >= threshold:
                scored.append((overlap, other))
        scored.sort(key=lambda x: -x[0])
        return [n for _, n in scored[:k]]

    def add(
        self,
        note: Note,
        relate: RelateFn,
        *,
        passage: str,
        forbidden: Sequence[str] = (),
    ) -> AddResult:
        """Save a fact verified in an answer: checks, then merge / replace / keep both."""
        result = self._add(note, relate, passage=passage, forbidden=forbidden)
        self._count(result.outcome)
        return result

    def _add(
        self, note: Note, relate: RelateFn, *, passage: str, forbidden: Sequence[str]
    ) -> AddResult:
        if note.specie not in SPECIES_GROUPS or note.tema not in THEMES:
            return AddResult("scartata", reason="casella fuori griglia")
        if len(note.fonti) != 1:
            return AddResult("scartata", reason="una nota nuova nasce da una sola fonte")
        source = note.fonti[0]
        if source.gruppo == "c":
            return AddResult("scartata", reason="sito del gruppo (c): nessuna nota")
        run = longest_common_run(note.text, passage)
        if run >= MAX_RUN:
            return AddResult("scartata", reason=f"{run} parole identiche alla fonte")
        problems = user_data_problems(note, forbidden)
        if problems:
            return AddResult("scartata", reason="dati dell'utente: " + ", ".join(problems))
        allowed, alarm = self._site_allows(source)
        if not allowed:
            return AddResult("scartata", reason=alarm)
        today = date.fromisoformat(note.verificata_il)
        contrasts: list[Note] = []
        for other in self.similar(note):
            relation = relate(note, other)
            if relation == "uguale":
                if any(s.dominio == source.dominio and s.link == source.link for s in other.fonti):
                    other.verificata_il = max(other.verificata_il, note.verificata_il)
                    return AddResult("gia_presente", other.id, alarm="")
                other.fonti.append(source)
                other.verificata_il = max(other.verificata_il, note.verificata_il)
                return AddResult("unita", other.id, alarm=alarm)
            if relation == "contrasto":
                contrasts.append(other)
        if not contrasts:
            self.notes[note.id] = note
            return AddResult("creata", note.id, alarm=alarm)
        new_key = note.score_key()
        stronger = [o for o in contrasts if o.score_key()[0] < new_key[0]]
        if stronger:
            # an established note with a better source level wins: the new one is kept only
            # in the archive (it can be looked at, never served)
            self._archive(note, today, f"in contrasto con una nota migliore ({stronger[0].id})")
            self.notes[note.id] = note
            return AddResult("scartata", note.id, "punteggio più basso", [o.id for o in stronger])
        same_level = [o for o in contrasts if o.score_key()[0] == new_key[0]]
        weaker = [o for o in contrasts if o.score_key()[0] > new_key[0]]
        for old in weaker:
            self._archive(old, today, "sostituita da una nota con fonte di livello migliore")
            old.sostituita_da = note.id
        self.notes[note.id] = note
        if same_level:
            # equal level and in disagreement: both stay, marked, and the chat says so
            for old in same_level:
                old.discorde_con.append(note.id)
                note.discorde_con.append(old.id)
            return AddResult("discorde", note.id, other_ids=[o.id for o in same_level], alarm=alarm)
        return AddResult("sostituita", note.id, other_ids=[o.id for o in weaker], alarm=alarm)

    def _archive(self, note: Note, today: date, reason: str) -> None:
        note.stato = "archiviata"
        note.archiviata_il = today.isoformat()
        note.motivo_archivio = reason

    def remove_site(self, domain: str) -> dict[str, int]:
        """A site asks: every note built on it goes (archive included). Notes that also have
        other sources only lose that source; with none left they are deleted."""
        dropped = trimmed = 0
        for note_id in list(self.notes):
            note = self.notes[note_id]
            kept = [s for s in note.fonti if s.dominio != domain]
            if len(kept) == len(note.fonti):
                continue
            if kept:
                note.fonti = kept
                trimmed += 1
            else:
                del self.notes[note_id]
                dropped += 1
        for note in self.notes.values():
            note.discorde_con = [i for i in note.discorde_con if i in self.notes]
        return {"cancellate": dropped, "fonte_tolta": trimmed}

    def expired(self, today: date) -> list[Note]:
        return [n for n in self.active() if n.expired(today)]

    def flag_unhelpful(self, note_id: str) -> None:
        if note_id in self.notes:
            self.notes[note_id].non_utile += 1


# --- sufficiency and verification index ------------------------------------------------


@dataclass
class Sufficiency:
    enough: bool
    found: dict[str, Note]  # needed fact -> good note
    missing: list[str]  # facts to read on demand (absent, weak or expired)


MatchFn = Callable[[str, Sequence[Note]], Note | None]
# all the facts against the cell in one call (test 2 report §4, proposal 4)
MatchManyFn = Callable[[Sequence[str], Sequence[Note]], dict[str, Note]]


def sufficiency(
    library: NoteLibrary,
    specie: str,
    tema: str,
    needed: Sequence[str],
    match: MatchFn | None,
    today: date,
    *,
    match_many: MatchManyFn | None = None,
) -> Sufficiency:
    """Plan 08 step 2: for each fact the question needs there must be a good note in the
    cell. "The library has something" is not enough. The facts found are served from the
    library even when others are missing; only the missing ones are read on demand."""
    cell = [n for n in library.active(specie, tema) if n.good(today)]
    if specie != ALL_SPECIES:
        cell += [n for n in library.active(ALL_SPECIES, tema) if n.good(today)]
    found: dict[str, Note] = {}
    if cell and match_many is not None:
        found = {f: n for f, n in match_many(needed, cell).items() if f in needed}
    elif cell and match is not None:
        for fact in needed:
            note = match(fact, cell)
            if note is not None:
                found[fact] = note
    missing = [fact for fact in needed if fact not in found]
    return Sufficiency(enough=bool(needed) and not missing, found=found, missing=missing)


IndexLevel = Literal["verde", "giallo", "grigio"]
# Normativa compliance/20 §18.5: the index is called "Fonti"; never "Verificata". It is an
# element of the interface, never text of the answer (owner decision 2026-11-20).
INDEX_NAME = "Fonti"
INDEX_LABEL = {
    "verde": "Con fonti ufficiali",
    "giallo": "In parte con fonti",
    "grigio": "Senza fonti: conoscenze generali dell'IA",
}


def verification_index(*, claims: int, supported_levels: Sequence[int]) -> IndexLevel:
    """Computed by the code from what was verified, never declared by the model.
    Green only if every checkable sentence has a match in a law or a public body's
    document (level 1); a scientific society, a manual, an association or an article
    makes it yellow; nothing supported: grey. No urgency case apart (owner, 20/11)."""
    if not claims or not supported_levels:
        return "grigio"
    if len(supported_levels) >= claims and all(level == 1 for level in supported_levels):
        return "verde"
    return "giallo"
