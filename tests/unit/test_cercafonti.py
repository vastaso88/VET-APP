"""Cercafonti (scripts/sources): regole di accesso ai siti, griglia delle licenze, elenco vivo."""

from __future__ import annotations

import io
import json
import urllib.error
from datetime import date
from email.message import Message
from pathlib import Path
from typing import Any

import pytest

from scripts.sources import fetcher as F
from scripts.sources import licenses as L
from scripts.sources import store as S

ROBOTS_OPEN = "User-agent: *\nDisallow: /private/\n"


class FakeResponse:
    def __init__(
        self, status: int, body: str, ctype: str = "text/html", location: str = ""
    ) -> None:
        self.status = status
        self.headers = Message()
        self.headers["Content-Type"] = ctype
        if location:
            self.headers["Location"] = location
        self._body = body.encode()

    def read(self, n: int = -1) -> bytes:
        return self._body

    def __enter__(self) -> FakeResponse:
        return self

    def __exit__(self, *a: object) -> None:
        return None


class FakeOpener:
    """Risponde da una tabella {url: (status, body, ctype, location)}; registra le richieste."""

    def __init__(self, table: dict[str, tuple[Any, ...]]) -> None:
        self.table = table
        self.seen: list[tuple[str, str]] = []

    def open(self, req: Any, timeout: float = 0) -> FakeResponse:
        self.seen.append((req.full_url, req.get_header("User-agent")))
        status, body, *rest = self.table.get(req.full_url, (404, ""))
        ctype = rest[0] if rest else "text/html"
        location = rest[1] if len(rest) > 1 else ""
        if status >= 300:
            headers = Message()
            headers["Content-Type"] = ctype
            if location:
                headers["Location"] = location
            raise urllib.error.HTTPError(
                req.full_url, status, "x", headers, io.BytesIO(body.encode())
            )
        return FakeResponse(status, body, ctype)


class Clock:
    def __init__(self) -> None:
        self.t = 1000.0
        self.slept: list[float] = []

    def now(self) -> float:
        return self.t

    def sleep(self, s: float) -> None:
        self.slept.append(s)
        self.t += s


def make(
    tmp_path: Path, table: dict[str, tuple[Any, ...]], cap: int = 50
) -> tuple[F.Fetcher, FakeOpener, Clock]:
    clock = Clock()
    opener = FakeOpener(table)
    fetcher = F.Fetcher(
        tmp_path,
        max_requests=cap,
        clock=clock.now,
        sleep=clock.sleep,
        opener=opener,  # type: ignore[arg-type]
    )
    return fetcher, opener, clock


def test_name_is_quokka_and_never_a_browser() -> None:
    assert F.USER_AGENT.startswith("Quokka")
    assert "mozilla" not in F.USER_AGENT.lower() and "claude" not in F.USER_AGENT.lower()


def test_reads_robots_first_then_page_and_logs_every_request(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (200, ROBOTS_OPEN, "text/plain"),
        "https://a.example.org/p": (
            200,
            "<html><title>T</title><body><p>Ciao mondo</p></body></html>",
        ),
    }
    fetcher, opener, _ = make(tmp_path, table)
    page = fetcher.get("https://a.example.org/p")
    assert [u for u, _ in opener.seen] == [
        "https://a.example.org/robots.txt",
        "https://a.example.org/p",
    ]
    assert all(ua.startswith("Quokka") for _, ua in opener.seen)
    assert page.title == "T" and "Ciao mondo" in page.text and page.fingerprint
    rows = [
        json.loads(x)
        for x in (tmp_path / "registro_richieste.jsonl").read_text("utf-8").splitlines()
    ]
    assert [r["esito"] for r in rows] == [200, 200]
    assert all(r["nome"].startswith("Quokka") for r in rows)


def test_robots_disallow_blocks_without_fetching_page(tmp_path: Path) -> None:
    table = {"https://a.example.org/robots.txt": (200, ROBOTS_OPEN, "text/plain")}
    fetcher, opener, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        fetcher.get("https://a.example.org/private/x")
    assert [u for u, _ in opener.seen] == ["https://a.example.org/robots.txt"]


def test_named_rule_for_our_robot_is_respected(tmp_path: Path) -> None:
    robots = "User-agent: QuokkaCercafonti\nDisallow: /\n\nUser-agent: *\nAllow: /\n"
    fetcher, _, _ = make(
        tmp_path, {"https://a.example.org/robots.txt": (200, robots, "text/plain")}
    )
    with pytest.raises(F.Blocked):
        fetcher.get("https://a.example.org/p")


def test_content_signal_ai_input_no_blocks(tmp_path: Path) -> None:
    robots = "User-agent: *\nAllow: /\nContent-Signal: search=yes, ai-input=no, ai-train=no\n"
    fetcher, _, _ = make(
        tmp_path, {"https://a.example.org/robots.txt": (200, robots, "text/plain")}
    )
    with pytest.raises(F.Blocked, match="ai-input"):
        fetcher.get("https://a.example.org/p")


def test_ai_train_no_is_reported_but_does_not_block_reading(tmp_path: Path) -> None:
    robots = "User-agent: *\nAllow: /\nContent-Signal: search=yes, ai-train=no\n"
    table = {
        "https://a.example.org/robots.txt": (200, robots, "text/plain"),
        "https://a.example.org/p": (200, "<p>ok</p>"),
    }
    fetcher, _, _ = make(tmp_path, table)
    fetcher.get("https://a.example.org/p")
    assert fetcher.robots("a.example.org").ai_train_no is True


def test_403_stops_the_host_for_good_no_retry(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (200, ROBOTS_OPEN, "text/plain"),
        "https://a.example.org/p": (403, "forbidden"),
    }
    fetcher, opener, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        fetcher.get("https://a.example.org/p")
    n = len(opener.seen)
    with pytest.raises(F.Blocked, match="host fermato"):
        fetcher.get("https://a.example.org/other")
    assert len(opener.seen) == n  # nessuna nuova richiesta all'host
    again, opener2, _ = make(tmp_path, table)  # il fermo resta anche al giro dopo
    with pytest.raises(F.Blocked, match="host fermato"):
        again.get("https://a.example.org/p")
    assert opener2.seen == []


def test_429_and_robots_403_stop_the_host(tmp_path: Path) -> None:
    fetcher, _, _ = make(tmp_path, {"https://b.example.org/robots.txt": (403, "no")})
    with pytest.raises(F.Blocked):
        fetcher.get("https://b.example.org/p")
    assert fetcher.is_stopped("b.example.org")


def test_challenge_page_stops_the_host(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/p": (200, "<html><title>Just a moment...</title></html>"),
    }
    fetcher, _, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked, match="verifica"):
        fetcher.get("https://a.example.org/p")
    assert fetcher.is_stopped("a.example.org")


def test_pause_of_ten_seconds_between_requests_to_the_same_host(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/1": (200, "<p>uno</p>"),
        "https://a.example.org/2": (200, "<p>due</p>"),
    }
    fetcher, _, clock = make(tmp_path, table)
    fetcher.get("https://a.example.org/1")
    fetcher.get("https://a.example.org/2")
    assert clock.slept and all(s >= 9.99 for s in clock.slept)
    assert len(clock.slept) == 2  # robots->1 e 1->2


def test_crawl_delay_longer_than_ten_is_honoured(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (200, "User-agent: *\nCrawl-delay: 30\n", "text/plain"),
        "https://a.example.org/1": (200, "<p>uno</p>"),
    }
    fetcher, _, clock = make(tmp_path, table)
    fetcher.get("https://a.example.org/1")
    assert max(clock.slept) >= 29.99


def test_redirect_to_a_new_host_goes_through_its_robots(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/old": (301, "", "text/html", "https://c.example.org/new"),
        "https://c.example.org/robots.txt": (200, "User-agent: *\nDisallow: /\n", "text/plain"),
    }
    fetcher, opener, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        fetcher.get("https://a.example.org/old")
    assert ("https://c.example.org/new") not in [u for u, _ in opener.seen]


def test_request_cap_is_enforced(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/1": (200, "<p>uno</p>"),
    }
    fetcher, _, _ = make(tmp_path, table, cap=1)
    with pytest.raises(F.CapReached):
        fetcher.get("https://a.example.org/1")


def test_fingerprint_ignores_case_spacing_and_punctuation() -> None:
    assert F.fingerprint_of("Il Cane,  beve.") == F.fingerprint_of("il cane beve")
    assert F.fingerprint_of("il cane beve") != F.fingerprint_of("il gatto beve")


@pytest.mark.parametrize(
    ("text", "host", "expected"),
    [
        ("Licensed under the Open Government Licence v3.0", "www.gov.uk", L.V),
        ("Content under the Open Government Licence v3.0. Non-commercial keepers", "g.uk", L.V),
        ("Creative Commons Attribution 4.0 International", "x.example.org", L.V),
        ("Released under CC0", "x.example.org", L.V),
        ("Creative Commons Attribution-NonCommercial 4.0", "x.example.org", L.R),
        ("CC BY-ND 4.0", "x.example.org", L.R),
        ("CC BY-SA 4.0", "x.example.org", L.R),
        ("CC BY-NC-SA 3.0 IGO", "www.who.int", L.R),
        ("CC BY 3.0 IGO", "www.who.int", L.G),
        ("© 2025 Society. All rights reserved.", "x.example.org", L.R),
        ("Per uso personale", "x.example.org", L.R),
        ("Contenuto dell'agenzia", "www.cdc.gov", L.VR),
        ("© CDC. All rights reserved.", "www.cdc.gov", L.R),
        ("Contenuto di un'università", "extension.example.edu", L.R),  # §23.4: senza licenza è R
        ("CC BY 4.0 e tdm-reservation: 1", "x.example.org", L.G),
    ],
)
def test_license_grid(text: str, host: str, expected: str) -> None:
    assert L.classify_text(text, host=host).classe == expected


def test_official_acts_are_green() -> None:
    assert L.classify_text("", official_act=True).classe == L.V


def test_evidence_is_at_most_25_words_and_holds_the_phrase() -> None:
    text = (
        "intro " * 40
        + "All content is available under the Open Government Licence v3.0, except"
        + " x" * 40
    )
    verdict = L.classify_text(text, host="www.gov.uk")
    assert 0 < len(verdict.frase.split()) <= 25
    assert "Open Government Licence" in verdict.frase


PROOF = {
    "frase": "All content is available under the Open Government Licence v3.0",
    "url": "https://www.gov.uk/help/terms-conditions",
    "data": "2026-11-21",
    "regola": "riga 1021: OGL",
    "robots": "ok",
    "terzi": "no",
}


def good(**kw: Any) -> dict[str, Any]:
    src: dict[str, Any] = {
        "id": "uk-defra-fish",
        "titolo": "Fish",
        "url": "https://www.gov.uk/x",
        "ente": "Defra",
        "paese": "UK",
        "lingua": "en",
        "livello": "guida_proprietari",
        "scritto_per": "proprietari",
        "specie": ["S11"],
        "temi": ["T02"],
        "licenza": "OGL v3.0",
        "classe": "V",
        "prova": PROOF,
        "perche": "Guida ufficiale del ministero",
        "stato": "in_uso",
        "notte": "2026-11-21",
    }
    src.update(kw)
    return src


def test_store_adds_sets_review_dates_and_never_overwrites(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    assert store.add(good()) is True
    assert store.add(good(titolo="Altro")) is False
    assert store.load()["uk-defra-fish"]["titolo"] == "Fish"
    assert store.load()["uk-defra-fish"]["prossimo_controllo"] == "2027-05-23"  # guide: 6 mesi
    store.add(good(id="it-legge", livello="legge", scritto_per="legge"))
    assert store.load()["it-legge"]["prossimo_controllo"] == "2027-02-21"  # leggi: 3 mesi


def test_red_source_never_in_use_and_bad_codes_rejected(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    with pytest.raises(S.SourceError):
        store.add(good(classe="R"))
    with pytest.raises(S.SourceError):
        store.add(good(specie=["S99"]))
    with pytest.raises(S.SourceError):
        store.add(good(livello="blog"))
    with pytest.raises(S.SourceError, match="prova"):  # senza prova non è verde
        store.add(good(prova={}))
    with pytest.raises(S.SourceError, match="25"):
        store.add(good(prova={**PROOF, "frase": "parola " * 26}))
    with pytest.raises(S.SourceError):  # una G non entra mai in uso
        store.add(good(classe="G"))
    assert store.add(good(classe="R", stato="non_usabile", prova={})) is True


def test_no_moves_to_not_approved_and_leaves_coverage(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good())
    assert store.coverage() == {"S11-T02": 1}
    store.apply_decision("uk-defra-fish", "no", "troppo vaga")
    src = store.load()["uk-defra-fish"]
    assert src["stato"] == "non_approvata" and src["nota_no"] == "troppo vaga" and src["visto"]
    assert store.coverage() == {}
    assert store.due(date(2099, 1, 1)) == []  # le non approvate non si riverificano
    store.apply_decision("uk-defra-fish", "ok")
    assert store.load()["uk-defra-fish"]["stato"] == "in_uso"


def test_due_lists_expired_sources(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good())
    assert store.due(date(2026, 12, 1)) == []
    assert [s["id"] for s in store.due(date(2027, 6, 1))] == ["uk-defra-fish"]


def test_page_doc_has_no_source_text() -> None:
    doc = S.page_doc(good(testo="TESTO COPIATO", impronta="abc"))
    assert "testo" not in doc and "impronta" not in doc and doc["visto"] is False


def test_only_v_vr_n_go_to_the_owner_page(tmp_path: Path) -> None:
    assert S.on_page(good()) and S.on_page(good(classe="N")) and S.on_page(good(classe="VR"))
    assert not S.on_page(good(classe="G")) and not S.on_page(good(classe="R"))


def test_pause_holds_across_two_commands(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/1": (200, "<p>uno</p>"),
        "https://a.example.org/2": (200, "<p>due</p>"),
    }
    first, _, clock1 = make(tmp_path, table)
    first.get("https://a.example.org/1")
    second, _, clock2 = make(tmp_path, table)
    clock2.t = clock1.t + 1  # un secondo dopo, in un altro comando
    second.get("https://a.example.org/2")
    assert clock2.slept and clock2.slept[0] >= 8.99


def test_law_portal_fingerprint_ignores_the_validity_date() -> None:
    def page(date: str) -> str:
        return (
            f"<html><body><div>vigente al {date}</div>"
            '<div class="bodyTesto">Art. 1 Testo dell atto. articolo successivo nascondi</div>'
            "</body></html>"
        )

    a = F.main_text("www.normattiva.it", page("21/11/2026"))
    b = F.main_text("www.normattiva.it", page("22/11/2026"))
    assert a == b and a is not None and a.startswith("Art. 1")
    assert F.main_text("www.gov.uk", page("x")) is None
