"""Comandi a mano del Cercafonti (stesse regole del giro notturno: tutto passa da `Fetcher`).

  python -m scripts.sources.cli probe [--save] [--atto] <url> ...  legge e riassume (--atto: legge)
  python -m scripts.sources.cli robots <host> [<host> ...] legge solo i robots.txt
  python -m scripts.sources.cli add <file.json>           aggiunge fonti (lista di schede)
  python -m scripts.sources.cli coverage                  fonti in uso per casella

I dati stanno in `.local/cercafonti/` (fuori dal repository). Le pagine lette si salvano in
`.local/cercafonti/pagine/` solo per le fonti verdi (testo) e solo se `--save` è indicato.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from scripts.sources import licenses
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
    elif cmd == "coverage":
        print(json.dumps(Store(DATA / "fonti.json").coverage(), indent=1, sort_keys=True))
    else:
        print(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    main(sys.argv)
