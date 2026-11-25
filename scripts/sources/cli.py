"""Comandi a mano del Cercafonti (stesse regole del giro notturno: tutto passa da `Fetcher`).

  python -m scripts.sources.cli probe [--save] [--atto] <url> ...  legge e riassume (--atto: legge)
  python -m scripts.sources.cli robots <host> [<host> ...] legge solo i robots.txt
  python -m scripts.sources.cli add <file.json>           aggiunge fonti (lista di schede)
  python -m scripts.sources.cli coverage                  fonti in uso per casella
  python -m scripts.sources.cli scarta <id> <motivo>      fonte letta e non adatta
  python -m scripts.sources.cli controlla [--da ISO]      distanza minima per host nel registro
  python -m scripts.sources.cli coverage-argomenti [--elenco f.json]  fonti per argomento
  python -m scripts.sources.cli seconda-lettura prepara | confronta <lotto> <risposte.json>
  python -m scripts.sources.cli lista [--casella S-T] [--specie S]   fonti in uso
  python -m scripts.sources.cli argomenti <id> <ARG-...>  collega una fonte agli argomenti
  python -m scripts.sources.cli scollega <id> <ARG-...>   toglie un collegamento debole
  python -m scripts.sources.cli indipendenti [--elenco f.json] [--csv f.csv]  fonti indipendenti
  python -m scripts.sources.cli nota-prodotto <schede.json>  note prodotto (non farmaci)
  python -m scripts.sources.cli hosts                     enti con licenza e host fermati
  python -m scripts.sources.cli source <file.json>        propone fonti (prova dal registro)

I dati stanno in `.local/cercafonti/` (fuori dal repository). Le pagine lette si salvano in
`.local/cercafonti/pagine/` solo per le fonti verdi (testo) e solo se `--save` è indicato.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from scripts.sources import independence, licenses, pipeline, product_notes, second_read
from scripts.sources.fetcher import Blocked, CapReached, Fetcher
from scripts.sources.store import SourceError, Store, slug

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / ".local" / "cercafonti"


def probe(urls: list[str], save: bool, act: bool = False) -> None:
    fetcher = Fetcher(DATA)
    for url in urls:
        try:
            page = fetcher.get(url)
        except (Blocked, CapReached) as err:
            print(
                json.dumps({"url": url, "esito": "fermato", "motivo": str(err)}, ensure_ascii=False)
            )
            continue
        host = url.split("/")[2]
        verdict = licenses.classify_text(page.full_text, host=host, official_act=act)
        out = {
            "url": page.url,
            "status": page.status,
            "tipo": page.content_type.split(";")[0],
            "titolo": page.title,
            "caratteri": len(page.text),
            "impronta": page.fingerprint,
            "licenza": verdict.licenza,
            "classe": verdict.classe,
            "frase": verdict.frase,
            "regola": verdict.motivo,
            "anteprima": page.text[:240].replace("\n", " "),
        }
        print(json.dumps(out, ensure_ascii=False))
        if save and page.status == 200 and verdict.classe in licenses.USABLE and page.text:
            folder = DATA / "pagine"
            folder.mkdir(exist_ok=True)
            (folder / f"{slug(page.url[8:], 120)}.txt").write_text(page.text, "utf-8")


def robots(hosts: list[str]) -> None:
    fetcher = Fetcher(DATA)
    for host in hosts:
        try:
            info = fetcher.robots(host)
        except (Blocked, CapReached) as err:
            print(
                json.dumps(
                    {"host": host, "esito": "fermato", "motivo": str(err)}, ensure_ascii=False
                )
            )
            continue
        print(
            json.dumps(
                {
                    "host": host,
                    "presente": info.present,
                    "crawl_delay": info.crawl_delay,
                    "ai_train_no": info.ai_train_no,
                    "ai_input_no": info.ai_input_no,
                    "content_signal": info.signal_line,
                },
                ensure_ascii=False,
            )
        )


def add(path: str) -> None:
    store = Store(DATA / "fonti.json")
    for src in json.loads(Path(path).read_text("utf-8")):
        try:
            print(src["id"], "nuova" if store.add(src) else "già presente")
        except SourceError as err:
            print(src.get("id"), "RIFIUTATA:", err)


def _opt(rest: list[str], name: str, default: str = "") -> str:
    return rest[rest.index(name) + 1] if name in rest else default


def host_cmd(rest: list[str]) -> None:
    """host <url delle note legali> --copre h1,h2 [--frase "..."] [--act|--federal|--pa-it] ..."""
    fetcher = Fetcher(DATA, max_requests=_max_requests())
    registry = pipeline.Registry(DATA / "licenze_host.json")
    try:
        entry = _register(fetcher, registry, rest)
    except (Blocked, CapReached, SourceError) as err:
        print(f"HOST NON REGISTRATO: {err}")
        return
    summary = {
        "host": entry["copre"],
        "classe": entry["classe"],
        "licenza": entry["licenza"],
        "frase": entry["prova"]["frase"],
    }
    print(json.dumps(summary, ensure_ascii=False))


def _register(fetcher: Fetcher, registry: pipeline.Registry, rest: list[str]) -> dict[str, Any]:
    return pipeline.register_host(
        fetcher,
        registry,
        rest[0],
        copre=_opt(rest, "--copre").split(","),
        frase=_opt(rest, "--frase"),
        act="--act" in rest,
        federal="--federal" in rest,
        pa_it="--pa-it" in rest,
        regola=_opt(rest, "--regola"),
        base_legale=_opt(rest, "--base-legale"),
        attribuzione=_opt(rest, "--attribuzione"),
        terzi=_opt(rest, "--terzi"),
    )


def source_cmd(path: str) -> None:
    fetcher = Fetcher(DATA, max_requests=_max_requests())
    store = Store(DATA / "fonti.json")
    registry = pipeline.Registry(DATA / "licenze_host.json")
    for scheda in json.loads(Path(path).read_text("utf-8")):
        print(pipeline.add_source(fetcher, store, registry, scheda, DATA), flush=True)


def _max_requests() -> int:
    return int(os.environ.get("CERCAFONTI_MAX_RICHIESTE", "150"))


def main(argv: list[str]) -> None:
    if len(argv) < 2:
        print(__doc__)
        return
    cmd, rest = argv[1], argv[2:]
    if cmd == "probe":
        save = "--save" in rest
        probe([r for r in rest if not r.startswith("--")], save, act="--atto" in rest)
    elif cmd == "robots":
        robots(rest)
    elif cmd == "add":
        add(rest[0])
    elif cmd == "host":
        host_cmd(rest)
    elif cmd == "source":
        source_cmd(rest[0])
    elif cmd == "export":
        ids = pipeline.export_for_page(
            Store(DATA / "fonti.json"), DATA / "export", DATA / "pagina_sync.json"
        )
        print(json.dumps(ids))
    elif cmd == "synced":
        path = DATA / "pagina_sync.json"
        done = set(json.loads(path.read_text("utf-8"))) if path.exists() else set()
        path.write_text(json.dumps(sorted(done | set(rest))), "utf-8")
    elif (
        cmd == "nota-prodotto"
    ):  # nota-prodotto <schede.json>: note per la chat, prodotti non farmaci
        fetcher = Fetcher(DATA, max_requests=_max_requests())
        hosts = product_notes.load_hosts(DATA / "host_prodotti.json")
        out_dir = ROOT / ".local" / "consegne" / "note_prodotti"
        for spec in json.loads(Path(rest[0]).read_text("utf-8")):
            try:
                outcome, _ = product_notes.make_note(fetcher, spec, hosts, out_dir)
            except (Blocked, CapReached) as err:
                outcome = f"FERMATO: {err}"
            if outcome.startswith("STOP_RISERVA"):  # riserva TDM: l'ente torna R
                bare = (urlparse(spec["source_url"]).hostname or "").removeprefix("www.")
                for key in hosts:
                    if key.removeprefix("www.") == bare:
                        hosts[key]["uso"] = "no"
                        hosts[key]["nota"] = "Riserva TDM trovata alla prima pagina: " + outcome
                (DATA / "host_prodotti.json").write_text(
                    json.dumps(hosts, ensure_ascii=False, indent=2) + "\n", "utf-8"
                )
            print(spec.get("id", "?"), outcome, flush=True)
    elif cmd == "scarta":
        Store(DATA / "fonti.json").discard(rest[0], " ".join(rest[1:]) or "non pertinente")
        print("scartata", rest[0])
    elif cmd == "controlla":
        ok, violations, minimum = pipeline.check_log(
            DATA / "registro_richieste.jsonl",
            DATA / "robots_cache.json",
            _opt(rest, "--da"),
        )
        for line in violations:
            print("NON CONFORME:", line)
        shortest = min(minimum.values()) if minimum else None
        print("GIRO CONFORME" if ok else "GIRO NON CONFORME", f"(distanza minima {shortest})")
    elif cmd == "hosts":
        reg = pipeline.Registry(DATA / "licenze_host.json").load()
        for e in sorted(reg.values(), key=lambda x: x["copre"][0]):
            print(f"{e['classe']:2} {', '.join(e['copre'])}  [{e['licenza']}]")
        stop = DATA / "host_fermati.json"
        if stop.exists():
            print(
                "FERMATI (nessuna richiesta):",
                ", ".join(sorted(json.loads(stop.read_text("utf-8")))),
            )
    elif cmd == "seconda-lettura":
        sub, extra = rest[0], rest[1:]
        folder = DATA / "seconda_lettura"
        reviewed = DATA / "seconda_lettura.json"
        store = Store(DATA / "fonti.json")
        if sub == "prepara":
            made = second_read.prepare_batches(store, DATA / "pagine", folder, reviewed)
            print(json.dumps(made))
        elif sub == "confronta":  # confronta <lotto_NN> <risposte.json>
            mapping = json.loads((folder / f"{extra[0]}.json").read_text("utf-8"))
            answers = json.loads(Path(extra[1]).read_text("utf-8"))
            flagged = second_read.compare(store, mapping, answers)
            second_read.mark_reviewed(reviewed, mapping, flagged)
            print(json.dumps(flagged, ensure_ascii=False, indent=1))
    elif cmd == "lista":  # lista [--casella S11-T02] [--specie S11]
        store = Store(DATA / "fonti.json")
        cell, specie = _opt(rest, "--casella"), _opt(rest, "--specie")
        for sid, src in sorted(store.load().items()):
            if src["stato"] != "in_uso" or src["classe"] not in ("V", "VR"):
                continue
            cells = {f"{s}-{t}" for s in src["specie"] for t in src["temi"]}
            if (cell and cell not in cells) or (specie and specie not in src["specie"]):
                continue
            topics = ",".join(src.get("argomenti", []))
            print(f"{sid} | {src['titolo'][:70]} | {src['paese']} | {topics}")
    elif cmd == "argomenti":  # argomenti <id fonte> <ARG-...> [<ARG-...> ...]
        store = Store(DATA / "fonti.json")
        print(store.add_topics(rest[0], rest[1:]))
    elif cmd == "scollega":  # scollega <id fonte> <ARG-...> [<ARG-...> ...]
        print(Store(DATA / "fonti.json").remove_topics(rest[0], rest[1:]))
    elif cmd == "indipendenti":  # indipendenti [--elenco f.json] [--csv uscita.csv]
        store = Store(DATA / "fonti.json")
        manual = independence.load_manual(DATA / "famiglie_manuali.json")
        fam = independence.families(store, DATA / "pagine", manual)
        per_topic = independence.topic_independence(store, fam)
        wanted = _opt(rest, "--elenco")
        topics = json.loads(Path(wanted).read_text("utf-8")) if wanted else []
        ids = [x["id"] if isinstance(x, dict) else x for x in topics] or sorted(per_topic)
        rows = [
            (i, per_topic.get(i, {}).get("fonti", 0), per_topic.get(i, {}).get("indipendenti", 0))
            for i in ids
        ]
        summary = {
            "argomenti": len(rows),
            "con_3_fonti": sum(1 for r in rows if r[1] >= 3),
            "con_3_indipendenti": sum(1 for r in rows if r[2] >= 3),
            "con_2_indipendenti": sum(1 for r in rows if r[2] == 2),
            "con_1_indipendente": sum(1 for r in rows if r[2] == 1),
            "senza_fonti": sum(1 for r in rows if r[1] == 0),
            "famiglie": len(set(fam.values())),
            "fonti_in_uso": len(fam),
        }
        csv_path = _opt(rest, "--csv")
        if csv_path:
            meta = {x["id"]: x for x in topics if isinstance(x, dict)}
            lines = ["id,casella,argomento,domande,fonti,indipendenti"]
            for i, n, k in rows:
                m = meta.get(i, {})
                title = str(m.get("argomento", "")).replace('"', "'")
                lines.append(f'{i},{m.get("casella", "")},"{title}",{m.get("domande", "")},{n},{k}')
            Path(csv_path).write_text("\n".join(lines) + "\n", "utf-8")
        print(json.dumps(summary, ensure_ascii=False, indent=1))
    elif cmd == "coverage-argomenti":
        counts = Store(DATA / "fonti.json").topic_coverage()
        wanted = _opt(rest, "--elenco")
        if wanted:  # un file con una lista di identificativi di argomenti
            ids = json.loads(Path(wanted).read_text("utf-8"))
            ids = [x["id"] if isinstance(x, dict) else x for x in ids]
            poor = [i for i in ids if counts.get(i, 0) < 3]
            print(
                json.dumps(
                    {
                        "argomenti": len(ids),
                        "con_3_o_piu": len(ids) - len(poor),
                        "da_riempire": poor,
                    },
                    ensure_ascii=False,
                    indent=1,
                )
            )
        else:
            print(json.dumps(counts, ensure_ascii=False, indent=1, sort_keys=True))
    elif cmd == "coverage":
        print(json.dumps(Store(DATA / "fonti.json").coverage(), indent=1, sort_keys=True))
    else:
        print(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    main(sys.argv)
