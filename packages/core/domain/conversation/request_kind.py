"""What the owner is asking for, decided before any anamnesis.

Real-world feedback (build 22, 2026-10-05): asked "spiegami il referto",
the chat kept asking about the animal's symptoms. "Ask before assuming"
is right for a vague symptom and wrong for an explicit, self-contained
request — explaining a report or a value, what a term means, a practical
question about feeding, care, prevention or behaviour, a question about
the profile. Those are answered straight away.

Deliberately deterministic and coarse: three kinds are enough to change
what the chat does, and a wrong guess only loosens or tightens how many
questions the model may ask — the safety gate runs before any of this
and does not depend on it.
"""

from __future__ import annotations

import re
from enum import StrEnum


class RequestKind(StrEnum):
    # Explain a document or its values (a report in the cartella clinica,
    # a file attached to the message, figures typed by the owner).
    REPORT = "report"
    # An explicit, self-contained question: answer it now.
    DIRECT = "direct"
    # Something seems wrong with the animal: a short anamnesis is welcome
    # when the description is vague.
    SYMPTOM = "symptom"


# A reply this short that ends with a question mark gave the owner nothing
# but questions. A real answer that closes with one optional question is
# longer than this.
QUESTION_ONLY_MAX_CHARS = 500

# "Never more than two turns of questions in a row without giving
# something useful" — and none at all once the owner says to stop.
MAX_CONSECUTIVE_QUESTION_TURNS = 2

_DOCUMENT_WORDS = (
    "referto",
    "referti",
    "esame",
    "esami",
    "analisi",
    "emocromo",
    "ecografia",
    "ecografico",
    "radiografia",
    "lastra",
    "lastre",
    "biochimic",
    "citologic",
    "istologic",
    "risultat",
    "valori",
    "valore",
    "documento",
    "allegato",
    "cartella clinica",
)

# Names an owner reads on a lab report and asks about.
ANALYTES = (
    "creatinina",
    "urea",
    "azotemia",
    "sdma",
    "transaminasi",
    "fosforo",
    "potassio",
    "glicemia",
    "glucosio",
    "ematocrito",
    "emoglobina",
    "globuli",
    "piastrine",
    "leucociti",
    "albumina",
    "bilirubina",
    "colesterolo",
    "trigliceridi",
    "fosfatasi",
    "peso specifico",
    "proteine nelle urine",
    "proteinuria",
)

_EXPLAIN_MARKERS = (
    "spieg",
    "significa",
    "vuol dire",
    "vuole dire",
    "cosa dice",
    "che dice",
    "cosa c'è scritto",
    "cosa indica",
    "cosa risulta",
    "come sono",
    "com'è",
    "a posto",
    "va bene",
    "vanno bene",
    "normale",
    "normali",
    "alt",
    "bass",
    "interpret",
    "legg",
    "letto",
    "capire",
    "capisco",
    "riassum",
    "preoccup",
    "guarda",
    "vedi",
)

_INTERROGATIVE_OPENINGS = (
    "come ",
    "cosa ",
    "cos'",
    "che ",
    "quanto ",
    "quanta ",
    "quanti ",
    "quante ",
    "quando ",
    "ogni quanto",
    "perché ",
    "perche ",
    "può ",
    "puo ",
    "posso ",
    "possiamo ",
    "devo ",
    "si può",
    "si puo",
    "qual ",
    "quale ",
    "quali ",
    "dove ",
    "chi ",
    "è meglio",
    "meglio ",
    "mi consigli",
    "mi spieghi",
    "spiegami",
    "dimmi",
    "sai ",
)

# Something is wrong with the animal. Kept short and generic: its only
# job is to tell "my dog limps" from "how often should he eat".
_SYMPTOM_MARKERS = (
    "vomit",
    "diarrea",
    "tosse",
    "tossisce",
    "febbre",
    "dolore",
    "zoppica",
    "si gratta",
    "prurito",
    "mogio",
    "mogia",
    "abbattut",
    "apatic",
    "letarg",
    "non mangia",
    "mangia meno",
    "mangia poco",
    "non beve",
    "beve tanto",
    "beve molto",
    "respira",
    "trema",
    "sangue",
    "gonfi",
    "ferita",
    "perde pelo",
    "dimagri",
    "sta male",
    "non sta bene",
    "sembra giù",
    "strano",
    "strana",
    "si lamenta",
    "piange",
    "scuote la testa",
    "starnut",
    "secrezion",
    "non fa le feci",
    "non fa pipì",
    "fa fatica",
    "da ieri",
    "da stamattina",
    "da qualche giorno",
    "da due giorni",
    "da una settimana",
)

# The owner is telling the chat to stop interviewing.
_STOP_QUESTION_MARKERS = (
    "non c'entra",
    "non centra",
    "non c'entrano",
    "non centrano",
    "non ha sintomi",
    "nessun sintomo",
    "non ci sono sintomi",
    "voglio solo",
    "vorrei solo",
    "volevo solo",
    "mi serve solo",
    "rispondi e basta",
    "rispondimi e basta",
    "basta domande",
    "smetti di chiedere",
    "smettila di chiedere",
    "non farmi domande",
    "senza domande",
    "non lo so",
    "non saprei",
    "non so dire",
    "te l'ho già detto",
    "te l'ho gia detto",
    "l'ho già detto",
    "dimmelo comunque",
    "dimmi comunque",
    "rispondi comunque",
)


_NAMED_EXAM = re.compile(
    r"(esam\w+|analisi|prelievo|referto|controll\w+)\s+(del|della|delle|dei|di)\s+\w+"
)


def _has_any(text: str, markers: tuple[str, ...]) -> bool:
    return any(marker in text for marker in markers)


def _has_word(text: str, words: tuple[str, ...]) -> bool:
    return any(re.search(rf"\b{re.escape(word)}", text) for word in words)


def is_question(message: str) -> bool:
    lowered = message.strip().lower()
    return "?" in lowered or lowered.startswith(_INTERROGATIVE_OPENINGS)


def classify_request(message: str, *, has_attachment: bool = False) -> RequestKind:
    """`message` is what the owner typed (not the transcription of an
    attached file); `has_attachment` says a file came with it."""
    lowered = message.strip().lower()
    about_document = _has_word(lowered, _DOCUMENT_WORDS) or _has_word(lowered, ANALYTES)
    asks_to_explain = _has_any(lowered, _EXPLAIN_MARKERS)
    # "esami del sangue", "esame delle feci" name a document, not a symptom.
    describes_symptom = _has_any(_NAMED_EXAM.sub(" ", lowered), _SYMPTOM_MARKERS)

    if has_attachment and (asks_to_explain or is_question(lowered) or not describes_symptom):
        # "cosa dice?" with a file attached: the file is the subject.
        return RequestKind.REPORT
    if about_document and asks_to_explain and not describes_symptom:
        return RequestKind.REPORT
    if describes_symptom:
        return RequestKind.SYMPTOM
    if is_question(lowered) or _has_any(lowered, _EXPLAIN_MARKERS):
        return RequestKind.DIRECT
    # A bare statement ("Toby è mogio", "da ieri"): part of describing a
    # problem, where a question back can be the right move.
    return RequestKind.SYMPTOM


_DOCUMENT_TEXT = re.compile(
    r"referto|esame|esami|analisi|laboratorio|rif\.|riferimento|mg/dl|ecografi|prelievo|"
    r"ricetta|prescrizione|libretto|vaccinazion|diagnosi"
)


def looks_like_document(attachment_text: str) -> bool:
    """Whether the text read from an attached file is a document (a
    report, a prescription) rather than the description of a photo of the
    animal."""
    return bool(_DOCUMENT_TEXT.search(attachment_text.lower()))


def asks_to_stop_questions(message: str) -> bool:
    return _has_any(message.strip().lower(), _STOP_QUESTION_MARKERS)


def is_question_only(reply: str) -> bool:
    """True when a reply gives the owner nothing but questions."""
    text = reply.strip()
    return len(text) <= QUESTION_ONLY_MAX_CHARS and text.rstrip(" \n\t*_)»\"'").endswith("?")


def consecutive_question_turns(assistant_replies: list[str]) -> int:
    """How many of the most recent assistant replies, in a row, were
    question-only (`assistant_replies` oldest first)."""
    count = 0
    for reply in reversed(assistant_replies):
        if not is_question_only(reply):
            break
        count += 1
    return count


def may_ask_before_answering(
    kind: RequestKind, *, question_turns_in_a_row: int, owner_said_stop: bool
) -> bool:
    """Whether this reply may consist of questions only."""
    if owner_said_stop or kind is not RequestKind.SYMPTOM:
        return False
    return question_turns_in_a_row < MAX_CONSECUTIVE_QUESTION_TURNS
