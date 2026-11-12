"""Builds the static site in apps/site from the page definitions in pages_<lang>.py.

    python apps/site/tools/build.py             # draft build: banner, noindex, robots blocks all
    python apps/site/tools/build.py --release   # publication build: stops if a marker is left
    python apps/site/tools/build.py --vercel --out dist   # what Vercel runs (see vercel.json)

The legal pages are laid out from the texts the legal workstream keeps in
docs/compliance/<lang>/, so they are never retyped here.

Owner data (company name, registered office, VAT number, ...) never lives in the
repository, which is public: the texts keep placeholders such as [TITOLARE]. A
publication build fills them from environment variables named QUOKKA_SITE_<NAME>
(QUOKKA_SITE_TITOLARE for [TITOLARE]) and stops if any placeholder stays open.
"""

from __future__ import annotations

import argparse
import html
import importlib
import os
import re
import shutil
import sys
from collections.abc import Mapping
from pathlib import Path
from types import ModuleType
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mdlite  # type: ignore[import-not-found]  # noqa: E402

SITE_DIR = Path(__file__).resolve().parents[1]
REPO_DIR = SITE_DIR.parents[1]
LANGS = ["it"]  # add "en", "de", ... here once pages_<lang>.py exists

# Where the site is written. None = in place, next to the sources (draft, local preview).
OUT_DIR: Path | None = None

# While True every page asks search engines not to index it and robots.txt
# blocks everything. main() turns it off for a release build.
DRAFT = True

ENV_PREFIX = "QUOKKA_SITE_"
# Owner data for the placeholders of a release build: {"TITOLARE": "..."}; set by main().
_VALUES: dict[str, str] = {}
# What an environment value may not contain: it would break the Markdown or the HTML around it.
_FORBIDDEN_IN_VALUE = re.compile(r"[\[\]|`*<>\r\n]")

# Placeholders ending in _O_VUOTO are for facts that only some companies have (sole
# shareholder, winding up): without a value they are left out and never block a release.
_OPTIONAL = re.compile(r"\[[A-Z][A-Z0-9_]*_O_VUOTO\]")

# A release build refuses to run while any of these is left in a page: placeholders
# ([TITOLARE], [da verificare: ...], [in attesa del codice: ...]) and the lawyer flag.
_REVIEW_FLAG = "⚖"  # the scales symbol the legal texts put next to points to confirm
# Layout words that only exist while the site is a draft.
_DRAFT_ONLY_UI = {"draft_banner", "footer_draft"}


def _load_lang(lang: str) -> ModuleType:
    return importlib.import_module(f"pages_{lang}")


def _out() -> Path:
    return OUT_DIR or SITE_DIR


def values_from_environ(environ: Mapping[str, str]) -> tuple[dict[str, str], list[str]]:
    """Owner data from QUOKKA_SITE_* variables, and a message per unusable variable.

    The messages never repeat a value: they may be personal data.
    """
    values: dict[str, str] = {}
    errors: list[str] = []
    for key, raw in environ.items():
        if not key.startswith(ENV_PREFIX):
            continue
        name, value = key[len(ENV_PREFIX) :], raw.strip()
        if not value:
            continue
        if not re.fullmatch(r"[A-Z][A-Z0-9_]+", name):
            errors.append(f"{key}: the name after {ENV_PREFIX} must be UPPER_CASE (A-Z, 0-9, _)")
        elif _FORBIDDEN_IN_VALUE.search(value):
            errors.append(f"{key}: value must be one line without [ ] | ` * < >")
        else:
            values[name] = value
    return values, errors


def _fill(text: str, *, escape: bool) -> str:
    """Replace every [NAME] that has an environment value.

    In a publication build an optional placeholder (see _OPTIONAL) that has no value
    disappears; in a draft it stays visible so the owner can see where it goes.
    """
    for name, value in _VALUES.items():
        text = text.replace(f"[{name}]", html.escape(value) if escape else value)
    if not DRAFT:
        text = _OPTIONAL.sub("", text)
    return text


def _page_shell(
    lang_mod: ModuleType, *, title: str, description: str, body: str, path: str, nav: bool = True
) -> str:
    T = lang_mod.UI
    links = "".join(
        f'<li><a href="/{lang_mod.LANG}/{p["slug"]}{"/" if p["slug"] else ""}"'
        f"{' aria-current="page"' if path == p['slug'] else ''}>{html.escape(p['nav'])}</a></li>"
        for p in lang_mod.PAGES
        if p.get("nav")
    )
    robots = '<meta name="robots" content="noindex, nofollow">\n' if DRAFT else ""
    owner = _fill(T["footer_owner"], escape=True).strip()
    if DRAFT:
        owner = mdlite.PLACEHOLDER.sub(lambda m: f"<mark>{m.group(0)}</mark>", owner)
    return f"""<!doctype html>
<html lang="{lang_mod.LANG}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(description)}">
{robots}<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<a class="skip" href="#contenuto">{T["skip"]}</a>
<header class="site-header">
<div class="wrap">
<a class="brand" href="/{lang_mod.LANG}/">Quokka</a>
{f'<nav aria-label="{T["nav_label"]}"><ul>{links}</ul></nav>' if nav else ""}
</div>
</header>
<main id="contenuto" class="wrap">
{body}
</main>
<footer class="site-footer">
<div class="wrap">
<p>{owner}</p>
<p>{T["footer_note"]}{" " + T["footer_draft"] if DRAFT else ""}</p>
</div>
</footer>
</body>
</html>
"""


def _legal_source(page: dict[str, Any]) -> tuple[str, int]:
    """The publishable part of a docs/compliance text, and the file line it starts on."""
    raw = (REPO_DIR / page["md"]).read_text(encoding="utf-8")
    # Drop the draft header (before the first rule) and the reviewer notes (last section).
    header, text = raw.split("\n---\n", 1)
    first_line = header.count("\n") + 3
    text = text.split("\n## Note per il revisore", 1)[0].rstrip().rstrip("-").rstrip()
    for old, new in page.get("subs", {}).items():
        text = text.replace(old, new)
    return _fill(text, escape=False), first_line


def _open_markers(label: str, text: str, first_line: int = 1) -> list[str]:
    """One message per placeholder or review flag still in the text, with its line."""
    found = []
    for number, line in enumerate(text.splitlines(), start=first_line):
        markers = [
            m.group(0)
            for m in mdlite.PLACEHOLDER.finditer(line)
            if not _OPTIONAL.fullmatch(m.group(0))
        ]
        if _REVIEW_FLAG in line:
            markers.append(_REVIEW_FLAG)
        found += [f"{label}:{number}: {marker[:90]}" for marker in markers]
    return found


def release_problems(lang_mod: ModuleType) -> list[str]:
    """Everything that must be settled before the site goes public (empty = ready)."""
    problems: list[str] = []
    for page in lang_mod.PAGES:
        if "md" in page:
            text, first_line = _legal_source(page)
            problems += _open_markers(page["md"], text, first_line)
        label = f"pages_{lang_mod.LANG}.py [{page['slug'] or 'home'}]"
        for key in ("title", "description", "intro", "body"):
            problems += _open_markers(f"{label} {key}", _fill(page.get(key, ""), escape=True))
    for key, value in lang_mod.UI.items():
        if key not in _DRAFT_ONLY_UI:
            problems += _open_markers(
                f"pages_{lang_mod.LANG}.py UI[{key}]", _fill(value, escape=True)
            )
    return problems


def _open_names(problems: list[str]) -> list[str]:
    """Names of the [UPPER_CASE] placeholders among the problems, without repeats."""
    names = []
    for problem in problems:
        found = re.search(r"\[([A-Z][A-Z0-9_]+)\]$", problem)
        if found and found.group(1) not in names:
            names.append(found.group(1))
    return names


def _legal_body(lang_mod: ModuleType, page: dict[str, Any]) -> str:
    """Take the publishable part of a docs/compliance text and lay it out."""
    text, _ = _legal_source(page)
    lines = text.strip().splitlines()
    if lines and lines[0].startswith("# "):
        lines = lines[1:]  # the page's own h1 is written by the template
    text = "\n".join(lines)
    body, toc = mdlite.convert(text)
    toc_html = ""
    if page.get("toc") and toc:
        items = "".join(f'<li><a href="#{i}">{t}</a></li>' for i, t in toc)
        toc_html = (
            f'<nav class="toc" aria-label="{lang_mod.UI["toc_label"]}"><ol>{items}</ol></nav>'
        )
    banner = f'<p class="draft" role="note">{lang_mod.UI["draft_banner"]}</p>' if DRAFT else ""
    return (
        f"<h1>{html.escape(page['title'])}</h1>\n{banner}\n{page.get('intro', '')}\n{toc_html}\n"
        f'<div class="prose">\n{body}\n</div>'
    )


def build_lang(lang: str) -> None:
    lang_mod = _load_lang(lang)
    for page in lang_mod.PAGES:
        if "md" in page:
            body = _legal_body(lang_mod, page)
        else:
            body = _fill(page["body"], escape=True)
        if DRAFT and page.get("draft") and "md" not in page:
            body = body.replace(
                "</h1>", f'</h1>\n<p class="draft" role="note">{lang_mod.UI["draft_banner"]}</p>', 1
            )
        out_dir = _out() / lang / page["slug"]
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "index.html").write_text(
            _page_shell(
                lang_mod,
                title=f"{page['title']} · Quokka" if page["slug"] else "Quokka",
                description=page["description"],
                body=body,
                path=page["slug"],
            ),
            encoding="utf-8",
        )
    not_found = lang_mod.NOT_FOUND
    (_out() / "404.html").write_text(
        _page_shell(
            lang_mod,
            title=not_found["title"] + " · Quokka",
            description=not_found["title"],
            body=not_found["body"],
            path="",
        ),
        encoding="utf-8",
    )


def build_root() -> None:
    first = LANGS[0]
    links = "".join(
        f'<li><a href="/{lang}/" hreflang="{lang}" lang="{lang}">{lang.upper()}</a></li>'
        for lang in LANGS
    )
    robots = '<meta name="robots" content="noindex, nofollow">\n' if DRAFT else ""
    out = _out()
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(
        f"""<!doctype html>
<html lang="{first}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quokka</title>
{robots}<meta http-equiv="refresh" content="0; url=/{first}/">
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<main class="wrap"><h1>Quokka</h1><ul class="plain">{links}</ul></main>
</body>
</html>
""",
        encoding="utf-8",
    )
    (out / "robots.txt").write_text(
        "User-agent: *\nDisallow: /\n" if DRAFT else "User-agent: *\nAllow: /\n", encoding="utf-8"
    )
    if out.resolve() != SITE_DIR.resolve():
        shutil.copytree(SITE_DIR / "assets", out / "assets", dirs_exist_ok=True)


def main(argv: list[str] | None = None, environ: Mapping[str, str] | None = None) -> int:
    global DRAFT, OUT_DIR
    environ = os.environ if environ is None else environ
    parser = argparse.ArgumentParser(description="Build the Quokka static site.")
    parser.add_argument(
        "--release",
        action="store_true",
        help="publication build: owner data from QUOKKA_SITE_* variables, fails while any "
        "placeholder is open; no draft banner, no noindex",
    )
    parser.add_argument(
        "--vercel",
        action="store_true",
        help="--release when Vercel builds the production deployment (VERCEL_ENV=production), "
        "a draft build for previews",
    )
    parser.add_argument(
        "--out", type=Path, help="write the site here instead of next to the sources"
    )
    args = parser.parse_args(argv)
    release = args.release or (args.vercel and environ.get("VERCEL_ENV") == "production")
    OUT_DIR = args.out
    if release:
        values, errors = values_from_environ(environ)
        if errors:
            print("Release blocked: unusable environment variable(s):", file=sys.stderr)
            print("\n".join(errors), file=sys.stderr)
            return 1
        _VALUES.clear()
        _VALUES.update(values)
        problems = [line for lang in LANGS for line in release_problems(_load_lang(lang))]
        if problems:
            print(f"Release blocked: {len(problems)} open marker(s).", file=sys.stderr)
            print("\n".join(problems), file=sys.stderr)
            names = _open_names(problems)
            if names:
                print(
                    f"\nOwner data is set with environment variables {ENV_PREFIX}<NAME>, "
                    f"never in the repository. Open names: {', '.join(names)}.",
                    file=sys.stderr,
                )
            return 1
        DRAFT = False
    for lang in LANGS:
        build_lang(lang)
    build_root()
    print(f"built {', '.join(LANGS)} (draft={DRAFT}) in {_out()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
