"""Cercafonti: registro delle licenze per host, inserimento delle fonti e export per la pagina.

Chi cerca (anche un sotto-agente) propone solo schede senza classe di diritti: la classe e la
prova vengono dal registro degli host (`licenze_host.json`), che si compila a mano con `host`
dopo aver letto la pagina delle note legali dell'ente. Senza prova verificata nella pagina, una
fonte non è verde (docs/compliance/20 §23.10).
"""

from __future__ import annotations

import json
import os
import re
import urllib.parse
from datetime import date
from pathlib import Path
from typing import Any

from scripts.sources import licenses
from scripts.sources.fetcher import Blocked, CapReached, Fetcher
from scripts.sources.store import SourceError, Store, on_page, page_doc, slug

MINIMAL = (
    "id", "titolo", "url", "ente", "paese", "lingua", "livello", "scritto_per", "specie", "temi",
    "perche",
)  # fmt: skip
ATTRIBUTION = {
    "OGL v3.0": "Contains public sector information licensed under the Open Government Licence "
    "v3.0. Riassunto da Quokka.",
    "CC BY": "{ente}, CC BY (vedi la pagina delle note legali), modificato: riassunto da Quokka.",
    "VR": "Fonte: {ente}, opera del governo federale USA (dominio pubblico negli USA); nessuna "
    "approvazione dell'agenzia. Riassunto da Quokka.",
    "V": "Fonte: {ente} (testo non ufficiale e gratuito; fa fede la pubblicazione ufficiale). "
    "Riassunto da Quokka.",
}


class Registry:
    """Prove di licenza per host: una prova copre gli host elencati in `copre`."""

    def __init__(self, path: Path) -> None:
        self.path = path

    def load(self) -> dict[str, dict[str, Any]]:
        if not self.path.exists():
            return {}
        data: dict[str, dict[str, Any]] = json.loads(self.path.read_text("utf-8"))
        return data

    def save_entry(self, key: str, entry: dict[str, Any]) -> None:
        data = self.load()
        data[key] = entry
        tmp = self.path.with_suffix(f".{os.getpid()}.tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), "utf-8")
        tmp.replace(self.path)

    def find(self, host: str) -> dict[str, Any] | None:
        host = host.lower()
        for key, entry in self.load().items():
            if host == key or host in entry.get("copre", []):
                return entry
        return None


def register_host(
    fetcher: Fetcher,
    registry: Registry,
    terms_url: str,
    *,
    copre: list[str],
    frase: str = "",
    act: bool = False,
    federal: bool = False,
    pa_it: bool = False,
    regola: str = "",
    base_legale: str = "",
    attribuzione: str = "",
    terzi: str = "",
) -> dict[str, Any]:
    """Legge la pagina delle note legali e registra la prova (frase copiata e verificata)."""
    page = fetcher.get(terms_url)
    if page.status != 200:
        raise SourceError(f"pagina delle note legali: risposta {page.status}")
    primary = copre[0]
    text = page.full_text
    if frase:
        if not licenses.proof_in_page(frase, text):
            raise SourceError("la frase non compare nella pagina: copiala dalla pagina")
        classe = licenses.VR if federal else licenses.V if act else None
        if classe is None:
            verdict = licenses.classify_text(text, host=primary, italian_pa=pa_it)
            classe, licenza = verdict.classe, verdict.licenza
            regola = regola or verdict.motivo
        else:
            licenza = (
                "opera del governo federale USA (17 U.S.C. §105)" if federal else "atto ufficiale"
            )
            regola = regola or ("Tabella A: opere federali USA" if federal else "Tabella B")
    else:
        verdict = licenses.classify_text(text, host=primary, italian_pa=pa_it)
        classe, licenza, regola = verdict.classe, verdict.licenza, regola or verdict.motivo
        frase = verdict.frase
        if classe in licenses.USABLE and frase and not licenses.proof_in_page(frase, text):
            raise SourceError("la frase di prova non compare nella pagina")
    if classe in licenses.USABLE and not frase:
        raise SourceError("nessuna frase di prova: passa --frase copiandola dalla pagina")
    robots = fetcher.robots(primary)
    entry = {
        "classe": classe,
        "licenza": licenza,
        "copre": sorted({h.lower() for h in copre}),
        "prova": {
            "frase": frase,
            "url": page.url,
            "data": date.today().isoformat(),
            "regola": regola,
            "robots": f"{primary}: robots.txt "
            + ("assente" if not robots.present else "letto; nessun divieto per Quokka")
            + (f"; crawl-delay {robots.crawl_delay:g} s" if robots.crawl_delay else ""),
            "terzi": terzi or "da controllare nel testo; solo testo, niente immagini né loghi",
            "controllata_nella_pagina": True,
        },
        "base_legale": base_legale,
        "attribuzione": attribuzione,
    }
    registry.save_entry(primary, entry)
    return entry


def attribution_for(entry: dict[str, Any], ente: str, url: str = "", today: str = "") -> str:
    """La riga fonte (condizione della licenza): per ente, e per tipo di testo dove serve."""
    host = urllib.parse.urlsplit(url).netloc.lower()
    if host.endswith(
        "boe.es"
    ):  # consolidata: carattere informativo; testo della Gazzetta: ufficiale
        if "act.php" in url:
            return (
                "Fuente: BOE, texto consolidado, carácter informativo, sin valor jurídico "
                f"(actualizado a {today}); riassunto da Quokka."
            )
        return f"Fuente: BOE, texto oficial (consultado el {today}); riassunto da Quokka."
    if host.endswith("gesetze-im-internet.de"):
        return (
            "Quelle: gesetze-im-internet.de, Bundesministerium der Justiz (konsolidierte, nicht "
            f"amtliche Fassung, Stand: {today}); maßgeblich ist das Bundesgesetzblatt; "
            "riassunto da Quokka."
        )
    if entry.get("attribuzione"):
        text = str(entry["attribuzione"]).replace("{ente}", ente)
    else:
        key = entry["classe"] if entry["classe"] == "VR" else entry["licenza"]
        text = (ATTRIBUTION.get(key) or ATTRIBUTION["V"]).format(ente=ente)
    if host.endswith("legislation.gov.uk") and "/enacted" not in url and "/made" not in url:
        text += " Versione aggiornata (revised), non ufficiale."
    return text


def add_source(
    fetcher: Fetcher, store: Store, registry: Registry, scheda: dict[str, Any], data_dir: Path
) -> str:
    """Una fonte proposta: legge la pagina, applica la prova dell'host, aggiunge all'elenco."""
    missing = [k for k in MINIMAL if not scheda.get(k)]
    if missing:
        return f"RIFIUTATA {scheda.get('id')}: campi mancanti {', '.join(missing)}"
    scheda = dict(scheda)
    scheda["id"] = slug(scheda["id"], 100)
    url = scheda["url"]
    host = urllib.parse.urlsplit(url).netloc.lower()
    if scheda["id"] in store.load():  # nessuna richiesta per una fonte già in elenco
        return f"GIA_PRESENTE {scheda['id']}"
    entry = registry.find(host)
    today = date.today().isoformat()
    if entry is None:
        return f"DA_REGISTRARE {scheda['id']}: host {host} senza prova di licenza"
    if entry["classe"] not in licenses.USABLE:
        return f"NON_USABILE {scheda['id']}: host {host} è {entry['classe']} ({entry['licenza']})"
    try:
        page = fetcher.get(url)
    except Blocked as err:
        scheda.update(
            classe="N",
            stato="in_sospeso",
            notte=today,
            licenza=entry["licenza"],
            avvertenza=str(err),
        )
        _add(store, scheda)
        return f"BLOCCATA {scheda['id']}: {err}"
    except CapReached as err:
        return f"TETTO {scheda['id']}: {err}"
    if page.status != 200 or not page.text:
        return f"NON_LETTA {scheda['id']}: risposta {page.status}"
    body = page.text
    if re.search(
        r"all rights reserved|tutti i diritti riservati|todos los derechos reservados", body, re.I
    ):
        return f"RISERVA {scheda['id']}: «diritti riservati» nel testo: caso G, non aggiunta"
    scheda.update(
        classe=entry["classe"],
        stato="in_uso",
        notte=today,
        licenza=entry["licenza"],
        prova=entry["prova"],
        base_legale=entry.get("base_legale", ""),
        attribuzione=attribution_for(entry, scheda["ente"], url, today),
        impronta=page.fingerprint,
        scaricato_il=today,
        url=page.url if page.url.split("#")[0] != url.split("#")[0] else url,
    )
    result = _add(store, scheda)
    if result == "nuova":
        folder = data_dir / "pagine"
        folder.mkdir(exist_ok=True)
        (folder / f"{scheda['id']}.txt").write_text(body, "utf-8")
    return f"{result.upper()} {scheda['id']} [{entry['classe']}] {len(body)} caratteri"


def _add(store: Store, scheda: dict[str, Any]) -> str:
    try:
        return "nuova" if store.add(scheda) else "gia_presente"
    except SourceError as err:
        return f"rifiutata ({err})"


def export_for_page(store: Store, out_dir: Path, synced_path: Path) -> list[str]:
    """Scrive un file JSON per ogni fonte V, VR o N non ancora nella pagina."""
    synced = set(json.loads(synced_path.read_text("utf-8"))) if synced_path.exists() else set()
    out_dir.mkdir(exist_ok=True)
    ids = []
    for sid, src in sorted(store.load().items()):
        if sid in synced or not on_page(src):
            continue
        (out_dir / f"{sid}.json").write_text(json.dumps(page_doc(src), ensure_ascii=False), "utf-8")
        ids.append(sid)
    return ids


def check_log(
    log_path: Path, robots_path: Path, since: str = ""
) -> tuple[bool, list[str], dict[str, float]]:
    """Distanza minima tra richieste allo stesso host, dal registro (dal momento `since`).

    Conforme se ogni distanza è almeno di 10 s (o del Crawl-delay del robots.txt, se maggiore).
    Restituisce (conforme, righe di violazione, distanza minima per host).
    """
    from datetime import datetime

    rows = [json.loads(x) for x in log_path.read_text("utf-8").splitlines() if x.strip()]
    delays: dict[str, float] = {}
    if robots_path.exists():
        for host, entry in json.loads(robots_path.read_text("utf-8")).items():
            found = re.findall(r"(?im)^\s*crawl-delay:\s*(\d+(?:\.\d+)?)", entry.get("text", ""))
            if found:
                delays[host] = float(found[0])
    by_host: dict[str, list[datetime]] = {}
    for row in rows:
        when = datetime.fromisoformat(row["quando"])
        if since and when < datetime.fromisoformat(since).astimezone():
            continue
        host = urllib.parse.urlsplit(row["indirizzo"]).netloc.lower()
        by_host.setdefault(host, []).append(when)
    minimum: dict[str, float] = {}
    violations: list[str] = []
    for host, times in sorted(by_host.items()):
        times.sort()
        gaps = [(b - a).total_seconds() for a, b in zip(times, times[1:], strict=False)]
        if not gaps:
            continue
        minimum[host] = min(gaps)
        needed = max(10.0, delays.get(host, 0.0))
        low = [g for g in gaps if g < needed - 0.5]  # mezzo secondo di tolleranza sugli orologi
        if low:
            violations.append(
                f"{host}: {len(low)} richieste a meno di {needed:g} s (minimo {min(low):.1f} s)"
            )
    return not violations, violations, minimum
