"""Pictures of the collaudo web build, phone size, light and dark.

    python -m scripts.collaudo.schermate http://localhost:8080 [--pagine pagine.json]

The app moves between most pages with taps, not addresses: this tool photographs the pages
that have an address (default list below, or a JSON list of paths). The «before» pictures of
every page are taken on the Android emulator (plan of 22/11); this tool serves the quick
checks of the web build. Output: `.local/collaudo/giro-<COLLAUDO_GIRO>/foto/`.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import tempfile
from pathlib import Path

from scripts.collaudo.chrome import controlla_locale, fotografa
from scripts.collaudo.config import output_root

PAGINE_PREDEFINITE = ("/home-shell", "/home", "/paywall")


def nome_file(path: str, scuro: bool) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", path.lower()).strip("_") or "avvio"
    return f"{slug}_{'scuro' if scuro else 'chiaro'}.png"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="schermate")
    parser.add_argument("indirizzo")
    parser.add_argument("--pagine", type=Path, default=None)
    args = parser.parse_args(argv)
    base = controlla_locale(args.indirizzo.rstrip("/"))
    pages = list(PAGINE_PREDEFINITE)
    if args.pagine:
        pages = [str(p) for p in json.loads(args.pagine.read_text(encoding="utf-8"))]
    folder = output_root() / f"giro-{os.environ.get('COLLAUDO_GIRO') or 'prova'}" / "foto"
    profile = Path(tempfile.mkdtemp(prefix="collaudo-chrome-"))
    try:
        for page in pages:
            for dark in (False, True):
                out = fotografa(
                    base + page, folder / nome_file(page, dark), scuro=dark, profilo=profile
                )
                print(out)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
