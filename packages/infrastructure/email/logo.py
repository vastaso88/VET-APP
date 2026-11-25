"""The quokka of the e-mails: the head in paper colour (176 px wide, 2x of the 88 px it is shown
at), transparent, for the petrol band. It travels inside the message (never fetched from a
site) and is never recoloured, also in dark mode."""

from __future__ import annotations

from functools import cache
from pathlib import Path

_FILE = Path(__file__).parent / "assets" / "quokka_head_paper.png"


@cache
def quokka_head_png() -> bytes:
    """The PNG bytes, or empty bytes if the file is missing (the message then has no image)."""
    try:
        return _FILE.read_bytes()
    except OSError:
        return b""
