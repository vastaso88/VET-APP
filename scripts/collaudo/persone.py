"""The 17 testers of the network (`persone.json`) and the coverage matrix.

Rule of the plan: every species group and every function has at least 2 FUNCTIONAL users
(villains and aesthetics do not count). `buchi()` lists what is missing.
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

PERSONE_FILE = Path(__file__).with_name("persone.json")
MINIMO = 2


def carica(path: Path = PERSONE_FILE) -> dict[str, Any]:
    data: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    return data


def persona(chat: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
    for item in (data or carica())["persone"]:
        if item["chat"] == chat:
            return dict(item)
    raise KeyError(f"persona sconosciuta: {chat}")


def risolvi_account(nome: str, data: dict[str, Any] | None = None) -> tuple[str, int]:
    """`col-villain-chat-b` -> (`col-villain-chat`, 1): the extra accounts (the villains'
    «victim» for the user-B checks) are named after their tester. Anything else -> (nome, 0)."""
    base, _, suffix = nome.rpartition("-")
    if base and len(suffix) == 1 and suffix in "bcdefghij":
        index = "abcdefghij".index(suffix)
        for item in (data or carica())["persone"]:
            if item["chat"] == base and int(item.get("account_extra", 0)) >= index:
                return base, index
    return nome, 0


def email_account(chat: str, indice: int = 0) -> str:
    """Synthetic address: `col-x@example.com`, the extra ones `col-x-b@example.com`, ..."""
    suffix = "" if indice == 0 else "-" + "abcdefghij"[indice]
    return f"{chat}{suffix}@example.com"


def account_di(item: dict[str, Any]) -> list[str]:
    extra = int(item.get("account_extra", 0))
    return [email_account(item["chat"], i) for i in range(extra + 1)]


def matrice(data: dict[str, Any]) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """(species group -> functional users, function -> functional users)."""
    specie: dict[str, list[str]] = defaultdict(list)
    funzioni: dict[str, list[str]] = defaultdict(list)
    for item in data["persone"]:
        if item["tipo"] != "funzionale":
            continue
        for gruppo in sorted({pet.get("gruppo", "") for pet in item["animali"]} - {""}):
            specie[gruppo].append(item["chat"])
        for funzione in item["funzioni"]:
            funzioni[funzione].append(item["chat"])
    return dict(specie), dict(funzioni)


def buchi(data: dict[str, Any]) -> list[str]:
    specie, funzioni = matrice(data)
    missing: list[str] = []
    for gruppo in data["gruppi_specie"]:
        if len(specie.get(gruppo, [])) < MINIMO:
            missing.append(f"specie {gruppo}: {specie.get(gruppo, [])}")
    for funzione in data["funzioni"]:
        if len(funzioni.get(funzione, [])) < MINIMO:
            missing.append(f"funzione {funzione}: {funzioni.get(funzione, [])}")
    unknown_groups = set(specie) - set(data["gruppi_specie"])
    unknown_functions = set(funzioni) - set(data["funzioni"])
    missing += [f"gruppo non in elenco: {name}" for name in sorted(unknown_groups)]
    missing += [f"funzione non in elenco: {name}" for name in sorted(unknown_functions)]
    return missing


def tabella_copertura(data: dict[str, Any]) -> str:
    """Markdown table for the page («Copertura») and the reports."""
    specie, funzioni = matrice(data)
    lines = ["| Voce | Utenti funzionali |", "|---|---|"]
    for gruppo in data["gruppi_specie"]:
        lines.append(f"| specie: {gruppo} | {', '.join(specie.get(gruppo, [])) or '—'} |")
    for funzione in data["funzioni"]:
        lines.append(f"| funzione: {funzione} | {', '.join(funzioni.get(funzione, [])) or '—'} |")
    return "\n".join(lines)


if __name__ == "__main__":
    loaded = carica()
    print(tabella_copertura(loaded))
    gaps = buchi(loaded)
    print("\nBuchi:", gaps or "nessuno")
