"""What the radar importers send to other hosts, and how politely.

Project rule (CLAUDE.md, "Richieste a siti esterni"; docs/compliance/20 §22):
every request to an external host is written down (UTC time, the name we
send, address, outcome), at least 10 seconds pass between two requests to
the same host, and a host that answers 403 or 429 (or shows a challenge)
is left alone from then on: no retry, no other server name or tool.

The log is metadata only: no query text, no answer, no personal data (the
importers never send any). It lives in `.local/radar/` (ignored by git) and
is never deleted by the scripts.
"""

from __future__ import annotations

import json
import time
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from packages.shared.config.external_hosts import forbidden_reason

LOG_NAME = "requests.log"
TURNS_NAME = "ultima_richiesta.json"
STOPPED_NAME = "host_fermati.json"
MIN_GAP_SECONDS = 10.0
# Answers that mean "stop": the host stays out until a person decides.
STOP_STATUSES = frozenset({403, 429})


def agent_name(user_agent: str) -> str:
    """The product token of a User-Agent ("QuokkaImport/1.0 (+...)" ->
    "QuokkaImport/1.0"): what the log records."""
    return user_agent.split(" ", 1)[0]


def log_address(url: str) -> str:
    """Scheme, host and path of `url`: query strings and fragments are left
    out, except the `prefix` of a bucket listing (it only names a folder)."""
    parts = urlsplit(url)
    address = f"{parts.scheme}://{parts.netloc}{parts.path}"
    prefix = parse_qs(parts.query).get("prefix")
    return f"{address}?prefix={prefix[0]}" if prefix else address


def log_request(
    log_path: Path,
    *,
    user_agent: str,
    url: str,
    outcome: object,
    started: str | None = None,
    count: int | None = None,
) -> None:
    """Appends one metadata-only line (JSON) to the request log."""
    row: dict[str, object] = {
        "quando": started or datetime.now(UTC).isoformat(timespec="seconds"),
        "nome": agent_name(user_agent),
        "indirizzo": log_address(url),
        "esito": outcome,
    }
    if count is not None:
        row["richieste"] = count
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False) + "\n")


class HostStoppedError(Exception):
    """A host said no (403/429) now or in an earlier run: leave it alone."""

    def __init__(self, host: str, reason: str) -> None:
        super().__init__(f"{host}: {reason}")
        self.host = host
        self.reason = reason


class HostTurns:
    """Minimum gap between two requests to one host, kept on disk so that a
    rerun of the same command respects it too, and the list of stopped hosts."""

    def __init__(
        self,
        local_dir: Path,
        gap_seconds: float = MIN_GAP_SECONDS,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._turns_path = local_dir / TURNS_NAME
        self._stopped_path = local_dir / STOPPED_NAME
        self._gap = max(MIN_GAP_SECONDS, gap_seconds)
        self._clock = clock

    def _read(self, path: Path) -> dict[str, object]:
        if not path.exists():
            return {}
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
        return data if isinstance(data, dict) else {}

    def _write(self, path: Path, data: dict[str, object]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    def stopped_reason(self, host: str) -> str | None:
        """Why `host` is out: the permanent list first (never contacted),
        then the hosts stopped by a 403/429 in an earlier run."""
        if permanent := forbidden_reason(host):
            return f"escluso per sempre: {permanent}"
        reason = self._read(self._stopped_path).get(host)
        return str(reason) if reason is not None else None

    def stop(self, host: str, reason: str) -> None:
        stopped = self._read(self._stopped_path)
        stopped[host] = f"{datetime.now(UTC).isoformat(timespec='seconds')} {reason}"
        self._write(self._stopped_path, stopped)

    def seconds_to_wait(self, host: str) -> float:
        last = self._read(self._turns_path).get(host)
        if not isinstance(last, int | float):
            return 0.0
        return max(0.0, float(last) + self._gap - self._clock())

    def record(self, host: str) -> None:
        """Called when a request to `host` ends (the gap counts from there)."""
        turns = self._read(self._turns_path)
        turns[host] = self._clock()
        self._write(self._turns_path, turns)
