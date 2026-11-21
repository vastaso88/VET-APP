"""Comandi a mano del Cercafonti (stesse regole del giro notturno: tutto passa da `Fetcher`).

  python -m scripts.sources.cli probe [--save] [--atto] <url> ...  legge e riassume (--atto: legge)
  python -m scripts.sources.cli robots <host> [<host> ...] legge solo i robots.txt
  python -m scripts.sources.cli add <file.json>           aggiunge fonti (lista di schede)
  python -m scripts.sources.cli coverage                  fonti in uso per casella
  python -m scripts.sources.cli scarta <id> <motivo>      fonte letta e non adatta
  python -m scripts.sources.cli controlla [--da ISO]      distanza minima per host nel registro
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

from scripts.sources import licenses, pipeline
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
    elif cmd == "coverage":
        print(json.dumps(Store(DATA / "fonti.json").coverage(), indent=1, sort_keys=True))
    else:
        print(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    main(sys.argv)
