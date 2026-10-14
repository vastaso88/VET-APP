"""Is the owner asking how much of a medicine to give?

The guard that refuses to give a dose (ChatOrchestrator._dosage_guard_result)
used to recognise only a handful of fixed phrases ("quanti mg", "che dose"…):
6 of 15 realistic requests were stopped in the 2026-10-14 stress test, and
the rest reached the model. A request is now recognised as
  (a way of asking an amount, or a dose word, or a fraction of a tablet)
  AND (a medicine, a pharmaceutical form, or a unit of a medicine)
matched as whole words on normalised text. Both halves are needed, so
"quanto deve mangiare?" or "quante dosi di vaccino?" are not stopped.
"""

from __future__ import annotations

import re

from packages.core.domain.safety.emergency_patterns import normalize_for_matching


def _words(pattern: str) -> re.Pattern[str]:
    return re.compile(rf"\b(?:{pattern})\b")


_MEDICINE_WORDS = (
    # units and pharmaceutical forms
    r"mg|ml|milligramm\w*|millilitr\w*|gocce|goccia|compress\w*|pastigli\w*|pillol\w*|"
    r"capsul\w*|cpr|fial\w*|bustin\w*|supposte?|supposit\w*|pipett\w*|sciropp\w*|"
    r"iniezion\w*|puntur\w*|"
    # kinds of medicine
    r"farmac\w*|medicin\w*|antibiotic\w*|antidolorific\w*|antinfiammatori\w*|"
    r"antiinfiammatori\w*|cortison\w*|antiparassitari\w*|vermifug\w*|antistaminic\w*|"
    r"sedativ\w*|calmant\w*|tranquillant\w*|antiemetic\w*|antiacid\w*|"
    # common names (veterinary and from the family medicine cabinet)
    r"metacam|meloxicam|rimadyl|carprofen\w*|previcox|firocoxib|onsior|robenacoxib|"
    r"novalgina|metamizolo|tachipirina|paracetamolo|aspirina|oki|ketoprofene|brufen|"
    r"nurofen|ibuprofene|amoxicillina|synulox|clavaseptin|baytril|enrofloxacina|"
    r"metronidazolo|prednisolone|prednisone|deltacortene|gabapentin\w*|tramadolo?|"
    r"cerenia|maropitant|apoquel|frontline|advantix|milbemax|drontal|stronghold|"
    r"bravecto|nexgard|simparica|seresto"
)
_MEDICINE = _words(_MEDICINE_WORDS)

_GIVE = r"(?:dare|dargli|darle|darne|do|dovrei dare|somministr\w*)"

# How much: "quanti mg", "quanta tachipirina", "quante gocce di…" (the
# medicine right after the question word), or "quanto/ogni quanto … dare".
# A question word alone is not enough: "quanto costa il metacam?", "quanto
# dura l'antibiotico?" are not requests for a dose.
_ASKS_AN_AMOUNT = re.compile(
    rf"\b(?:quant[oaie]) (?:di |del |della |dello |dei |delle |degli )?(?:{_MEDICINE_WORDS})\b"
    rf"|\b(?:quant[oaie]|ogni quanto)(?: \w+){{0,3}} {_GIVE}\b"
    r"|\b(?:dos[ei]|dosaggi\w*|posologi\w*)\b"
    r"|\b(?:raddoppi\w*|dimezz\w*)\b"
    r"|\b(?:mezz[ao]|meta|un quarto|un terzo)(?: \w+){0,2} (?:compress\w*|pastigli\w*|"
    r"pillol\w*|capsul\w*|fial\w*|bustin\w*)\b"
)

_VACCINE = _words(r"vaccin\w*|richiam\w*")


def is_dosage_request(message: str) -> bool:
    text = normalize_for_matching(message)
    if _VACCINE.search(text) and not _words(r"farmac\w*|mg|ml|compress\w*").search(text):
        # "quante dosi di vaccino deve fare?" is a schedule question.
        return False
    return bool(_ASKS_AN_AMOUNT.search(text) and _MEDICINE.search(text))
