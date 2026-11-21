"""Unico punto da cui il Cercafonti contatta siti esterni (CLAUDE.md, «Richieste a siti esterni»).

Regole incorporate, così sono il comportamento predefinito e non una disciplina da ricordare:
- nome proprio che inizia con «Quokka» (mai un nome di browser o di un'altra azienda);
- prima `robots.txt` (per nome e per `*`; contano `Content-Signal` e `ai-train`), poi la pagina;
- 10 secondi (o il `Crawl-delay`, se più alto) tra due richieste allo stesso host;
- stop a sfida, CAPTCHA, 403, 429, 5xx con pagina di verifica: l'host resta fuori, nessuna riprova;
- tetto di richieste per giro;
- ogni richiesta registrata (data, nome, indirizzo, esito) in un file che non si cancella.
I reindirizzamenti si seguono a mano (al massimo 3) e ogni nuovo host passa dal suo `robots.txt`.
"""

from __future__ import annotations

import hashlib
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from urllib.robotparser import RobotFileParser

USER_AGENT = (
    "QuokkaCercafonti/0.1 (lettura rispettosa di fonti pubbliche; una richiesta alla volta)"
)
ROBOT_NAME = "QuokkaCercafonti"
MIN_PAUSE_SECONDS = 10.0
MAX_BYTES = 6_000_000
MAX_REDIRECTS = 3
ROBOTS_CACHE_SECONDS = 24 * 3600
DEFAULT_MAX_REQUESTS = 150

CHALLENGE = re.compile(
    r"just a moment|captcha|are you human|verify you are|access denied|request unsuccessful"
    r"|enable javascript and cookies|incapsula|attention required|cf-chl|checking your browser"
    r"|pardon our interruption|bot detection",
    re.IGNORECASE,
)


class Blocked(Exception):
    """Il sito ha detto no (robots, sfida, 403/429): nessuna riprova, nessun altro strumento."""

    def __init__(self, host: str, reason: str) -> None:
        super().__init__(f"{host}: {reason}")
        self.host = host
        self.reason = reason


class CapReached(Exception):
    """Tetto di richieste del giro raggiunto."""


@dataclass
class Page:
    url: str
    status: int
    content_type: str
    body: bytes
    text: str = ""
    title: str = ""
    fingerprint: str = ""
    full_text: str = ""  # anche menu e piè di pagina: serve a leggere la riga di licenza


@dataclass
class RobotsInfo:
    allowed_parser: RobotFileParser
    crawl_delay: float = 0.0
    ai_train_no: bool = False
    ai_input_no: bool = False
    signal_line: str = ""
    present: bool = True


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args: object, **kwargs: object) -> None:  # type: ignore[override]
        return None


class _Text(HTMLParser):
    CHROME = {"nav", "footer", "header", "form", "aside"}

    def __init__(self, keep_chrome: bool = False) -> None:
        super().__init__()
        self.SKIP = {"script", "style", "noscript", "svg"} | (set() if keep_chrome else self.CHROME)
        self.parts: list[str] = []
        self.title = ""
        self._skip = 0
        self._in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in self.SKIP:
            self._skip += 1
        elif tag == "title":
            self._in_title = True
        elif tag in {"p", "li", "br", "h1", "h2", "h3", "h4", "tr", "div"}:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in self.SKIP and self._skip:
            self._skip -= 1
        elif tag == "title":
            self._in_title = False

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data
        elif not self._skip:
            self.parts.append(data)


def html_to_text(raw: str, keep_chrome: bool = False) -> tuple[str, str]:
    """(titolo, testo) di una pagina HTML; scarta script e, di norma, menu e piè di pagina."""
    parser = _Text(keep_chrome)
    parser.feed(raw)
    text = re.sub(r"[ \t ]+", " ", "".join(parser.parts))
    text = re.sub(r"\n\s*\n+", "\n", text).strip()
    return re.sub(r"\s+", " ", parser.title).strip(), text


def main_text(host: str, raw: str) -> str | None:
    """Solo il corpo dell'atto per i portali di leggi (niente data di vigenza né menu): così
    l'impronta cambia solo se cambia il testo."""
    if host.endswith("normattiva.it") and "bodyTesto" in raw:
        segment = raw[raw.index("bodyTesto") :]
        text = html_to_text("<div>" + segment, keep_chrome=True)[1]
        cut = re.search(r"articolo successivo|Approfondimenti|nascondi", text)
        return (text[: cut.start()] if cut else text).split(">", 1)[-1].strip()
    return None


def fingerprint_of(text: str) -> str:
    """Impronta del testo normalizzato (maiuscole, spazi e punteggiatura non contano)."""
    norm = re.sub(r"\W+", " ", text.lower()).strip()
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()[:24]


@dataclass
class Fetcher:
    data_dir: Path
    max_requests: int = DEFAULT_MAX_REQUESTS
    clock: Callable[[], float] = time.time
    sleep: Callable[[float], None] = time.sleep
    opener: urllib.request.OpenerDirector | None = None
    requests_made: int = 0
    _last: dict[str, float] = field(default_factory=dict)
    _robots: dict[str, RobotsInfo] = field(default_factory=dict)
    _stopped: dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        if self.opener is None:
            self.opener = urllib.request.build_opener(_NoRedirect)
        self.log_path = self.data_dir / "registro_richieste.jsonl"
        self.stop_path = self.data_dir / "host_fermati.json"
        self.last_path = self.data_dir / "ultima_richiesta.json"
        if self.last_path.exists():  # la pausa vale anche tra un comando e il successivo
            self._last = {
                k: float(v) for k, v in json.loads(self.last_path.read_text("utf-8")).items()
            }
        self.robots_path = self.data_dir / "robots_cache.json"
        if self.stop_path.exists():
            self._stopped = json.loads(self.stop_path.read_text("utf-8"))

    # -- registro -------------------------------------------------------------------------
    def _log(self, url: str, esito: object, nota: str = "") -> None:
        row = {"quando": now_iso(), "nome": USER_AGENT, "indirizzo": url, "esito": esito}
        if nota:
            row["nota"] = nota
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")

    def _save_last(self) -> None:
        self.last_path.write_text(json.dumps(self._last), "utf-8")

    def _stop_host(self, host: str, reason: str) -> None:
        self._stopped[host] = f"{now_iso()} {reason}"
        self.stop_path.write_text(json.dumps(self._stopped, ensure_ascii=False, indent=1), "utf-8")

    def is_stopped(self, host: str) -> str | None:
        return self._stopped.get(host)

    # -- una richiesta ---------------------------------------------------------------------
    def _pause(self, host: str, delay: float) -> None:
        wait = self._last.get(host, -1e9) + max(MIN_PAUSE_SECONDS, delay) - self.clock()
        if wait > 0:
            self.sleep(wait)

    def _raw_get(
        self, url: str, host: str, delay: float, accept: str
    ) -> tuple[int, str, bytes, str]:
        if self.requests_made >= self.max_requests:
            raise CapReached(f"tetto di {self.max_requests} richieste raggiunto")
        self._pause(host, delay)
        assert self.opener is not None
        req = urllib.request.Request(
            url, headers={"User-Agent": USER_AGENT, "Accept": accept, "Accept-Language": "*"}
        )
        self.requests_made += 1
        location = ""
        try:
            with self.opener.open(req, timeout=45) as resp:
                status = resp.status
                ctype = resp.headers.get("Content-Type", "")
                body = resp.read(MAX_BYTES)
        except urllib.error.HTTPError as err:
            status = err.code
            ctype = err.headers.get("Content-Type", "") if err.headers else ""
            location = err.headers.get("Location", "") if err.headers else ""
            body = err.read(20_000) if err.fp else b""
        except Exception as err:  # rete, timeout: una sola prova, nessuna riprova
            self._last[host] = self.clock()
            self._save_last()
            self._log(url, f"errore {type(err).__name__}")
            raise Blocked(host, f"errore di rete {type(err).__name__}") from err
        self._last[host] = self.clock()
        self._save_last()
        self._log(url, status)
        return status, ctype, body, location

    def _robots_cached(self, host: str) -> tuple[int, str] | None:
        """robots.txt già letto nelle ultime 24 ore (si ricontrolla ogni giorno)."""
        if not self.robots_path.exists():
            return None
        entry = json.loads(self.robots_path.read_text("utf-8")).get(host)
        if entry and time.time() - entry["quando"] < ROBOTS_CACHE_SECONDS:
            return int(entry["status"]), str(entry["text"])
        return None

    def _robots_store(self, host: str, status: int, text: str) -> None:
        cache = json.loads(self.robots_path.read_text("utf-8")) if self.robots_path.exists() else {}
        cache[host] = {"quando": time.time(), "status": status, "text": text[:60_000]}
        self.robots_path.write_text(json.dumps(cache, ensure_ascii=False), "utf-8")

    def robots(self, host: str, scheme: str = "https") -> RobotsInfo:
        if host in self._robots:
            return self._robots[host]
        cached = self._robots_cached(host)
        if cached:
            status, text = cached
        else:
            url = f"{scheme}://{host}/robots.txt"
            status, _, body, _ = self._raw_get(url, host, 0.0, "text/plain")
            text = body.decode("utf-8", "replace")
            if status in (401, 403) or status == 429 or status >= 500:
                self._stop_host(host, f"robots.txt {status}")
                raise Blocked(host, f"robots.txt risponde {status}")
            self._robots_store(host, status, text)
        parser = RobotFileParser()
        info = RobotsInfo(parser)
        if status == 200 and not re.search(r"<html|<!doctype", text[:300], re.IGNORECASE):
            parser.parse(text.splitlines())
            delays = re.findall(r"(?im)^\s*crawl-delay:\s*(\d+(?:\.\d+)?)", text)
            info.crawl_delay = float(delays[0]) if delays else 0.0
            signals = re.findall(r"(?im)^\s*content-signal:\s*(.+)$", text)
            info.signal_line = signals[0].strip() if signals else ""
            info.ai_train_no = bool(re.search(r"ai-train\s*=\s*no", " ".join(signals), re.I))
            info.ai_input_no = bool(re.search(r"ai-input\s*=\s*no", " ".join(signals), re.I))
        else:  # nessun robots.txt (404 e simili): nessun divieto dichiarato
            parser.parse([])
            info.present = False
        self._robots[host] = info
        return info

    def get(self, url: str, accept: str = "text/html,application/pdf;q=0.9,*/*;q=0.5") -> Page:
        """Una pagina, nel rispetto di tutte le regole. Solleva Blocked o CapReached."""
        current = url
        for _ in range(MAX_REDIRECTS + 1):
            parts = urllib.parse.urlsplit(current)
            host = parts.netloc.lower()
            if parts.scheme not in ("http", "https") or not host:
                raise Blocked(host or current, "indirizzo non valido")
            if reason := self.is_stopped(host):
                raise Blocked(host, f"host fermato: {reason}")
            info = self.robots(host, parts.scheme)
            if not info.allowed_parser.can_fetch(ROBOT_NAME, current):
                raise Blocked(host, "robots.txt non permette questa pagina ai programmi")
            if info.ai_input_no:
                raise Blocked(host, f"Content-Signal ai-input=no ({info.signal_line})")
            status, ctype, body, location = self._raw_get(current, host, info.crawl_delay, accept)
            head = body[:6000].decode("utf-8", "ignore")
            if status in (301, 302, 303, 307, 308) and location:
                current = urllib.parse.urljoin(current, location)
                continue
            if status in (401, 403, 429) or (status >= 500 and CHALLENGE.search(head)):
                self._stop_host(host, f"risposta {status}")
                raise Blocked(host, f"risposta {status}: l'host resta fuori")
            if status == 200 and "html" in ctype.lower() and CHALLENGE.search(head[:3000]):
                self._stop_host(host, "pagina di verifica")
                raise Blocked(host, "pagina di verifica o sfida: l'host resta fuori")
            page = Page(current, status, ctype, body)
            if status == 200:
                if "html" in ctype.lower() or "xml" in ctype.lower():
                    raw = body.decode("utf-8", "replace")
                    page.title, page.text = html_to_text(raw)
                    page.full_text = html_to_text(raw, keep_chrome=True)[1]
                    if law_text := main_text(urllib.parse.urlsplit(current).netloc.lower(), raw):
                        page.text = law_text
                    page.fingerprint = fingerprint_of(page.text)
                else:
                    page.fingerprint = hashlib.sha256(body).hexdigest()[:24]
            return page
        raise Blocked(urllib.parse.urlsplit(url).netloc, "troppi reindirizzamenti")
