"""Fonti indipendenti (Orchestratore 22/11): più versioni dello stesso testo contano come UNA fonte.

Le versioni dello stesso codice per Inghilterra, Galles, Scozia e Irlanda del Nord, o lo stesso
testo ripubblicato da enti diversi, hanno testi quasi uguali. Si raggruppano le fonti in
«famiglie» con la sovrapposizione di sequenze di parole (shingle) tra i testi salvati; si può
correggere a mano con un file di famiglie. Le fonti indipendenti di un argomento sono le famiglie
diverse che lo trattano.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from scripts.sources.store import Store

SHINGLE = 8  # parole per sequenza
THRESHOLD = (
    0.30  # quota di sequenze in comune (sul testo più corto) oltre la quale è la stessa famiglia
)
MIN_WORDS = 60  # sotto questa lunghezza il confronto non è affidabile: la fonte resta da sola


def shingles(text: str) -> set[int]:
    words = re.findall(r"[a-zà-ÿ0-9]+", text.lower())
    if len(words) < MIN_WORDS:
        return set()
    return {hash(" ".join(words[i : i + SHINGLE])) for i in range(len(words) - SHINGLE + 1)}


def overlap(a: set[int], b: set[int]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / min(len(a), len(b))


def families(
    store: Store, pages: Path, manual: dict[str, str] | None = None, threshold: float = THRESHOLD
) -> dict[str, str]:
    """Per ogni fonte in uso, l'id della sua famiglia (l'id più piccolo del gruppo)."""
    sources = {
        sid: s
        for sid, s in store.load().items()
        if s["stato"] == "in_uso" and s["classe"] in ("V", "VR")
    }
    sets = {}
    for sid in sources:
        f = pages / f"{sid}.txt"
        sets[sid] = shingles(f.read_text("utf-8")) if f.exists() else set()
    parent = {sid: sid for sid in sources}

    def find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    ids = sorted(sources)
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            if overlap(sets[a], sets[b]) >= threshold:
                parent[find(b)] = find(a)
    for sid, target in (
        manual or {}
    ).items():  # correzioni a mano: «questa fonte è della famiglia X»
        if sid in parent and target in parent:
            parent[find(sid)] = find(target)
    return {sid: min(g for g in ids if find(g) == find(sid)) for sid in ids}


def topic_independence(store: Store, fam: dict[str, str]) -> dict[str, dict[str, Any]]:
    """Per argomento: numero di fonti e numero di fonti indipendenti (famiglie diverse)."""
    out: dict[str, dict[str, Any]] = {}
    for sid, src in store.load().items():
        if sid not in fam:
            continue
        for topic in src.get("argomenti", []):
            entry = out.setdefault(topic, {"fonti": 0, "famiglie": set()})
            entry["fonti"] += 1
            entry["famiglie"].add(fam[sid])
    return {
        t: {
            "fonti": e["fonti"],
            "indipendenti": len(e["famiglie"]),
            "famiglie": sorted(e["famiglie"]),
        }
        for t, e in out.items()
    }


def load_manual(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data: dict[str, str] = json.loads(path.read_text("utf-8"))
    return data
