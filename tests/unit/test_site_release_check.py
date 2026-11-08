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
    monkeypatch.setattr(module, "OUT_DIR", None)
    monkeypatch.setattr(module, "_VALUES", {})
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


_OWNER = {
    "QUOKKA_SITE_TITOLARE": "Esempio & Figli S.r.l.",
    "QUOKKA_SITE_SEDE": "Via Esempio 1, 00100 Roma",
}


def _footer_lang(page: dict[str, Any]) -> SimpleNamespace:
    return _lang([page], {**_UI, "footer_owner": "Titolare: [TITOLARE], [SEDE]."})


def test_environment_values_fill_placeholders_in_texts_and_footer(
    build: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    page = _legal(tmp_path, "Titolare: **[TITOLARE]**, sede [SEDE].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _code: _footer_lang(page))

    assert build.main(["--release"], _OWNER) == 0

    html = (tmp_path / "site" / "it" / "privacy" / "index.html").read_text(encoding="utf-8")
    assert "<strong>Esempio &amp; Figli S.r.l.</strong>" in html  # escaped, never raw markup
    assert "Via Esempio 1, 00100 Roma" in html
    assert "Titolare: Esempio &amp; Figli S.r.l., Via Esempio 1, 00100 Roma." in html
    assert "[TITOLARE]" not in html
    assert "<mark>" not in html


def test_release_stops_naming_the_variables_that_are_missing(
    build: ModuleType,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    page = _legal(tmp_path, "Titolare [TITOLARE], sede [SEDE], PEC [PEC].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _code: _footer_lang(page))

    assert build.main(["--release"], {"QUOKKA_SITE_TITOLARE": "Esempio S.r.l."}) == 1

    err = capsys.readouterr().err
    assert "QUOKKA_SITE_<NAME>" in err
    assert "SEDE" in err and "PEC" in err
    assert "Open names: SEDE, PEC" in err  # TITOLARE is set, so it is not open
    assert "Esempio S.r.l." not in err
    assert not (tmp_path / "site").exists()


@pytest.mark.parametrize("value", ["a | b", "[x]", "riga\ndue", "<b>", "`x`", "*x*"])
def test_unusable_values_are_refused_without_echoing_them(
    build: ModuleType,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    value: str,
) -> None:
    values, errors = build.values_from_environ({"QUOKKA_SITE_TITOLARE": value})
    assert values == {}
    assert errors and value not in errors[0]

    page = _legal(tmp_path, "Testo definitivo.")
    monkeypatch.setattr(build, "_load_lang", lambda _code: _lang([page]))
    monkeypatch.setattr(build, "LANGS", ["it"])
    assert build.main(["--release"], {"QUOKKA_SITE_TITOLARE": value}) == 1
    assert "unusable environment variable" in capsys.readouterr().err


def test_environment_reading_ignores_other_variables_and_blank_values(build: ModuleType) -> None:
    values, errors = build.values_from_environ(
        {
            "QUOKKA_SITE_SEDE": "  Via Esempio 1  ",
            "QUOKKA_SITE_PEC": "   ",
            "PATH": "/usr/bin",
            "QUOKKA_OTHER": "x",
        }
    )
    assert values == {"SEDE": "Via Esempio 1"}
    assert errors == []


def test_draft_build_ignores_the_environment_and_keeps_placeholders(
    build: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    page = _legal(tmp_path, "Titolare [TITOLARE].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _code: _footer_lang(page))

    assert build.main([], _OWNER) == 0

    html = (tmp_path / "site" / "it" / "privacy" / "index.html").read_text(encoding="utf-8")
    assert "Esempio" not in html
    assert html.count("<mark>[TITOLARE]</mark>") == 2  # text and footer


def test_out_directory_gets_the_whole_site_and_leaves_the_sources_alone(
    build: ModuleType, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (tmp_path / "site" / "assets").mkdir(parents=True)
    (tmp_path / "site" / "assets" / "style.css").write_text("body{}", encoding="utf-8")
    page = _legal(tmp_path, "Testo definitivo.")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _code: _lang([page]))
    out = tmp_path / "dist"

    assert build.main(["--release", "--out", str(out)], {}) == 0

    for name in (
        "index.html",
        "404.html",
        "robots.txt",
        "it/privacy/index.html",
        "assets/style.css",
    ):
        assert (out / name).is_file(), name
    assert not (tmp_path / "site" / "it").exists()


@pytest.mark.parametrize(
    ("vercel_env", "expect_release"), [("production", True), ("preview", False), (None, False)]
)
def test_vercel_mode_releases_only_for_production(
    build: ModuleType,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    vercel_env: str | None,
    expect_release: bool,
) -> None:
    (tmp_path / "site" / "assets").mkdir(parents=True)
    page = _legal(tmp_path, "Titolare [TITOLARE].")
    monkeypatch.setattr(build, "LANGS", ["it"])
    monkeypatch.setattr(build, "_load_lang", lambda _code: _lang([page]))
    environ = {"VERCEL_ENV": vercel_env} if vercel_env else {}
    out = tmp_path / "dist"

    code = build.main(["--vercel", "--out", str(out)], environ)

    if expect_release:
        assert code == 1  # the placeholder is open: production must not go out
        assert not out.exists()
    else:
        assert code == 0
        assert "noindex" in (out / "it" / "privacy" / "index.html").read_text(encoding="utf-8")
