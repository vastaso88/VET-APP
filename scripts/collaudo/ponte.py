"""Forwarding to the twin's API with the Vercel bypass code, for the collaudo app builds.

The `collaudo` previews of vet-app are protected (Vercel Authentication): every request needs
the `x-vercel-protection-bypass` header. Scripts add it themselves; the app builds cannot, and
the code must never be compiled into a build. So `servi_web.py` serves the web build and
forwards `/api/*` here (same origin: the web app calls `http://localhost:8080/api`, the
emulator `http://10.0.2.2:8080/api`); this module adds the code (read from `.env`, never
printed) and sends the request on to COLLAUDO_API_URL. Supabase is reached directly by the
app: it does not go through Vercel.

The bridge adds a few milliseconds on this computer: timings measured through it say so. The
timekeeper also measures the server directly from the scripts, which send the header.
"""

from __future__ import annotations

import urllib.error
import urllib.request
from email.message import Message
from http.server import BaseHTTPRequestHandler

from scripts.collaudo.config import Gemello, GemelloNonSicuro
from scripts.collaudo.rete import BYPASS_HEADER, USER_AGENT

PREFISSO = "/api"
PORTA = 8080
INDIRIZZO_WEB = f"http://localhost:{PORTA}{PREFISSO}"
# The Android emulator reaches the computer's loopback at 10.0.2.2.
INDIRIZZO_EMULATORE = f"http://10.0.2.2:{PORTA}{PREFISSO}"
# Hop-by-hop headers and the ones the bridge sets itself are not copied.
_SKIP_REQUEST = {
    "host",
    "connection",
    "keep-alive",
    "proxy-connection",
    "transfer-encoding",
    "upgrade",
    "te",
    "trailer",
    BYPASS_HEADER,
    "content-length",
}
_SKIP_RESPONSE = {
    "connection",
    "keep-alive",
    "transfer-encoding",
    "upgrade",
    "te",
    "trailer",
    "content-length",
    "content-encoding",
}


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args: object, **kwargs: object) -> None:
        return None  # the app sees the redirect itself, as it would without the bridge


_OPENER = urllib.request.build_opener(_NoRedirect())


def percorso_api(path: str) -> str | None:
    """`/api/chat?x=1` -> `/chat?x=1`; None when the path is not an API one."""
    if path == PREFISSO or path.startswith(PREFISSO + "/") or path.startswith(PREFISSO + "?"):
        rest = path[len(PREFISSO) :]
        return rest if rest.startswith("/") else "/" + rest
    return None


def richiesta_inoltrata(
    gemello: Gemello, method: str, path: str, headers: dict[str, str], body: bytes | None
) -> urllib.request.Request:
    """The request to the twin: same method, path, headers and body, plus the bypass code."""
    if not path.startswith("/") or path.startswith("//"):
        raise GemelloNonSicuro("percorso non valido")
    request = urllib.request.Request(gemello.api_url + path, data=body, method=method)
    for name, value in headers.items():
        if name.lower() not in _SKIP_REQUEST:
            request.add_header(name, value)
    if not any(name.lower() == "user-agent" for name in headers):
        request.add_header("User-Agent", USER_AGENT)
    if gemello.bypass:
        request.add_header(BYPASS_HEADER, gemello.bypass)
    return request


def inoltra(handler: BaseHTTPRequestHandler, gemello: Gemello, path: str) -> None:
    """Answers [handler]'s request with the twin's answer to the same request."""
    length = int(handler.headers.get("Content-Length") or 0)
    body = handler.rfile.read(length) if length else None
    headers: Message | None
    try:
        request = richiesta_inoltrata(
            gemello, handler.command, path, dict(handler.headers.items()), body
        )
        with _OPENER.open(request, timeout=180) as response:
            status, headers, payload = response.status, response.headers, response.read()
    except urllib.error.HTTPError as error:
        status, headers, payload = error.code, error.headers, error.read()
    except (urllib.error.URLError, TimeoutError, GemelloNonSicuro):
        status, headers = 502, None
        payload = b'{"detail":"ponte: gemello non raggiungibile"}'
    handler.send_response(status)
    for name, value in headers.items() if headers is not None else []:
        if name.lower() not in _SKIP_RESPONSE:
            handler.send_header(name, value)
    if headers is None:
        handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    if handler.command != "HEAD":
        handler.wfile.write(payload)
