"""One finding of a tester (`segnalazioni.jsonl`, one JSON object per line).

Fields (all text in plain Italian, short):
    chat, giro, tipo, gravita, funzione, specie, titolo, cosa_succede, perche_conta,
    come_riprodurre (list of steps), proposta, lavoro (piccolo|medio|grande),
    risposta_sbagliata (bool), fonte, prima, dopo (image paths), richiesta (timing ref), at.

Rules of the plan:
- severity scale: Bloccante, Grave, Fastidio, Ritocco;
- a finding that says «the answer is wrong» carries a source from the local library or the
  words «senza fonte, da verificare»;
- `abuso` findings (villains) never go to the public repository while the hole is open, and
  their page card says the risk in plain words, never the steps.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

GRAVITA = ("bloccante", "grave", "fastidio", "ritocco")
TIPI = ("funzioni", "estetica", "rischi_legali", "tempi", "abuso")
LAVORO = ("piccolo", "medio", "grande", "")
SENZA_FONTE = "senza fonte, da verificare"


class SegnalazioneNonValida(ValueError):
    pass


@dataclass
class Segnalazione:
    chat: str
    giro: str
    tipo: str
    gravita: str
    titolo: str
    cosa_succede: str
    funzione: str = ""
    specie: str = ""
    perche_conta: str = ""
    come_riprodurre: list[str] = field(default_factory=list)
    proposta: str = ""
    lavoro: str = ""
    risposta_sbagliata: bool = False
    fonte: str = ""
    prima: str = ""
    dopo: str = ""
    richiesta: str = ""
    at: str = ""

    def __post_init__(self) -> None:
        self.tipo = self.tipo.strip().lower()
        self.gravita = self.gravita.strip().lower()
        if self.tipo not in TIPI:
            raise SegnalazioneNonValida(f"tipo tra {TIPI}")
        if self.gravita not in GRAVITA:
            raise SegnalazioneNonValida(f"gravità tra {GRAVITA}")
        if self.lavoro not in LAVORO:
            raise SegnalazioneNonValida(f"lavoro tra {LAVORO[:-1]}")
        if not self.titolo.strip() or not self.cosa_succede.strip():
            raise SegnalazioneNonValida("titolo e cosa_succede sono obbligatori")
        if len(self.titolo) > 140:
            raise SegnalazioneNonValida("titolo oltre 140 caratteri: accorcialo")
        if self.risposta_sbagliata and not self.fonte.strip():
            self.fonte = SENZA_FONTE
        if not self.at:
            self.at = datetime.now(UTC).isoformat(timespec="seconds")

    @classmethod
    def da_dict(cls, raw: dict[str, Any]) -> Segnalazione:
        known = {name for name in cls.__dataclass_fields__}
        return cls(**{key: value for key, value in raw.items() if key in known})

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def aggiungi(path: Path, segnalazione: Segnalazione) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(segnalazione.to_dict(), ensure_ascii=False) + "\n")


def leggi(path: Path) -> tuple[list[Segnalazione], list[str]]:
    """(valid findings, problems with line numbers). A broken line never stops the summary."""
    found: list[Segnalazione] = []
    problems: list[str] = []
    if not path.is_file():
        return found, problems
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            found.append(Segnalazione.da_dict(json.loads(line)))
        except (ValueError, TypeError) as error:
            problems.append(f"{path.name}:{number}: {error}")
    return found, problems
