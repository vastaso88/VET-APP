"""Elenco vivo delle fonti del Cercafonti (un file JSON in `.local/cercafonti/`, fuori dal repo).

Una fonte = una pagina o un documento. Stati: in_uso (il silenzio del proprietario vale sì),
non_approvata (ha detto No: fuori dall'uso, non è una lista nera), in_sospeso (sparita o bloccata,
da rivedere). Scadenze: leggi 3 mesi, guide 6 mesi (piano del 21/11/2026, §5).
"""

from __future__ import annotations

import json
import os
import re
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Any

LEVELS = {
    "legge": "Legge o atto ufficiale",
    "guida_proprietari": "Guida pubblica per proprietari",
    "guida_professionisti": "Guida per professionisti (etologia, comportamento, ambiente)",
    "linea_guida": "Linea guida o consenso",
    "revisione": "Revisione sistematica o meta-analisi",
}
# in_uso (V, VR: il silenzio vale sì), non_approvata (No del proprietario), in_sospeso (N o
# sparita), in_attesa_normativa (G), non_usabile (R)
STATES = (
    "in_uso",
    "non_approvata",
    "in_sospeso",
    "in_attesa_normativa",
    "non_usabile",
    "scartata",
)  # scartata: letta e giudicata non adatta (qualità), mai sulla pagina
VALID_CLASSES = ("V", "VR", "G", "R", "N")
PROOF_FIELDS = ("frase", "url", "data", "regola", "robots", "terzi")  # frasi extra: "frasi_extra"
REQUIRED = (
    "id",
    "titolo",
    "url",
    "ente",
    "paese",
    "lingua",
    "livello",
    "scritto_per",
    "specie",
    "temi",
    "licenza",
    "classe",
    "perche",
    "stato",
    "notte",
)
# giorni entro cui rileggere la fonte (piano §5): leggi 3 mesi, tutto il resto 6 mesi
REVIEW_DAYS = {"legge": 92}
DEFAULT_REVIEW_DAYS = 183
SPECIES = [f"S{n:02d}" for n in range(1, 13)]
THEMES = [f"T{n:02d}" for n in range(1, 13)]


def slug(text: str, limit: int = 80) -> str:
    """Id adatto al database della pagina (lettere, numeri, trattini)."""
    out = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return out[:limit].strip("-") or "fonte"


def review_days(livello: str) -> int:
    return REVIEW_DAYS.get(livello, DEFAULT_REVIEW_DAYS)


def next_review(livello: str, since: date) -> str:
    return (since + timedelta(days=review_days(livello))).isoformat()


class SourceError(ValueError):
    pass


def validate(src: dict[str, Any]) -> None:
    missing = [k for k in REQUIRED if k not in src or src[k] in (None, "", [])]
    if missing:
        raise SourceError(f"campi mancanti: {', '.join(missing)}")
    if src["livello"] not in LEVELS:
        raise SourceError(f"livello sconosciuto: {src['livello']}")
    if src["classe"] not in VALID_CLASSES:
        raise SourceError(f"classe sconosciuta: {src['classe']}")
    if src["classe"] in ("V", "VR"):  # senza prova conservata la fonte non è verde (§23.10)
        proof = src.get("prova") or {}
        absent = [k for k in PROOF_FIELDS if not proof.get(k)]
        if absent:
            raise SourceError(f"prova della licenza incompleta: {', '.join(absent)}")
        phrases = [proof["frase"], *proof.get("frasi_extra", [])]
        if any(len(str(p).split()) > 25 for p in phrases):
            raise SourceError("frase della prova oltre 25 parole")
        if "controllata_nella_pagina" not in proof:
            raise SourceError("prova non verificata: la frase va cercata nella pagina scaricata")
    if src["stato"] not in STATES:
        raise SourceError(f"stato sconosciuto: {src['stato']}")
    if not set(src["specie"]) <= set(SPECIES) or not set(src["temi"]) <= set(THEMES):
        raise SourceError("codici di specie o tema non validi (S01-S12, T01-T12)")
    topics = src.get("argomenti", [])
    if not isinstance(topics, list) or not all(isinstance(x, str) and x.strip() for x in topics):
        raise SourceError("argomenti: lista di identificativi non vuoti")


@dataclass
class Store:
    path: Path

    def load(self) -> dict[str, dict[str, Any]]:
        if not self.path.exists():
            return {}
        data: dict[str, dict[str, Any]] = json.loads(self.path.read_text("utf-8"))
        return data

    def save(self, data: dict[str, dict[str, Any]]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True), "utf-8")
        tmp.replace(self.path)

    def add(self, src: dict[str, Any]) -> bool:
        """Aggiunge una fonte nuova (mai in uso se rossa); False se esiste già."""
        validate(src)
        if src["stato"] == "in_uso" and src["classe"] not in ("V", "VR"):
            raise SourceError("solo le fonti V e VR possono essere in uso")
        with self._locked():
            data = self.load()
            if src["id"] in data:
                return False
            src = dict(src)
            src.setdefault("visto", False)
            today = date.fromisoformat(src["notte"])
            src.setdefault("prossimo_controllo", next_review(src["livello"], today))
            data[src["id"]] = src
            self.save(data)
            return True

    @contextmanager
    def _locked(self) -> Iterator[None]:
        """Blocco semplice per più comandi insieme (file di lock, attesa breve)."""
        lock = self.path.with_suffix(".lock")
        lock.parent.mkdir(parents=True, exist_ok=True)
        for _ in range(200):
            try:
                handle = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                break
            except FileExistsError:
                if time.time() - lock.stat().st_mtime > 30:  # lock rimasto da un comando morto
                    lock.unlink(missing_ok=True)
                time.sleep(0.05)
        else:
            raise SourceError("elenco occupato da un altro comando")
        try:
            yield
        finally:
            os.close(handle)
            lock.unlink(missing_ok=True)

    def discard(self, source_id: str, motivo: str) -> None:
        """Fonte letta e giudicata non adatta: fuori dall'uso e dalla pagina."""
        with self._locked():
            data = self.load()
            data[source_id]["stato"] = "scartata"
            data[source_id]["motivo_scarto"] = motivo
            self.save(data)

    def apply_decision(self, source_id: str, decisione: str | None, nota: str = "") -> None:
        """Legge la scelta del proprietario: ok -> resta in uso; no -> non_approvata."""
        data = self.load()
        src = data[source_id]
        src["visto"] = decisione is not None or src.get("visto", False)
        if decisione == "no":
            src["stato"] = "non_approvata"
            src["nota_no"] = nota
        elif decisione == "ok" and src["stato"] == "non_approvata":
            src["stato"] = "in_uso"
        self.save(data)

    def due(self, today: date) -> list[dict[str, Any]]:
        """Fonti in uso o in sospeso la cui rilettura è scaduta (da riverificare con l'impronta)."""
        data = self.load()
        return [
            s
            for s in data.values()
            if s["stato"] != "non_approvata"
            and s.get("prossimo_controllo", "9999") <= today.isoformat()
        ]

    def topic_coverage(self) -> dict[str, int]:
        """Fonti verdi in uso per argomento (identificativi dell'elenco degli argomenti comuni)."""
        counts: dict[str, int] = {}
        for src in self.load().values():
            if src["stato"] != "in_uso" or src["classe"] not in ("V", "VR"):
                continue
            for topic in src.get("argomenti", []):
                counts[topic] = counts.get(topic, 0) + 1
        return counts

    def coverage(self) -> dict[str, int]:
        """Fonti in uso per casella `Sxx-Tyy` (solo verdi, né rosse né non approvate)."""
        counts: dict[str, int] = {}
        for src in self.load().values():
            if src["stato"] != "in_uso" or src["classe"] not in ("V", "VR"):
                continue
            for sp in src["specie"]:
                for th in src["temi"]:
                    counts[f"{sp}-{th}"] = counts.get(f"{sp}-{th}", 0) + 1
        return counts


def on_page(src: dict[str, Any]) -> bool:
    """Alla pagina vanno solo V, VR e N: i G alla Normativa, gli R al foglio."""
    return src["classe"] in ("V", "VR", "N") and src["stato"] != "scartata"


def page_doc(src: dict[str, Any]) -> dict[str, Any]:
    """Il documento che la pagina di controllo mostra (nessun testo della fonte, solo i dati)."""
    keys = (
        "titolo",
        "url",
        "ente",
        "paese",
        "lingua",
        "livello",
        "scritto_per",
        "specie",
        "temi",
        "licenza",
        "classe",
        "perche",
        "stato",
        "notte",
        "attribuzione",
        "avvertenza",
        "argomenti",
    )
    doc = {k: src[k] for k in keys if k in src}
    doc["visto"] = bool(src.get("visto"))
    doc["decisione"] = src.get("decisione")
    return doc
