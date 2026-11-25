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
    "controllata_nella_pagina": True,
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


def test_proof_phrase_must_appear_in_the_downloaded_page() -> None:
    page = "Footer  All content is available under the Open Government Licence v3.0, except"
    assert L.proof_in_page("all content is available under the open government licence v3.0", page)
    assert not L.proof_in_page("Creative Commons Attribution", page)
    assert not L.proof_in_page("", page)


def test_unverified_proof_is_not_green(tmp_path: Path) -> None:
    proof = {k: v for k, v in PROOF.items() if k != "controllata_nella_pagina"}
    with pytest.raises(S.SourceError, match="verificata"):
        S.Store(tmp_path / "f.json").add(good(prova=proof))


def test_italian_public_administration_rule() -> None:
    notes = "Note legali. Informazioni sul sito e sulla privacy."
    assert L.classify_text(notes, italian_pa=True).classe == L.VR
    assert L.classify_text(notes).classe == L.R
    reserved = "Tutti i diritti riservati. Uso consentito solo con consenso scritto."
    assert L.classify_text(reserved, italian_pa=True).classe == L.G
    assert L.classify_text("Licence CC BY 4.0", italian_pa=True).classe == L.V


def test_pdf_is_read_as_text(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    import subprocess

    class Done:
        stdout = b"Codice di benessere  per i cani.\n\n\nSecondo paragrafo"

    monkeypatch.setattr(subprocess, "run", lambda *a, **k: Done())
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/guida.pdf": (200, "%PDF-1.4", "application/pdf"),
    }
    fetcher, _, _ = make(tmp_path, table)
    page = fetcher.get("https://a.example.org/guida.pdf")
    assert page.text.startswith("Codice di benessere per i cani.") and page.fingerprint


def test_body_is_decoded_with_the_declared_charset() -> None:
    latin = "Bundesamt für Justiz".encode("latin-1")
    assert F.decode_body(latin, "text/html; charset=ISO-8859-1") == "Bundesamt für Justiz"
    assert F.decode_body(b'<meta charset="iso-8859-1">f\xfcr', "text/html").endswith("für")
    assert F.decode_body("für".encode(), "text/html") == "für"


def _scheda(url: str, sid: str = "guida-uno") -> dict[str, Any]:
    return {
        "id": sid, "titolo": "Guida", "url": url, "ente": "Ente", "paese": "Regno Unito",
        "lingua": "en", "livello": "guida_proprietari", "scritto_per": "proprietari",
        "specie": ["S11"], "temi": ["T02"], "perche": "Guida ufficiale",
    }  # fmt: skip


def test_add_source_uses_the_host_proof_and_never_refetches(tmp_path: Path) -> None:
    from scripts.sources import pipeline as P

    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/g": (
            200,
            "<html><title>G</title><p>Tieni l'acqua pulita.</p></html>",
        ),
        "https://a.example.org/r": (200, "<p>All rights reserved by someone.</p>"),
    }
    fetcher, opener, _ = make(tmp_path, table)
    store = S.Store(tmp_path / "f.json")
    registry = P.Registry(tmp_path / "h.json")
    assert P.add_source(
        fetcher, store, registry, _scheda("https://a.example.org/g"), tmp_path
    ).startswith("DA_REGISTRARE")
    entry = {"classe": "V", "licenza": "OGL v3.0", "copre": ["a.example.org"],
             "prova": PROOF, "base_legale": "", "attribuzione": ""}  # fmt: skip
    registry.save_entry("a.example.org", entry)
    out = P.add_source(fetcher, store, registry, _scheda("https://a.example.org/g"), tmp_path)
    assert (
        out.startswith("NUOVA") and store.load()["guida-uno"]["prova"]["controllata_nella_pagina"]
    )
    assert (tmp_path / "pagine" / "guida-uno.txt").exists()
    seen = len(opener.seen)
    assert P.add_source(
        fetcher, store, registry, _scheda("https://a.example.org/g"), tmp_path
    ).startswith("GIA_PRESENTE")
    assert len(opener.seen) == seen  # nessuna nuova richiesta
    assert P.add_source(
        fetcher, store, registry, _scheda("https://a.example.org/r", "guida-due"), tmp_path
    ).startswith("RISERVA")
    assert "guida-due" not in store.load()


def test_discarded_sources_leave_coverage_and_the_page(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good())
    store.discard("uk-defra-fish", "per produttori")
    assert store.coverage() == {} and not S.on_page(store.load()["uk-defra-fish"])


def test_two_commands_starting_together_do_not_hit_the_host_at_once(tmp_path: Path) -> None:
    a, _, clock_a = make(tmp_path, {})
    b, _, clock_b = make(tmp_path, {})
    clock_b.t = clock_a.t  # partono nello stesso istante
    a._pause("h.example.org", 0.0)
    b._pause("h.example.org", 0.0)
    assert not clock_a.slept  # il primo passa subito
    assert clock_b.slept and clock_b.slept[0] >= 9.99  # il secondo aspetta il suo turno
    c, _, clock_c = make(tmp_path, {})
    clock_c.t = clock_a.t
    c._pause("h.example.org", 0.0)
    assert clock_c.slept[0] >= 19.99  # il terzo è dopo il secondo


def test_one_403_stops_every_host_of_the_same_domain_for_everyone(tmp_path: Path) -> None:
    table = {
        "https://www.a.example.org/robots.txt": (404, ""),
        "https://www.a.example.org/p": (403, "no"),
    }
    first, _, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        first.get("https://www.a.example.org/p")
    other, opener, _ = make(tmp_path, {})  # un altro comando, avviato dopo
    with pytest.raises(F.Blocked, match="host fermato"):
        other.get("https://sub.a.example.org/x")  # stesso dominio registrabile
    with pytest.raises(F.Blocked, match="host fermato"):
        other.robots("sub.a.example.org")
    assert opener.seen == []
    assert F.registrable_domain("www.aphis.usda.gov") == "usda.gov"
    assert F.registrable_domain("assets.publishing.service.gov.uk") == "service.gov.uk"


def test_stop_file_is_read_before_every_request_not_only_at_start(tmp_path: Path) -> None:
    table = {
        "https://a.example.org/robots.txt": (404, ""),
        "https://a.example.org/1": (200, "<p>uno</p>"),
        "https://a.example.org/2": (200, "<p>due</p>"),
    }
    runner, opener, _ = make(tmp_path, table)
    runner.get("https://a.example.org/1")
    (tmp_path / "host_fermati.json").write_text(
        '{"a.example.org": "fermato da un altro lavoratore"}'
    )
    with pytest.raises(F.Blocked, match="fermato da un altro lavoratore"):
        runner.get("https://a.example.org/2")
    assert all("/2" not in u for u, _ in opener.seen)


def test_log_check_flags_requests_closer_than_ten_seconds(tmp_path: Path) -> None:
    from scripts.sources import pipeline as P

    log = tmp_path / "registro.jsonl"
    rows = [
        ("2026-11-21T10:00:00+01:00", "https://h.example.org/a"),
        ("2026-11-21T10:00:12+01:00", "https://h.example.org/b"),
        ("2026-11-21T10:00:13+01:00", "https://h.example.org/c"),  # solo 1 s dopo
        ("2026-11-21T10:00:13+01:00", "https://k.example.org/a"),
    ]
    log.write_text(
        "\n".join(json.dumps({"quando": w, "indirizzo": u, "esito": 200}) for w, u in rows)
    )
    robots = tmp_path / "robots_cache.json"
    ok, violations, minimum = P.check_log(log, robots)
    assert not ok and "h.example.org" in violations[0] and minimum["h.example.org"] == 1.0
    ok2, _, _ = P.check_log(log, robots, since="2026-11-21T10:00:13+01:00")
    assert ok2  # dopo la correzione non ci sono coppie sotto soglia
    robots.write_text(json.dumps({"k.example.org": {"text": "User-agent: *\nCrawl-delay: 30\n"}}))
    log.write_text(
        "\n".join(
            json.dumps({"quando": w, "indirizzo": u, "esito": 200})
            for w, u in [
                ("2026-11-21T10:00:00+01:00", "https://k.example.org/a"),
                ("2026-11-21T10:00:12+01:00", "https://k.example.org/b"),
            ]
        )
    )
    assert not P.check_log(log, robots)[0]  # 12 s ma il robots chiede 30 s


def test_www_and_bare_host_share_one_turn_and_log_holds_the_start_time(tmp_path: Path) -> None:
    table = {
        "https://x.example.org/robots.txt": (404, ""),
        "https://www.x.example.org/robots.txt": (404, ""),
        "https://x.example.org/a": (200, "<p>a</p>"),
        "https://www.x.example.org/b": (200, "<p>b</p>"),
    }
    fetcher, _, clock = make(tmp_path, table)
    fetcher.get("https://x.example.org/a")
    before = len(clock.slept)
    fetcher.get("https://www.x.example.org/b")
    assert len(clock.slept) > before  # stesso server: aspetta il suo turno
    rows = [
        json.loads(x)
        for x in (tmp_path / "registro_richieste.jsonl").read_text("utf-8").splitlines()
    ]
    assert all(set(r) >= {"quando", "nome", "indirizzo", "esito"} for r in rows)


def test_attribution_line_depends_on_host_and_kind_of_text() -> None:
    from scripts.sources import pipeline as P

    entry = {"classe": "V", "licenza": "OGL v3.0", "attribuzione": ""}
    ogl = P.attribution_for(entry, "Ente", "https://www.nidirect.gov.uk/x", "2026-11-21")
    assert "Open Government Licence v3.0" in ogl and "revised" not in ogl
    leg = P.attribution_for(
        entry, "Ente", "https://www.legislation.gov.uk/ukpga/2006/45", "2026-11-21"
    )
    assert "revised" in leg
    made = P.attribution_for(
        entry, "Ente", "https://www.legislation.gov.uk/ukpga/2006/45/enacted", "d"
    )
    assert "revised" not in made
    boe_c = P.attribution_for(entry, "BOE", "https://www.boe.es/buscar/act.php?id=X", "2026-11-21")
    assert "consolidado" in boe_c and "2026-11-21" in boe_c
    assert "texto oficial" in P.attribution_for(
        entry, "BOE", "https://www.boe.es/diario_boe/txt.php?id=X", "d"
    )
    de = P.attribution_for(
        entry, "BMJ", "https://www.gesetze-im-internet.de/tierschg/__1.html", "2026-11-21"
    )
    assert "nicht amtliche Fassung, Stand: 2026-11-21" in de
    ccby = {"classe": "V", "licenza": "CC BY", "attribuzione": "{ente}, CC BY 4.0, modificato."}
    assert P.attribution_for(ccby, "ECDC", "https://www.ecdc.europa.eu/x", "d").startswith(
        "ECDC, CC BY"
    )


def test_umbrella_suffix_list_is_closed() -> None:
    expected = {
        "co.uk", "org.uk", "gov.uk", "ac.uk", "com.au", "gov.au", "org.au", "edu.au", "govt.nz",
        "co.nz", "gov.it", "gv.at", "co.at", "gob.es", "com.es", "europa.eu",
    }  # fmt: skip
    assert F.UMBRELLA_SUFFIXES == expected  # cambiare l'elenco richiede il parere della Normativa
    assert F.umbrella_of("www.ecdc.europa.eu") == "europa.eu"
    assert F.umbrella_of("www.nidirect.gov.uk") == "gov.uk"
    assert F.umbrella_of("www.usda.gov") == ""


def _blocked_fetcher(tmp_path: Path, host: str) -> F.Fetcher:
    table = {f"https://{host}/robots.txt": (404, ""), f"https://{host}/p": (403, "no")}
    fetcher, _, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        fetcher.get(f"https://{host}/p")
    return fetcher


def test_one_block_under_an_umbrella_stops_only_that_agency(tmp_path: Path) -> None:
    _blocked_fetcher(tmp_path, "www.ecdc.europa.eu")
    other, opener, _ = make(tmp_path, {"https://www.efsa.europa.eu/robots.txt": (404, "")})
    assert other.is_stopped("www.efsa.europa.eu") is None  # un altro ente: resta aperto
    assert other.is_stopped("sub.ecdc.europa.eu")  # stesso ente: fermo
    assert other.is_stopped("www.ecdc.europa.eu")


def test_second_agency_blocked_the_same_day_stops_the_whole_umbrella(tmp_path: Path) -> None:
    _blocked_fetcher(tmp_path, "www.ecdc.europa.eu")
    second = _blocked_fetcher(tmp_path, "www.efsa.europa.eu")
    assert second.is_stopped("www.anything.europa.eu")  # protezione condivisa
    third, opener, _ = make(tmp_path, {})
    with pytest.raises(F.Blocked, match="suffisso europa.eu"):
        third.get("https://www.eea.europa.eu/x")
    assert opener.seen == []
    assert third.is_stopped("www.nidirect.gov.uk") is None  # altri suffissi non toccati


def test_topics_are_optional_validated_and_counted(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good(argomenti=["gatto-lettiera", "gatto-lettiera-nuova"]))
    store.add(good(id="altra", argomenti=["gatto-lettiera"]))
    store.add(good(id="senza"))  # il campo è facoltativo
    assert store.topic_coverage() == {"gatto-lettiera": 2, "gatto-lettiera-nuova": 1}
    with pytest.raises(S.SourceError, match="argomenti"):
        store.add(good(id="male", argomenti=["", "ok"]))
    assert S.page_doc(good(argomenti=["x"]))["argomenti"] == ["x"]
    store.discard("altra", "non adatta")
    assert store.topic_coverage()["gatto-lettiera"] == 1  # le scartate non contano


def test_second_read_prepares_clean_batches_and_flags_disagreements(tmp_path: Path) -> None:
    from scripts.sources import second_read as R

    store = S.Store(tmp_path / "f.json")
    store.add(good(id="uno", specie=["S11"] if False else ["S01", "S02"]))
    store.add(good(id="due", specie=["S03"]))
    pages = tmp_path / "pagine"
    pages.mkdir()
    (pages / "uno.txt").write_text(
        "Cani e gatti. Scrivi a mario@example.com o chiama +39 333 1234567."
    )
    (pages / "due.txt").write_text("Conigli: fieno sempre disponibile.")
    out, reviewed = tmp_path / "lotti", tmp_path / "riviste.json"
    assert R.prepare_batches(store, pages, out, reviewed, size=20) == ["lotto_01"]
    text = (out / "lotto_01.txt").read_text()
    assert "mario@example.com" not in text and "1234567" not in text and "[EMAIL]" in text
    mapping = json.loads((out / "lotto_01.json").read_text())
    assert mapping == {"01": "due", "02": "uno"}  # in ordine di id
    answers = [
        {"n": 1, "specie": ["S03"], "temi": ["T01"], "per_proprietari": True, "adatto": True},
        {"n": 2, "specie": ["S01"], "temi": ["T02"], "per_proprietari": False, "adatto": False,
         "perche": "per le autorità"},
    ]  # fmt: skip
    flagged = R.compare(store, mapping, answers)
    assert [f["id"] for f in flagged] == ["uno"]
    assert any("non adatta" in x for x in flagged[0]["flags"])
    assert any("S02" in x for x in flagged[0]["flags"])  # S02 dichiarata ma non nel testo
    R.mark_reviewed(reviewed, mapping, flagged)
    assert R.prepare_batches(store, pages, out, reviewed) == []  # già riviste: nessun nuovo lotto


def test_add_topics_merges_and_refuses_sources_not_in_use(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good())
    assert store.add_topics("uk-defra-fish", ["ARG-S11-T02-001"]).startswith("OK")
    assert store.add_topics("uk-defra-fish", ["ARG-S11-T02-002", "ARG-S11-T02-001"]).endswith(
        "2 argomenti"
    )
    assert store.add_topics("uk-defra-fish", ["pesci"]).startswith("ARGOMENTI_NON_VALIDI")
    assert store.add_topics("manca", ["ARG-S11-T02-001"]).startswith("SCONOSCIUTA")
    store.discard("uk-defra-fish", "x")
    assert store.add_topics("uk-defra-fish", ["ARG-S11-T02-001"]).startswith("NON_IN_USO")
    assert store.topic_coverage() == {}


def test_weak_topic_links_can_be_removed(tmp_path: Path) -> None:
    store = S.Store(tmp_path / "f.json")
    store.add(good())
    store.add_topics("uk-defra-fish", ["ARG-S11-T02-001", "ARG-S11-T02-002"])
    assert store.remove_topics("uk-defra-fish", ["ARG-S11-T02-002"]).endswith("restano 1")
    assert store.topic_coverage() == {"ARG-S11-T02-001": 1}
    assert store.remove_topics("manca", ["ARG-X"]).startswith("SCONOSCIUTA")


def test_independent_sources_count_families_not_copies(tmp_path: Path) -> None:
    from scripts.sources import independence as I  # noqa: E741

    base = " ".join(f"parola{i}" for i in range(120))
    pages = tmp_path / "pagine"
    pages.mkdir()
    store = S.Store(tmp_path / "f.json")
    for sid, text in {
        "codice-inghilterra": base,
        "codice-galles": base.replace("parola5", "altro5"),  # quasi uguale
        "legge-austriaca": " ".join(f"diverso{i}" for i in range(120)),
        "breve": "poche parole",
    }.items():
        store.add(good(id=sid, argomenti=["ARG-S01-T01-001"]))
        (pages / f"{sid}.txt").write_text(text)
    fam = I.families(store, pages)
    assert fam["codice-inghilterra"] == fam["codice-galles"] != fam["legge-austriaca"]
    assert fam["breve"] == "breve"  # testo troppo corto: resta da solo
    info = I.topic_independence(store, fam)["ARG-S01-T01-001"]
    assert info["fonti"] == 4 and info["indipendenti"] == 3
    fam2 = I.families(store, pages, manual={"legge-austriaca": "codice-inghilterra"})
    assert I.topic_independence(store, fam2)["ARG-S01-T01-001"]["indipendenti"] == 2
