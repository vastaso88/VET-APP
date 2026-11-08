"""The site build must refuse a publication build while any placeholder is left."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType, SimpleNamespace
from typing import Any

import pytest

_BUILD_PATH = Path(__file__).resolve().parents[2] / "apps" / "site" / "tools" / "build.py"

_UI = {
    "skip": "Vai al contenuto",
    "nav_label": "Pagine",
    "toc_label": "Indice",
    "draft_banner": "BOZZA",
    "footer_owner": "Titolare: Mario Esempio",
    "footer_note": "Nessun cookie.",
    "footer_draft": "Sito in costruzione.",
}

_HEADER = "> BOZZA [NOME_IN_MAIUSCOLO] nell'intestazione\n\n---\n\n"
_NOTES = "\n---\n\n## Note per il revisore (da eliminare)\n\n1. Sistemare [TITOLARE].\n"


@pytest.fixture
def build(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    spec = importlib.util.spec_from_file_location("site_build_under_test", _BUILD_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "REPO_DIR", tmp_path)
    monkeypatch.setattr(module, "SITE_DIR", tmp_path / "site")
    monkeypatch.setattr(module, "DRAFT", True)  # main() flips it; restored after the test
    return module


def _lang(pages: list[dict[str, Any]], ui: dict[str, str] | None = None) -> SimpleNamespace:
    return SimpleNamespace(
        LANG="it",
        UI=ui or _UI,
        PAGES=pages,
        NOT_FOUND={"title": "Non trovata", "body": "<h1>Non trovata</h1>"},
    )


def _legal(tmp_path: Path, body: str, name: str = "privacy.md") -> dict[str, Any]:
    (tmp_path / name).write_text(f"{_HEADER}# Titolo\n\n{body}\n{_NOTES}", encoding="utf-8")
    return {"slug": "privacy", "nav": "Privacy", "title": "Privacy", "description": "d", "md": name}


@pytest.mark.parametrize(
    "marker",
    [
        "[TITOLARE]",
        "[CF_PIVA]",
        "[da verificare: con il legale]",
        "[da decidere: età minima]",
        "[in attesa del codice: data di nascita]",
        "[in attesa del codice]",
        "[togliere questa riga se non più usato]",
        "punto di diritto ⚖️",
    ],
)
def test_every_kind_of_open_marker_is_reported(
    build: ModuleType, tmp_path: Path, marker: str
) -> None:
    page = _legal(tmp_path, f"Prima riga pulita.\nRiga con {marker} dentro.")
    problems = build.release_problems(_lang([page]))
    assert len(problems) == 1
    assert problems[0].startswith("privacy.md:")


def test_message_gives_the_real_line_of_the_source_file(build: ModuleType, tmp_path: Path) -> None:
    page = _legal(tmp_path, "uno\n\ndue [TITOLARE]")
    (problem,) = build.release_problems(_lang([page]))
    source_lines = (tmp_path / "privacy.md").read_text(encoding="utf-8").splitlines()
    number = int(problem.split(":")[1])
    assert "[TITOLARE]" in source_lines[number - 1]
    assert problem.endswith("[TITOLARE]")


def test_clean_pages_have_no_problems(build: ModuleType, tmp_path: Path) -> None:
    page = _legal(tmp_path, "Testo definitivo, con un [link](/it/termini/) e **grassetto**.")
    other = {"slug": "", "nav": "Home", "title": "Quokka", "description": "d", "body": "<h1>Q</h1>"}
    assert build.release_problems(_lang([page, other])) == []


def test_header_and_reviewer_notes_are_not_published_so_not_checked(
    build: ModuleType, tmp_path: Path
) -> None:
    page = _legal(tmp_path, "Testo pulito.")
    assert build.release_problems(_lang([page])) == []


def test_substitutions_that_fill_a_placeholder_resolve_it(
    build: ModuleType, tmp_path: Path
) -> None:
    page = _legal(tmp_path, "Scrivi a [EMAIL_ASSISTENZA].")
    assert build.release_problems(_lang([page]))
    page["subs"] = {"[EMAIL_ASSISTENZA]": "assistenza@example.com"}
    assert build.release_problems(_lang([page])) == []


def test_hand_written_pages_and_layout_words_are_checked(build: ModuleType) -> None:
    page = {
        "slug": "avviso-ia",
        "nav": "Avviso",
        "title": "Avviso",
        "description": "d",
        "body": "<h1>A</h1>\n<p>Durata: <mark>[da verificare: copie]</mark></p>",
    }
    ui = {**_UI, "footer_owner": "Titolare: <mark>[TITOLARE]</mark>"}
    problems = build.release_problems(_lang([page], ui))
    assert any("avviso-ia" in p and "body" in p for p in problems)
    assert any("UI[footer_owner]" in p for p in problems)


def test_draft_only_layout_words_are_not_flagged(build: ModuleType) -> None:
    ui = {**_UI, "draft_banner": "BOZZA [da compilare]", "footer_draft": "In costruzione [TODO]"}
    assert build.release_problems(_lang([], ui)) == []


def test_release_build_stops_and_writes_nothing_while_markers_remain(
    build: ModuleType,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    page = _legal(tmp_path, "Titolare [TITOLARE].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _lang_code: _lang([page]))

    assert build.main(["--release"]) == 1

    err = capsys.readouterr().err
    assert "Release blocked: 1 open marker" in err
    assert "privacy.md:" in err
    assert not (tmp_path / "site").exists()
    assert build.DRAFT is True


def test_release_build_with_everything_settled_publishes_without_draft_marks(
    build: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    page = _legal(tmp_path, "Testo definitivo.")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _lang_code: _lang([page]))

    assert build.main(["--release"]) == 0

    site = tmp_path / "site"
    html = (site / "it" / "privacy" / "index.html").read_text(encoding="utf-8")
    assert "noindex" not in html
    assert 'class="draft"' not in html
    assert "Sito in costruzione" not in html
    assert (site / "robots.txt").read_text(encoding="utf-8") == "User-agent: *\nAllow: /\n"


def test_default_build_stays_a_draft_even_with_markers(
    build: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    page = _legal(tmp_path, "Titolare [TITOLARE].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _lang_code: _lang([page]))

    assert build.main([]) == 0

    site = tmp_path / "site"
    html = (site / "it" / "privacy" / "index.html").read_text(encoding="utf-8")
    assert "noindex" in html
    assert 'class="draft"' in html
    assert "<mark>[TITOLARE]</mark>" in html
    assert (site / "robots.txt").read_text(encoding="utf-8") == "User-agent: *\nDisallow: /\n"
