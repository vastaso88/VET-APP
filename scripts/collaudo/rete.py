"""One HTTP call to the twin, timed, with an honest name.

`headers_ms` is the time until the response headers arrived (the server finished its work:
the API does not stream, `/chat` included), `total_ms` until the body was read. Every call
is appended to `tempi.jsonl` by the caller, so a round can be compared with the next one.

The Vercel preview bypass header is `x-vercel-protection-bypass` (Vercel docs, «Protection
Bypass for Automation»); it is only sent when VERCEL_BYPASS_COLLAUDO is set.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from typing import Any

USER_AGENT = "QuokkaCollaudo/0.1"
BYPASS_HEADER = "x-vercel-protection-bypass"


@dataclass(frozen=True)
class Risposta:
    status: int
    body: Any
    headers_ms: int
    total_ms: int

    @property
    def ok(self) -> bool:
        return 200 <= self.status < 300


def multipart(
    fields: dict[str, str], file_field: str, filename: str, content: bytes, content_type: str
) -> tuple[bytes, str]:
    """A multipart/form-data body (form fields + one file), as the app's uploads send."""
    boundary = "QuokkaCollaudo" + uuid.uuid4().hex
    parts: list[bytes] = []
    for name, value in fields.items():
        header = f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n'
        parts.append(header.encode() + value.encode() + b"\r\n")
    safe_name = filename.replace('"', "").replace("\r", "").replace("\n", "")
    parts.append(
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; '
            f'filename="{safe_name}"\r\nContent-Type: {content_type}\r\n\r\n'
        ).encode()
        + content
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def _decode(raw: bytes) -> Any:
    text = raw.decode("utf-8", "replace")
    if not text:
        return {}
    try:
        return json.loads(text)
    except ValueError:
        return text[:2000]


def chiama(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    body: Any = None,
    raw: tuple[bytes, str] | None = None,
    bypass: str = "",
    timeout: float = 120.0,
) -> Risposta:
    """`body` is sent as JSON; `raw` = (bytes, content type) for files and forms."""
    data = None
    request = urllib.request.Request(url, method=method.upper())
    request.add_header("User-Agent", USER_AGENT)
    for name, value in (headers or {}).items():
        request.add_header(name, value)
    if bypass:
        request.add_header(BYPASS_HEADER, bypass)
    if raw is not None:
        data, content_type = raw
        request.add_header("Content-Type", content_type)
    elif body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        request.add_header("Content-Type", "application/json")
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, data, timeout=timeout) as response:
            headers_at = time.perf_counter()
            payload = response.read()
            status = response.status
    except urllib.error.HTTPError as error:
        headers_at = time.perf_counter()
        payload = error.read()
        status = error.code
    except (urllib.error.URLError, TimeoutError) as error:
        now = time.perf_counter()
        elapsed = int((now - started) * 1000)
        return Risposta(0, {"errore_rete": type(error).__name__}, elapsed, elapsed)
    finished = time.perf_counter()
    return Risposta(
        status=status,
        body=_decode(payload),
        headers_ms=int((headers_at - started) * 1000),
        total_ms=int((finished - started) * 1000),
    )
