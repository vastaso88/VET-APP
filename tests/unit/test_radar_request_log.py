"""The radar importers' request log, host turns and stopped hosts
(scripts/radar/request_log.py; CLAUDE.md "Richieste a siti esterni")."""

from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parents[2]


def _load(name: str) -> Any:
    scripts = str(ROOT / "scripts" / "radar")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    return importlib.import_module(name)


def test_log_lines_hold_only_time_name_address_and_outcome(tmp_path: Path) -> None:
    log = _load("request_log")
    path = tmp_path / "radar" / "requests.log"
    log.log_request(
        path,
        user_agent="QuokkaImport/1.0 (+https://quokkapet.net; import periodico)",
        url="https://mirror.example.org/api/interpreter",
        outcome=200,
        started="2026-11-26T10:00:00+00:00",
    )
    log.log_request(
        path,
        user_agent="QuokkaImport/1.0 (+https://quokkapet.net; import periodico)",
        url="https://bucket.example.com/?list-type=2&prefix=release/x/&token=abc#frag",
        outcome="GET 200",
        count=3,
    )
    first, second = (json.loads(line) for line in path.read_text("utf-8").splitlines())
    assert first == {
        "quando": "2026-11-26T10:00:00+00:00",
        "nome": "QuokkaImport/1.0",
        "indirizzo": "https://mirror.example.org/api/interpreter",
        "esito": 200,
    }
    # Query strings are dropped, except the folder of a bucket listing.
    assert second["indirizzo"] == "https://bucket.example.com/?prefix=release/x/"
    assert second["richieste"] == 3
    assert second["quando"].endswith("+00:00")
    assert second["nome"].startswith("Quokka")


def test_host_turns_keep_ten_seconds_even_across_runs(tmp_path: Path) -> None:
    log = _load("request_log")
    now = [1000.0]
    turns = log.HostTurns(tmp_path, gap_seconds=3, clock=lambda: now[0])
    assert turns.seconds_to_wait("mirror.example.org") == 0
    turns.record("mirror.example.org")
    now[0] += 4
    # A shorter pause is never accepted: 10 s is the floor.
    assert turns.seconds_to_wait("mirror.example.org") == pytest.approx(6)
    assert turns.seconds_to_wait("other.example.com") == 0
    # A new run (new object) reads the last turn from disk.
    again = log.HostTurns(tmp_path, clock=lambda: now[0])
    assert again.seconds_to_wait("mirror.example.org") == pytest.approx(6)


def test_a_stopped_host_stays_stopped(tmp_path: Path) -> None:
    log = _load("request_log")
    turns = log.HostTurns(tmp_path)
    assert turns.stopped_reason("mirror.example.org") is None
    turns.stop("mirror.example.org", "HTTP 429")
    reason = log.HostTurns(tmp_path).stopped_reason("mirror.example.org")
    assert reason is not None and reason.endswith("HTTP 429")


SERVER = "https://overpass.example/api/interpreter"


def test_overpass_429_stops_the_server_without_retry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    importer = _load("import_osm_places")
    calls: list[str] = []

    def fake_urlopen(req: Any, timeout: float = 0) -> Any:
        calls.append(req.full_url)
        raise importer.error.HTTPError(req.full_url, 429, "Too Many Requests", {}, None)  # type: ignore[arg-type]

    monkeypatch.setattr(importer.request, "urlopen", fake_urlopen)
    fetcher = importer.Fetcher(600, local_dir=tmp_path, servers=(SERVER,))
    with pytest.raises(importer.HostStoppedError):
        fetcher.elements("[out:json];node(1);out;")
    assert calls == [SERVER]
    rows = [json.loads(line) for line in (tmp_path / "requests.log").read_text().splitlines()]
    assert [row["esito"] for row in rows] == [429]
    assert importer.HostTurns(tmp_path).stopped_reason("overpass.example")
    # The next run refuses the host without sending anything.
    with pytest.raises(importer.HostStoppedError):
        importer.Fetcher(600, local_dir=tmp_path, servers=(SERVER,)).elements("[out:json];")
    assert len(calls) == 1


@pytest.mark.parametrize(
    "server",
    ["https://overpass-api.de/api/interpreter", "https://z.overpass-api.de/api/interpreter"],
)
def test_overpass_api_de_is_refused_before_any_request(
    server: str, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    importer = _load("import_osm_places")
    calls: list[str] = []
    monkeypatch.setattr(importer.request, "urlopen", lambda req, timeout=0: calls.append(req))
    with pytest.raises(importer.HostStoppedError, match="robots.txt"):
        importer.Fetcher(600, local_dir=tmp_path, servers=(server,)).elements("[out:json];")
    assert calls == []
    assert not (tmp_path / "requests.log").exists()


def test_the_command_line_refuses_overpass_api_de_and_has_no_default_server(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    importer = _load("import_osm_places")
    monkeypatch.setattr(importer, "CACHE_DIR", tmp_path)
    monkeypatch.setattr(importer, "LOCAL_DIR", tmp_path)
    argv = ["import_osm_places.py", "--country", "DE", "--regions", "DE-HB", "--dry-run"]
    monkeypatch.setattr(sys, "argv", [*argv, "--server", "https://overpass-api.de/api/interpreter"])
    with pytest.raises(SystemExit):
        importer.main()
    assert "robots.txt" in capsys.readouterr().err
    # No server given: nothing to ask, a plain message, nothing written.
    monkeypatch.setattr(sys, "argv", argv)
    assert importer.main() == importer.EXIT_NO_SERVER
    assert "Nessun server Overpass" in capsys.readouterr().out
    assert not (tmp_path / "requests.log").exists()


def test_the_scripts_refuse_production_without_the_flag(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    common = _load("common")
    production = f"https://{common.PRODUCTION_SUPABASE_REF}.supabase.co"
    with pytest.raises(SystemExit, match="produzione"):
        common.check_production_target(production, allow_production=False)
    common.check_production_target(production, allow_production=True)
    common.check_production_target("https://twinproject.supabase.co", allow_production=False)
    # build_client stops before creating any client.
    monkeypatch.setattr(common, "_load_dotenv", lambda: None)
    monkeypatch.setenv("SUPABASE_URL", production.upper())
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-only-not-a-key")
    with pytest.raises(SystemExit, match="produzione"):
        common.build_client()
