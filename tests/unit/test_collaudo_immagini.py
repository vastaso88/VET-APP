"""Pictures of the collaudo: only local addresses and files, phone size, light and dark;
drafts that reach the internet are refused. Offline: Chrome is never started here."""

from __future__ import annotations

from pathlib import Path

import pytest

from scripts.collaudo import bozza_png, chrome, schermate


@pytest.mark.parametrize(
    "url",
    ["https://vet-app-psi-nine.vercel.app/home", "https://example.com", "http://10.0.0.5:8080"],
)
def test_only_local_addresses_are_photographed(url: str) -> None:
    with pytest.raises(chrome.IndirizzoNonLocale):
        chrome.controlla_locale(url)


@pytest.mark.parametrize(
    "url", ["http://localhost:8080/home", "http://127.0.0.1:5000", "file:///c:/x.html"]
)
def test_local_addresses_and_files_are_accepted(url: str) -> None:
    assert chrome.controlla_locale(url) == url


def test_phone_size_and_colour_scheme(tmp_path: Path) -> None:
    light = chrome.argomenti(
        "http://localhost:1/x", tmp_path / "a.png", scuro=False, profilo=tmp_path, attesa_ms=1000
    )
    dark = chrome.argomenti(
        "http://localhost:1/x", tmp_path / "a.png", scuro=True, profilo=tmp_path, attesa_ms=1000
    )
    assert "--window-size=390,844" in light
    assert "--blink-settings=preferredColorScheme=1" in light and "--force-dark-mode" not in light
    assert "--blink-settings=preferredColorScheme=0" in dark and "--force-dark-mode" in dark
    assert light[-1] == "http://localhost:1/x"


@pytest.mark.parametrize(
    "html",
    [
        '<img src="https://cdn.example.com/a.png">',
        "<link href='//fonts.example.com/x.css'>",
        "<style>@import 'https://x/y.css';</style>",
        "<style>body{background:url(https://x/y.png)}</style>",
    ],
)
def test_drafts_that_reach_the_internet_are_refused(html: str, tmp_path: Path) -> None:
    assert bozza_png.remota(html)
    draft = tmp_path / "b.html"
    draft.write_text(html, encoding="utf-8")
    with pytest.raises(ValueError):
        bozza_png.converti(draft)


def test_local_drafts_are_fine() -> None:
    assert not bozza_png.remota('<img src="mascotte.png"><style>a{color:#2b2b2b}</style>')


def test_picture_names_say_page_and_theme() -> None:
    assert schermate.nome_file("/home-shell", True) == "home_shell_scuro.png"
    assert schermate.nome_file("/", False) == "avvio_chiaro.png"


def test_the_collaudo_build_always_passes_the_twin_and_its_own_entry_point(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    import json

    from scripts.collaudo import build_collaudo
    from scripts.collaudo.config import Gemello

    monkeypatch.setenv("COLLAUDO_OUTPUT", str(tmp_path))
    (tmp_path / "utenti.json").write_text(
        json.dumps({"col-est-home@example.com": {"password": "p", "id": "u"}}), "utf-8"
    )
    twin = Gemello(
        "https://abcdefghijklmnopqrst.supabase.co",
        "anon",
        "",
        "https://vet-app-git-collaudo-x.vercel.app",
        "",
    )
    values = build_collaudo.valori(twin, "col-est-home")
    assert values["SUPABASE_URL"] == twin.supabase_url
    assert values["COLLAUDO_SUPABASE_REF"] == "abcdefghijklmnopqrst"
    assert values["ENVIRONMENT"] != "production"
    assert values["COLLAUDO_EMAIL"] == "col-est-home@example.com"
    command = build_collaudo.comando_web(tmp_path / "v.json")
    assert command[command.index("-t") + 1] == "lib/main_collaudo.dart"
    assert "--no-web-resources-cdn" in command
    assert any(part.startswith("--dart-define-from-file=") for part in command)


def test_the_web_server_refuses_a_folder_that_is_not_a_build(tmp_path: Path) -> None:
    from scripts.collaudo import servi_web

    assert servi_web.main([str(tmp_path)]) == 2
