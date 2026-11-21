"""Griglia delle licenze del Cercafonti (Normativa, docs/compliance/20 §23).

Classi: V verde, VR verde con riserva (opere federali USA), G giallo (si manda alla Normativa),
R rosso (mai usata), N non raggiungibile (diritti verdi, accesso bloccato).
La classificazione automatica è prudente: nel dubbio non è verde. Senza prova (frase di licenza
di al massimo 25 parole, indirizzo e data) una fonte non è verde (§23.10).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

V = "V"
VR = "VR"
G = "G"
R = "R"
N = "N"
ALL_CLASSES = (V, VR, G, R, N)
USABLE = (V, VR)  # il silenzio del proprietario vale «sì» solo per queste (§23.10)

# Solo nel linguaggio delle licenze: «non-commercial» da sola compare in qualunque testo.
_NC = re.compile(r"CC[ -]BY-NC|attribu(?:tion|zione)[- ]non[- ]?commercial|licenses/by-nc", re.I)
_ND = re.compile(
    r"CC[ -]BY-(?:NC-)?ND|attribution[- ](?:non[- ]?commercial[- ])?no[- ]?deriv"
    r"|licenses/by-(?:nc-)?nd",
    re.I,
)
_SA = re.compile(
    r"CC[ -]BY-(?:NC-)?SA|attribution[- ](?:non[- ]?commercial[- ])?share[- ]?alike"
    r"|licenses/by-(?:nc-)?sa",
    re.I,
)
_IGO = re.compile(r"\bIGO\b", re.I)
_RESERVED = re.compile(
    r"all rights reserved|tutti i diritti riservati|alle rechte vorbehalten"
    r"|tous droits r[ée]serv[ée]s|todos los derechos reservados|riproduzione vietata"
    r"|uso personale|personal use only|non[- ]commercial use",
    re.I,
)
_OGL = re.compile(r"open government licen[cs]e|nationalarchives\.gov\.uk/doc/open-government", re.I)
_CC0 = re.compile(r"\bCC0\b|creativecommons\.org/publicdomain/zero|public domain mark", re.I)
_CCBY = re.compile(
    r"creative commons attribu(?:tion|zione)(?! ?-?non)|CC[ -]BY(?:[ -]?(?:2\.0|2\.5|3\.0|4\.0))?\b"
    r"|creativecommons\.org/licenses/by/",
    re.I,
)
_IODL = re.compile(r"\bIODL\s*2\.0|italian open data licen[cs]e\s*2", re.I)
_LO = re.compile(r"licence ouverte|open licen[cs]e 2\.0", re.I)
_TDM = re.compile(r"tdm-reservation\s*[:=]\s*1", re.I)

# Agenzie del governo federale USA (17 U.S.C. §105): solo domini federali, non Stati né università.
US_FEDERAL_HOSTS = (
    "cdc.gov", "fda.gov", "usda.gov", "fws.gov", "usgs.gov", "nih.gov", "noaa.gov", "epa.gov",
    "nps.gov", "govinfo.gov", "ecfr.gov", "congress.gov",
)  # fmt: skip


@dataclass(frozen=True)
class Verdict:
    classe: str
    licenza: str
    motivo: str
    frase: str = ""  # frase esatta della prova, al massimo 25 parole


def host_matches(host: str, suffixes: tuple[str, ...]) -> bool:
    host = host.lower().split(":")[0]
    return any(host == s or host.endswith("." + s) for s in suffixes)


def evidence(text: str, pattern: re.Pattern[str], words: int = 25) -> str:
    """La frase (al massimo `words` parole) che contiene la prova della licenza."""
    match = pattern.search(text)
    if not match:
        return ""
    before = text[: match.start()].split()[-8:]
    after = text[match.end() :].split()[:12]
    return " ".join((before + match.group(0).split() + after)[:words])


def classify_text(text: str, *, host: str = "", official_act: bool = False) -> Verdict:
    """Classifica da un testo di licenza o di note legali (tabelle A e C del §23).

    `official_act`: vero solo per leggi e atti ufficiali di un Paese della tabella B (§23.3).
    """
    if official_act:
        return Verdict(V, "atto ufficiale", "tabella B: atto ufficiale")
    sample = text[:300_000]
    for pattern in (_NC, _ND, _SA):
        if pattern.search(sample):
            return Verdict(
                R, "NC/ND/SA", "riga 1032: CC con NC, ND o SA", evidence(sample, pattern)
            )
    if _TDM.search(sample):
        return Verdict(G, "riserva TDM", "riga 1031: licenza e tdm-reservation in conflitto")
    if _IGO.search(sample) and _CCBY.search(sample):
        return Verdict(G, "CC BY IGO", "riga 1028: IGO, clausole speciali", evidence(sample, _IGO))
    for pattern, name, why in (
        (_OGL, "OGL v3.0", "riga 1021: OGL"),
        (_CC0, "CC0", "riga 1019: CC0"),
        (_CCBY, "CC BY", "riga 1020: CC BY"),
        (_IODL, "IODL 2.0", "riga 1025: IODL 2.0"),
        (_LO, "Licence Ouverte 2.0", "riga 1023: Licence Ouverte"),
    ):
        if pattern.search(sample):
            return Verdict(V, name, why, evidence(sample, pattern))
    if host and host_matches(host, US_FEDERAL_HOSTS):
        if _RESERVED.search(sample):
            return Verdict(R, "diritti riservati", "© di terzi", evidence(sample, _RESERVED))
        return Verdict(
            VR,
            "opera del governo federale USA (17 U.S.C. §105)",
            "riga 1027: dominio di un'agenzia federale, solo testo",
            "17 U.S.C. §105: nessun diritto d'autore sulle opere del governo federale USA",
        )
    if _RESERVED.search(sample):
        return Verdict(R, "diritti riservati", "riga 1035", evidence(sample, _RESERVED))
    return Verdict(R, "nessuna licenza dichiarata", "§23.5: pagina senza licenza")
