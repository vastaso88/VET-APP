"""Phone-sized pictures with the Chrome already installed on this computer (headless), so the
collaudo needs no new library. Only local addresses and local files are opened.

Phone size: 390x844 CSS pixels (a common modern phone). Light and dark: Chrome's own switches
for `prefers-color-scheme`, which Flutter web reads as the platform brightness.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

LARGHEZZA, ALTEZZA = 390, 844
_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "/usr/bin/google-chrome",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
)
_LOCAL = {"127.0.0.1", "localhost", "[::1]", "::1"}


class IndirizzoNonLocale(ValueError):
    pass


def trova_chrome() -> str:
    for candidate in (os.environ.get("COLLAUDO_CHROME", ""), *_CANDIDATES):
        if candidate and Path(candidate).is_file():
            return candidate
    found = shutil.which("chrome") or shutil.which("google-chrome")
    if not found:
        raise FileNotFoundError("Chrome non trovato: imposta COLLAUDO_CHROME")
    return found


def controlla_locale(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme == "file" or (
        parsed.scheme in ("http", "https") and parsed.hostname in _LOCAL
    ):
        return url
    raise IndirizzoNonLocale(f"solo indirizzi locali o file: {url}")


def argomenti(url: str, out: Path, *, scuro: bool, profilo: Path, attesa_ms: int) -> list[str]:
    return [
        "--headless=new",
        "--hide-scrollbars",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        f"--user-data-dir={profilo}",
        f"--window-size={LARGHEZZA},{ALTEZZA}",
        f"--blink-settings=preferredColorScheme={0 if scuro else 1}",
        *(["--force-dark-mode"] if scuro else []),
        "--enable-unsafe-swiftshader",
        f"--virtual-time-budget={attesa_ms}",
        f"--screenshot={out}",
        controlla_locale(url),
    ]


def fotografa(
    url: str, out: Path, *, scuro: bool = False, profilo: Path | None = None, attesa_ms: int = 15000
) -> Path:
    """One picture of [url] into [out]. The profile keeps the collaudo build's session
    between pictures (sign in once)."""
    out.parent.mkdir(parents=True, exist_ok=True)
    folder = profilo or Path(tempfile.mkdtemp(prefix="collaudo-chrome-"))
    command = [
        trova_chrome(),
        *argomenti(url, out.resolve(), scuro=scuro, profilo=folder, attesa_ms=attesa_ms),
    ]
    try:
        subprocess.run(command, check=False, capture_output=True, timeout=attesa_ms / 1000 + 60)
    finally:
        if profilo is None:
            # a throwaway profile is tens of MB: never leave it in the temp folder
            shutil.rmtree(folder, ignore_errors=True)
    if not out.is_file():
        raise RuntimeError(f"fotografia non riuscita: {url}")
    return out
