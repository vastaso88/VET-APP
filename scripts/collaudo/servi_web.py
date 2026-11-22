"""Serves the collaudo web build on this computer and bridges `/api/*` to the twin.

    python -m scripts.collaudo.servi_web <cartella build/web> [--porta 8080]

- `/api/...` goes to the twin's API with the Vercel bypass code added (`ponte.py`): same
  origin for the web app, so no CORS preflight; the code never enters a build.
- Any other path that is not a file gets `index.html` (the app uses path URLs such as
  `/home-shell`), as a hosting service would.

It listens on 127.0.0.1 only. The Android emulator reaches it at 10.0.2.2, which is the
computer's loopback: nothing on the network can.
"""

from __future__ import annotations

import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from scripts.collaudo.config import Gemello, GemelloNonSicuro, load_gemello
from scripts.collaudo.ponte import PORTA, inoltra, percorso_api


def _handler(gemello: Gemello | None) -> type[SimpleHTTPRequestHandler]:
    class AppHandler(SimpleHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def _maybe_api(self) -> bool:
            path = percorso_api(self.path)
            if path is None:
                return False
            if gemello is None:
                self.send_error(503, "gemello non configurato")
            else:
                inoltra(self, gemello, path)
            return True

        def do_GET(self) -> None:
            if not self._maybe_api():
                super().do_GET()

        def do_HEAD(self) -> None:
            if not self._maybe_api():
                super().do_HEAD()

        def do_POST(self) -> None:
            if not self._maybe_api():
                self.send_error(405)

        do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_POST

        def send_head(self):  # type: ignore[no-untyped-def]
            target = Path(self.translate_path(self.path))
            if not target.exists():
                self.path = "/index.html"
            return super().send_head()

        def log_message(self, format: str, *args: object) -> None:  # noqa: A002
            return  # quiet: no paths or tokens in a log

    return AppHandler


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="servi_web")
    parser.add_argument("cartella", type=Path)
    parser.add_argument("--porta", type=int, default=PORTA)
    args = parser.parse_args(argv)
    if not (args.cartella / "index.html").is_file():
        print(f"FERMO: {args.cartella} non è una build web (manca index.html)")
        return 2
    try:
        gemello: Gemello | None = load_gemello(need_api=True)
    except GemelloNonSicuro as error:
        print(f"Attenzione: /api non inoltrato ({error})")
        gemello = None
    if gemello is not None and not gemello.bypass:
        print("Attenzione: VERCEL_BYPASS_COLLAUDO vuoto, le anteprime protette risponderanno 401")
    handler = functools.partial(_handler(gemello), directory=str(args.cartella))
    server = ThreadingHTTPServer(("127.0.0.1", args.porta), handler)
    print(f"build di collaudo su http://localhost:{args.porta} (API su /api)")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
