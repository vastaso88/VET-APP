"""Turns the aesthetics testers' HTML drafts («dopo») into pictures the size of the «before»
ones (390x844), light and dark, so the page can show them side by side.

    python -m scripts.collaudo.bozza_png <bozza.html> [...]

A draft must use the app's own colours, fonts and spacing
(`apps/mobile_app/lib/design_system/tokens/`, `docs/design/PALETTE_60_30_10.md`). It may only
load local files: a draft that reaches the internet is refused, so nothing leaves the PC.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from scripts.collaudo.chrome import fotografa

_REMOTE = re.compile(r"""(?:src|href)\s*=\s*["']\s*(?:https?:)?//""", re.IGNORECASE)
_CSS_REMOTE = re.compile(r"""url\(\s*["']?\s*(?:https?:)?//|@import\s+["']?(?:https?:)?//""", re.I)


def remota(html: str) -> bool:
    """True when the draft would load something from the internet."""
    return bool(_REMOTE.search(html) or _CSS_REMOTE.search(html))


def converti(bozza: Path) -> list[Path]:
    html = bozza.read_text(encoding="utf-8")
    if remota(html):
        raise ValueError(f"{bozza.name} carica qualcosa da internet: solo file locali")
    out: list[Path] = []
    for dark in (False, True):
        target = bozza.with_name(f"{bozza.stem}_{'scuro' if dark else 'chiaro'}.png")
        out.append(fotografa(bozza.resolve().as_uri(), target, scuro=dark, attesa_ms=3000))
    return out


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for name in sys.argv[1:]:
        for picture in converti(Path(name)):
            print(picture)
