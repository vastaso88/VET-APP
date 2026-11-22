"""Reading time of an answer, per language.

Silent reading speed of adults on standardised texts (IReST, Trauzettel-Klosinski & Dietz,
Invest Ophthalmol Vis Sci 2012;53:5452-5461), words per minute: Italian 188, English 228,
Spanish 218, German 179, French 195. Elderly readers and phone screens are slower: the
figure is a lower bound of the real time, good for comparing answers and rounds.
"""

from __future__ import annotations

import re

PAROLE_AL_MINUTO = {"it": 188, "en": 228, "es": 218, "de": 179, "fr": 195}
_WORD = re.compile(r"[^\W\d_]+(?:['’-][^\W\d_]+)*", re.UNICODE)


def parole(testo: str) -> int:
    return len(_WORD.findall(testo or ""))


def secondi_di_lettura(testo: str, lingua: str) -> float:
    speed = PAROLE_AL_MINUTO.get((lingua or "it").split("-")[0].lower(), 188)
    return round(parole(testo) * 60 / speed, 1)
