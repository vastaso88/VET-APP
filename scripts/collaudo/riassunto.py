"""Merge the testers' findings and timings of one round into cards and a one-page summary.

    python -m scripts.collaudo.riassunto <giro>

Reads `.local/collaudo/giro-<giro>/<chat>/{segnalazioni,tempi,risposte}.jsonl` and writes,
in the same folder:
- `schede.json`: the cards for the «Collaudo Quokka» page (doubles merged, the 15 most
  important marked `in_evidenza`); villain (`abuso`) cards keep only the risk and the
  proposal, never the steps;
- `riassunto.md`: one page for the owner;
- `problemi.txt`: broken lines in the testers' files, if any.

Doubles: same type and function, and titles that say the same thing (similarity >= 0.72
after lower-casing and dropping punctuation). The merged card keeps the highest severity,
every tester who found it and how many times.
"""

from __future__ import annotations

import json
import math
import re
import sys
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from pathlib import Path
from statistics import median
from typing import Any

from scripts.collaudo.config import output_root
from scripts.collaudo.segnalazioni import GRAVITA, Segnalazione, leggi

SOGLIA_DOPPIONE = 0.72
IN_EVIDENZA = 15
REGOLA_SECONDI_CHAT = 20.0
_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)


def _norm(text: str) -> str:
    return " ".join(_PUNCT.sub(" ", text.lower()).split())


def simili(a: str, b: str) -> bool:
    return SequenceMatcher(None, _norm(a), _norm(b)).ratio() >= SOGLIA_DOPPIONE


@dataclass
class Scheda:
    id: str
    tipo: str
    gravita: str
    funzione: str
    titolo: str
    cosa_succede: str
    perche_conta: str
    proposta: str
    lavoro: str
    chi: list[str] = field(default_factory=list)
    volte: int = 0
    specie: list[str] = field(default_factory=list)
    fonte: str = ""
    come_riprodurre: list[str] = field(default_factory=list)
    prima: str = ""
    dopo: str = ""
    in_evidenza: bool = False

    def add(self, item: Segnalazione) -> None:
        self.volte += 1
        if item.chat not in self.chi:
            self.chi.append(item.chat)
        if item.specie and item.specie not in self.specie:
            self.specie.append(item.specie)
        if GRAVITA.index(item.gravita) < GRAVITA.index(self.gravita):
            self.gravita = item.gravita
        for name in ("perche_conta", "proposta", "lavoro", "fonte", "prima", "dopo"):
            if not getattr(self, name) and getattr(item, name):
                setattr(self, name, getattr(item, name))
        if not self.come_riprodurre and item.come_riprodurre:
            self.come_riprodurre = list(item.come_riprodurre)

    def per_pagina(self) -> dict[str, Any]:
        data = dict(self.__dict__)
        if self.tipo == "abuso":
            # The page says the risk and the fix in plain words, never how to do it.
            data["come_riprodurre"] = []
        return data


def unisci(items: list[Segnalazione]) -> list[Scheda]:
    cards: list[Scheda] = []
    for item in items:
        match = next(
            (
                card
                for card in cards
                if card.tipo == item.tipo
                and card.funzione == item.funzione
                and simili(card.titolo, item.titolo)
            ),
            None,
        )
        if match is None:
            match = Scheda(
                id=f"S{len(cards) + 1:03d}",
                tipo=item.tipo,
                gravita=item.gravita,
                funzione=item.funzione,
                titolo=item.titolo,
                cosa_succede=item.cosa_succede,
                perche_conta="",
                proposta="",
                lavoro="",
            )
            cards.append(match)
        match.add(item)
    cards.sort(key=lambda c: (GRAVITA.index(c.gravita), -len(c.chi), -c.volte, c.id))
    for index, card in enumerate(cards):
        card.in_evidenza = index < IN_EVIDENZA
    return cards


def _p90(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(0.9 * len(ordered)) - 1)]


def tempi(folder: Path) -> dict[str, dict[str, float]]:
    groups: dict[str, list[int]] = {}
    for path in sorted(folder.glob("*/tempi.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            entry = json.loads(line)
            groups.setdefault(f"{entry['metodo']} {entry['percorso']}", []).append(
                int(entry["total_ms"])
            )
    return {
        key: {
            "volte": len(values),
            "mediana_s": round(median(values) / 1000, 2),
            "p90_s": round(_p90(values) / 1000, 2),
            "massimo_s": round(max(values) / 1000, 2),
        }
        for key, values in sorted(groups.items())
    }


def risposte(folder: Path) -> dict[str, float]:
    server: list[float] = []
    reading: list[float] = []
    for path in sorted(folder.glob("*/risposte.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                entry = json.loads(line)
                server.append(float(entry.get("secondi_server", 0)))
                reading.append(float(entry.get("secondi_lettura", 0)))
    if not server:
        return {}
    return {
        "risposte": len(server),
        "mediana_server_s": round(median(server), 1),
        "oltre_20_s": sum(1 for value in server if value > REGOLA_SECONDI_CHAT),
        "mediana_lettura_s": round(median(reading), 1),
    }


def scrivi(numero: str, root: Path | None = None) -> Path:
    folder = (root or output_root()) / f"giro-{numero}"
    items: list[Segnalazione] = []
    problems: list[str] = []
    for path in sorted(folder.glob("*/segnalazioni.jsonl")):
        found, broken = leggi(path)
        items += found
        problems += [f"{path.parent.name}/{line}" for line in broken]
    cards = unisci(items)
    timings = tempi(folder)
    chat_numbers = risposte(folder)
    (folder / "schede.json").write_text(
        json.dumps([card.per_pagina() for card in cards], ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    if problems:
        (folder / "problemi.txt").write_text("\n".join(problems) + "\n", encoding="utf-8")
    (folder / "riassunto.md").write_text(
        riassunto_md(numero, cards, timings, chat_numbers), encoding="utf-8"
    )
    return folder


def riassunto_md(
    numero: str,
    cards: list[Scheda],
    timings: dict[str, dict[str, float]],
    chat_numbers: dict[str, float],
) -> str:
    counts = {level: sum(1 for c in cards if c.gravita == level) for level in GRAVITA}
    lines = [
        f"# Collaudo, giro {numero}: riassunto",
        "",
        "Avvertenze: sul ramo di prova l'avvio a freddo è più lento che in produzione; il "
        "database del gemello è quasi vuoto (ricerche più veloci); la conferma e-mail è "
        "spenta (i risultati sull'iscrizione non valgono).",
        "",
        f"Schede: {len(cards)} (bloccanti {counts['bloccante']}, gravi {counts['grave']}, "
        f"fastidi {counts['fastidio']}, ritocchi {counts['ritocco']}).",
        "",
        "## In evidenza",
        "",
    ]
    for card in [c for c in cards if c.in_evidenza]:
        who = ", ".join(card.chi)
        lines.append(f"- **{card.gravita.capitalize()}** · {card.titolo} ({who}; {card.volte}×)")
    if chat_numbers:
        lines += [
            "",
            "## Chat",
            "",
            f"- risposte: {chat_numbers['risposte']:.0f}; tempo del server (mediana): "
            f"{chat_numbers['mediana_server_s']} s; oltre 20 s: {chat_numbers['oltre_20_s']:.0f}",
            f"- tempo di lettura (mediana): {chat_numbers['mediana_lettura_s']} s",
        ]
    slow = sorted(timings.items(), key=lambda kv: -kv[1]["p90_s"])[:8]
    if slow:
        lines += ["", "## Le chiamate più lente (p90)", ""]
        lines += [f"- {key}: mediana {v['mediana_s']} s, p90 {v['p90_s']} s" for key, v in slow]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    print(f"scritto in {scrivi(sys.argv[1])}")
