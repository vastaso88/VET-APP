"""The web server of the collaudo bridges `/api` to the twin with the Vercel bypass code, the
code never enters a build, and Android allows plain http to 10.0.2.2 only in profile builds.
Local sockets only: a fake twin on 127.0.0.1 stands in for Vercel."""

from __future__ import annotations

import functools
import json
import threading
import urllib.request
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from scripts.collaudo import build_collaudo, ponte, servi_web
from scripts.collaudo.config import Gemello, GemelloNonSicuro

ROOT = Path(__file__).resolve().parents[2]
TWIN = Gemello(
    "https://abcdefghijklmnopqrst.supabase.co",
    "anon",
    "",
    "https://vet-app-git-collaudo-x.vercel.app",
    "codice-di-prova",
)


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("/api/chat?x=1", "/chat?x=1"),
        ("/api", "/"),
        ("/api?x=1", "/?x=1"),
        ("/apifake", None),
        ("/home-shell", None),
    ],
)
def test_only_api_paths_are_bridged(path: str, expected: str | None) -> None:
    assert ponte.percorso_api(path) == expected


def test_the_request_to_the_twin_carries_the_bypass_code_and_the_callers_headers() -> None:
    request = ponte.richiesta_inoltrata(
        TWIN,
        "POST",
        "/chat?x=1",
        {"Host": "localhost:8080", "Authorization": "Bearer t", "x-vercel-protection-bypass": "x"},
        b"{}",
    )
    assert request.full_url == "https://vet-app-git-collaudo-x.vercel.app/chat?x=1"
    headers = {name.lower(): value for name, value in request.header_items()}
    assert headers["x-vercel-protection-bypass"] == "codice-di-prova"
    assert headers["authorization"] == "Bearer t" and "host" not in headers


@pytest.mark.parametrize("path", ["//evil.example.com/x", "http://evil.example.com", ""])
def test_the_bridge_never_goes_anywhere_else(path: str) -> None:
    with pytest.raises(GemelloNonSicuro):
        ponte.richiesta_inoltrata(TWIN, "GET", path, {}, None)


class _FakeTwin(BaseHTTPRequestHandler):
    def _echo(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode() if length else ""
        out = json.dumps(
            {
                "method": self.command,
                "path": self.path,
                "body": body,
                "bypass": self.headers.get("x-vercel-protection-bypass"),
            }
        ).encode()
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    do_GET = do_POST = do_DELETE = _echo

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return


@pytest.fixture
def web_server(tmp_path: Path) -> Iterator[str]:
    (tmp_path / "index.html").write_text("<html>app</html>", encoding="utf-8")
    twin_server = ThreadingHTTPServer(("127.0.0.1", 0), _FakeTwin)
    threading.Thread(target=twin_server.serve_forever, daemon=True).start()
    twin = Gemello(
        TWIN.supabase_url, "anon", "", f"http://127.0.0.1:{twin_server.server_port}", "codice"
    )
    handler = functools.partial(servi_web._handler(twin), directory=str(tmp_path))
    app_server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=app_server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{app_server.server_port}"
    app_server.shutdown()
    twin_server.shutdown()


def test_api_calls_reach_the_twin_with_the_code_and_pages_get_the_app(web_server: str) -> None:
    request = urllib.request.Request(web_server + "/api/chat?x=1", data=b'{"a":1}', method="POST")
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=10) as response:
        assert response.status == 201
        echoed = json.loads(response.read())
    assert echoed == {"method": "POST", "path": "/chat?x=1", "body": '{"a":1}', "bypass": "codice"}
    with urllib.request.urlopen(web_server + "/home-shell", timeout=10) as response:
        assert response.read() == b"<html>app</html>"


def test_the_server_listens_on_this_computer_only() -> None:
    source = Path(servi_web.__file__).read_text(encoding="utf-8")
    assert 'ThreadingHTTPServer(("127.0.0.1"' in source and "0.0.0.0" not in source


def test_builds_call_the_bridge_and_never_carry_the_code(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    (tmp_path / "utenti.json").write_text(
        json.dumps({"col-telefono@example.com": {"password": "p", "id": "u"}}), "utf-8"
    )
    web = build_collaudo.valori(TWIN, "col-telefono")
    apk = build_collaudo.valori(TWIN, "col-telefono", apk=True)
    assert web["API_BASE_URL"] == "http://localhost:8080/api"
    assert apk["API_BASE_URL"] == "http://10.0.2.2:8080/api"
    assert "codice-di-prova" not in json.dumps([web, apk])


def test_plain_http_to_the_computer_is_allowed_only_in_profile_builds() -> None:
    android = ROOT / "apps" / "mobile_app" / "android" / "app" / "src"
    main = (android / "main" / "AndroidManifest.xml").read_text("utf-8")
    assert "networkSecurityConfig" not in main and "usesCleartextTraffic" not in main
    profile = (android / "profile" / "res" / "xml" / "network_security_config.xml").read_text(
        "utf-8"
    )
    assert '<base-config cleartextTrafficPermitted="false"' in profile
    domains = [line.strip() for line in profile.splitlines() if "<domain " in line]
    assert domains == ['<domain includeSubdomains="false">10.0.2.2</domain>']
