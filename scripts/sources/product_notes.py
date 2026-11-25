"""Note prodotto per la chat (Orchestratore 25/11): cosa dice l'etichetta o il produttore.

Solo prodotti NON farmacologici. Ogni nota nasce da UNA pagina di un produttore, di un
rivenditore, di un registro ufficiale o dall'etichetta stessa; mai forum, chat, social. Lo
strumento legge la pagina con il Fetcher (robots, pausa, registro, stop), poi controlla che:

- l'ente sia nell'elenco `host_prodotti.json` con i termini già letti e `uso` = "ok";
- la frase di prova (al massimo 25 parole) compaia nella pagina;
- ogni cifra della nota compaia nella pagina (nessuna cifra inventata o «aggiustata»);
- la nota non parli di farmaci.

L'esito è un file JSON in `.local/consegne/note_prodotti/`, nei campi di `ProductNote`
(packages/core/domain/knowledge/product_notes.py), più `host_stato`. La frase di prova va solo
nel registro interno `registro_note_prodotti.jsonl`, mai al modello della chat.
Il codice dell'app non si tocca: la nota la integra l'Orchestratore.
"""

from __future__ import annotations

import json
import re
from datetime import date, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from scripts.sources import licenses
from scripts.sources.fetcher import Fetcher

SOURCE_KINDS = ("label", "manufacturer", "seller", "register")
SPECIES = ("dog", "cat", "small_mammal", "bird", "reptile_amphibian", "fish", "other")
MAX_PROOF_WORDS = 25
MAX_PER_HOST_PER_NIGHT = 5  # parere della Normativa, §23.12: pagine una per una, mai il catalogo
RECHECK_DAYS = 90
USE_OK = ("fatti",)  # V-F: la assegna la Normativa, host per host
_NOT_A_SOURCE = re.compile(
    r"(?:forum|reddit|facebook|instagram|tiktok|youtube|twitter|x\.com|quora|discord|telegram|"
    r"whatsapp|blogspot|wordpress|medium\.com)"
)
# Fuori: prodotti presentati come cura, prevenzione o sotto controllo veterinario; tabelle per peso.
_CURE = re.compile(
    r"\b(?:cura|cure|curare|previen\w*|prevenzion\w*|prevenire|guarisc\w*|terapi\w*|sotto controllo"
    r"\s+veterinari\w*|cures?|treat\w*|prevent\w*|heal\w*|therap\w*|veterinary\s+(?:supervision|control))\b",
    re.IGNORECASE,
)
_PER_WEIGHT = re.compile(
    r"(?:/\s*kg|per\s+kg|per\s+chil\w+|\bkg\s+(?:di\s+)?peso|body\s*weight)", re.I
)
# Fuori: prezzi, offerte, foto, loghi, slogan (parere della Normativa, §23.12).
_NOT_A_FACT = re.compile(
    r"(?:[€$£]|\b(?:eur|usd|prezzo|price|sconto|discount|offerta|sale|add to cart|logo|foto|"
    r"photo)\b)",
    re.IGNORECASE,
)
_FIGURE = re.compile(r"\d+(?:[.,]\d+)*")
# Parole di farmaci: la lista vera sta nell'app; qui un controllo in più, a prova di errore.
_MEDICINE_HINTS = (
    "antibiotic",
    "antibiotico",
    "antiparass",
    "antiparasit",
    "cortison",
    "meloxicam",
    "carprofen",
    "ivermectin",
    "fenbendazol",
    "pentobarbital",
    "paracetamol",
    "ibuprofen",
    "prescription",
    "prescrizione",
)


def load_hosts(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    data: dict[str, Any] = json.loads(path.read_text("utf-8"))
    return data


def _host_entry(hosts: dict[str, Any], host: str) -> dict[str, Any] | None:
    host = host.lower().removeprefix("www.")
    for key, value in hosts.items():
        if host == key.lower().removeprefix("www."):
            entry: dict[str, Any] = value
            return entry
    return None


def figures(text: str) -> set[str]:
    """Le cifre di un testo, senza separatori finali: «1,5» e «1.5» restano distinte dal testo."""
    return {m.group(0).rstrip(".,") for m in _FIGURE.finditer(text)}


def spec_problems(spec: dict[str, Any], hosts: dict[str, Any]) -> list[str]:
    """Perché una scheda non può partire (prima di leggere la pagina)."""
    out: list[str] = []
    for key in ("id", "product", "maker", "species", "words", "says", "source_kind", "source_url"):
        if not spec.get(key):
            out.append(f"manca «{key}»")
    if out:
        return out
    if spec["source_kind"] not in SOURCE_KINDS:
        out.append("tipo di fonte non ammesso (label, manufacturer, seller, register)")
    parsed = urlparse(spec["source_url"])
    host = parsed.hostname or ""
    if parsed.scheme != "https" or not host:
        out.append("serve un indirizzo https")
    if _NOT_A_SOURCE.search(host):
        out.append("forum, chat e social non sono fonti")
    if any(s not in SPECIES for s in spec["species"]):
        out.append("specie non valida (dog, cat, small_mammal, bird, reptile_amphibian, fish)")
    if len(spec["says"]) > 600:
        out.append("«says» supera i 600 caratteri")
    low = f"{spec['product']} {spec['says']}".lower()
    if any(word in low for word in _MEDICINE_HINTS):
        out.append("sembra un farmaco: i farmaci non si dosano mai")
    if _CURE.search(low):
        out.append(
            "prodotto presentato come cura o prevenzione o sotto controllo veterinario: fuori"
        )
    if _NOT_A_FACT.search(low):
        out.append("niente prezzi, offerte, foto, loghi o slogan: solo fatti dell'etichetta")
    if _PER_WEIGHT.search(low):
        out.append("nessuna quantità per peso: scrivi «dipende dal peso, guarda l'etichetta»")
    if not spec.get("frase_prova"):
        out.append("manca la frase di prova")
    elif len(spec["frase_prova"].split()) > MAX_PROOF_WORDS:
        out.append(f"la frase di prova supera le {MAX_PROOF_WORDS} parole")
    elif figures(spec["says"]) and not figures(spec["frase_prova"]):
        out.append("la nota ha cifre ma la frase di prova non ne ha: copia la riga con le cifre")
    entry = _host_entry(hosts, host) if host else None
    if entry is None:
        out.append(f"{host}: ente non registrato in host_prodotti.json (robots e termini prima)")
    elif entry.get("uso") not in USE_OK:
        out.append(f"{host}: uso non permesso ({entry.get('nota', 'vedi host_prodotti.json')})")
    return out


def page_problems(spec: dict[str, Any], page_text: str) -> list[str]:
    """Perché la pagina letta non regge la nota."""
    out: list[str] = []
    if not licenses.proof_in_page(spec["frase_prova"], page_text):
        out.append("la frase di prova non compare nella pagina: copiala dalla pagina")
    page_figures = figures(page_text)
    missing = sorted(f for f in figures(spec["says"]) if f not in page_figures)
    if missing:
        out.append(f"cifre della nota che la pagina non ha: {', '.join(missing)}")
    return out


def source_line(spec: dict[str, Any], read_on: str) -> str:
    """Riga fonte voluta dalla Normativa (§23.12): casa madre, prodotto, data della scheda."""
    when = (
        f"scheda del {spec['scheda_data']}"
        if spec.get("scheda_data")
        else f"pagina letta il {read_on}"
    )
    if spec.get("versione"):
        when += f" (versione {spec['versione']})"
    market = f" Etichetta per il mercato: {spec['mercato']}." if spec.get("mercato") else ""
    return (
        f"Fonte: {spec['maker']}, {spec['product']}, {when}, {spec['source_url']}; "
        f"fatti riassunti da Quokka.{market}"
    )


def tonight_count(out_dir: Path, host: str) -> int:
    """Quante note di questo ente sono già state fatte oggi."""
    today, bare = date.today().isoformat(), host.lower().removeprefix("www.")
    count = 0
    for f in out_dir.glob("*.json") if out_dir.exists() else []:
        data = json.loads(f.read_text("utf-8"))
        same_host = (urlparse(data.get("source_url", "")).hostname or "").removeprefix(
            "www."
        ) == bare
        if data.get("read_on") == today and same_host:
            count += 1
    return count


def make_note(
    fetcher: Fetcher, spec: dict[str, Any], hosts: dict[str, Any], out_dir: Path
) -> tuple[str, dict[str, Any] | None]:
    """(esito, nota). Esiti: NOTA, SCHEDA_NON_VALIDA, PAGINA_NON_REGGE."""
    problems = spec_problems(spec, hosts)
    if problems:
        return "SCHEDA_NON_VALIDA: " + "; ".join(problems), None
    if (
        tonight_count(out_dir, urlparse(spec["source_url"]).hostname or "")
        >= MAX_PER_HOST_PER_NIGHT
    ):
        return f"LIMITE: al massimo {MAX_PER_HOST_PER_NIGHT} pagine per ente a notte", None
    page = fetcher.get(spec["source_url"])
    text = f"{page.text}\n{page.full_text}"
    if page.status != 200:
        return f"PAGINA_NON_LETTA: risposta {page.status}", None
    problems = page_problems(spec, text)
    if problems:
        return "PAGINA_NON_REGGE: " + "; ".join(problems), None
    host = urlparse(spec["source_url"]).hostname or ""
    entry = _host_entry(hosts, host) or {}
    note = {
        "product": spec["product"],
        "maker": spec["maker"],
        "species": list(spec["species"]),
        "words": list(spec["words"]),
        "says": spec["says"],
        "source_kind": spec["source_kind"],
        "source_url": spec["source_url"],
        "read_on": date.today().isoformat(),
        "riga_fonte": source_line(spec, date.today().isoformat()),
        "impronta": page.fingerprint,
        "host_stato": entry.get("approvato_dal_proprietario", "in attesa del sì del proprietario"),
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    note["ricontrollo_entro"] = (date.today() + timedelta(days=RECHECK_DAYS)).isoformat()
    (out_dir / f"{spec['id']}.json").write_text(
        json.dumps(note, ensure_ascii=False, indent=1) + "\n", "utf-8"
    )
    # La frase di prova resta SOLO nel registro interno: mai al modello della chat.
    log_path = out_dir.parent.parent / "cercafonti" / "registro_note_prodotti.jsonl"
    row = {
        "id": spec["id"],
        "host": host,
        "letta": note["read_on"],
        "frase_prova": spec["frase_prova"],
    }
    with log_path.open("a", encoding="utf-8") as log:
        log.write(json.dumps(row, ensure_ascii=False) + "\n")
    return "NOTA", note
