"""Shared translation glossary: check it, render it, push it to DeepL.

The glossary lives in docs/i18n/glossary.json (Italian is the source). It names
the veterinary terms and the features of the app (Monitoraggio, Storico,
Corporatura, Vicino a me, Promemoria...) once per language, so that the
automatic drafts, the human translators and the checks all use the same words.

    python scripts/i18n/glossary.py check [--soft]   # blocking: feature names in the ARB catalogs
    python scripts/i18n/glossary.py render [--check] # docs/i18n/GLOSSARIO_E_STILE.md table
    python scripts/i18n/glossary.py deepl-sync [--github-env FILE]  # needs DEEPL_API_KEY

`check` fails when a catalog label listed under a term's `keys` differs from
the glossary. `--soft` also lists long texts where the Italian source uses a
glossary term and the translation uses neither the term nor an alias: those
are hints for the reviewer, never a failure.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
GLOSSARY = Path("docs/i18n/glossary.json")
ARB = Path("apps/mobile_app/lib/l10n")
DOC = Path("docs/i18n/GLOSSARIO_E_STILE.md")
LANGUAGES = ("en", "es", "de", "fr")
START = "<!-- glossary:start -->"
END = "<!-- glossary:end -->"
# DeepL glossaries use the base language codes.
DEEPL_BASE = {"en": "EN", "es": "ES", "de": "DE", "fr": "FR"}


def load(root: Path = ROOT) -> list[dict]:
    terms: list[dict] = json.loads((root / GLOSSARY).read_text(encoding="utf-8"))["terms"]
    return terms


def _plain(text: str) -> str:
    """Compare without caring about non-breaking spaces or case."""
    return text.replace(" ", " ").replace(" ", " ").strip()


def load_arb(root: Path, lang: str) -> dict[str, str]:
    data = json.loads((root / ARB / f"app_{lang}.arb").read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}


def strict_problems(root: Path = ROOT) -> list[str]:
    problems: list[str] = []
    terms = load(root)
    catalogs = {lang: load_arb(root, lang) for lang in ("it", *LANGUAGES)}
    for term in terms:
        for lang in ("it", *LANGUAGES):
            if not term.get(lang, "").strip():
                problems.append(f"{term['id']}: missing {lang} in the glossary")
        for key in term.get("keys", []):
            for lang in ("it", *LANGUAGES):
                value = catalogs[lang].get(key)
                if value is None:
                    problems.append(f"{term['id']}: key {key} is missing from app_{lang}.arb")
                elif _plain(value) != _plain(term[lang]):
                    problems.append(
                        f"{term['id']}: {key} in {lang} is «{value}», "
                        f"the glossary says «{term[lang]}»"
                    )
    return problems


def _stem(word: str, cut: int) -> str:
    """Drop the inflection ending of a long term, so a plural or a feminine form still matches."""
    plain = _plain(word).lower()
    return plain[:-cut] if len(plain) >= 7 else plain


def soft_issues(it_text: str, lang: str, text: str, terms: list[dict] | None = None) -> list[str]:
    """Glossary terms the Italian source uses that the translation does not."""
    found: list[str] = []
    lowered_it = _plain(it_text).lower()
    lowered = _plain(text).lower()
    for term in terms if terms is not None else load():
        # Feature names must appear as written; medical words may be plural (referto/referti).
        tail = r"\w{0,2}" if term.get("kind") == "medical" else r"(?!\w)"
        if not re.search(rf"(?<!\w){re.escape(term['it'].lower())}{tail}", lowered_it):
            continue
        accepted = [term[lang], *term.get("aliases", {}).get(lang, [])]
        # A stem match is enough: "Impfung" accepts "Impfungen", "vétérinaire" "vétérinaires".
        if not any(_stem(word, 2) in lowered for word in accepted):
            found.append(f"«{term['it']}» should be «{term[lang]}» in {lang}")
    return found


def soft_problems(root: Path = ROOT) -> list[str]:
    terms = load(root)
    strict_keys = {key for term in terms for key in term.get("keys", [])}
    it = load_arb(root, "it")
    out: list[str] = []
    for lang in LANGUAGES:
        catalog = load_arb(root, lang)
        for key, source in it.items():
            if key in strict_keys or key not in catalog:
                continue
            out.extend(
                f"{key} ({lang}): {issue}"
                for issue in soft_issues(source, lang, catalog[key], terms)
            )
    return out


def render(root: Path = ROOT) -> str:
    rows = [
        "| Italiano | English | Español | Deutsch | Français | Note |",
        "|---|---|---|---|---|---|",
    ]
    for term in load(root):
        note = term.get("note", "").replace("|", "/").replace("\n", " ")
        cells = [term["it"], *(term[lang] for lang in LANGUAGES)]
        rows.append("| " + " | ".join(cells) + f" | {note} |")
    return "\n".join(rows)


def render_into_doc(root: Path = ROOT, check: bool = False) -> bool:
    path = root / DOC
    text = path.read_text(encoding="utf-8")
    if START not in text or END not in text:
        raise SystemExit(f"{DOC}: markers {START} / {END} not found")
    head, rest = text.split(START, 1)
    _, tail = rest.split(END, 1)
    updated = f"{head}{START}\n{render(root)}\n{END}{tail}"
    if updated == text:
        return True
    if not check:
        path.write_text(updated, encoding="utf-8", newline="")
    return not check


def deepl_sync(github_env: Path | None = None) -> int:
    """Create one IT->xx DeepL glossary per language (replacing ours) and print its id.

    The ids go to $GITHUB_ENV as DEEPL_GLOSSARY_<LANG>, which auto_translate.py reads.
    A plan that refuses glossaries (the free plan allows very few) is not an error:
    the drafts are then produced without one and the soft check still flags the terms.
    """
    key = os.environ.get("DEEPL_API_KEY", "")
    if not key:
        print("DEEPL_API_KEY is not set: nothing to synchronise.")
        return 1
    endpoint = "https://api-free.deepl.com" if key.endswith(":fx") else "https://api.deepl.com"
    headers = {"Authorization": "DeepL-Auth-Key " + key, "Content-Type": "application/json"}

    def call(method: str, path: str, body: dict | None = None) -> object:
        request = Request(
            endpoint + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers=headers,
            method=method,
        )
        with urlopen(request, timeout=45) as response:
            raw = response.read()
        return json.loads(raw) if raw else {}

    try:
        existing = call("GET", "/v2/glossaries")
        glossaries = existing.get("glossaries", []) if isinstance(existing, dict) else []
    except (HTTPError, URLError) as error:
        print(f"Could not list DeepL glossaries ({getattr(error, 'code', 'network')}).")
        return 1
    terms = load()
    lines: list[str] = []
    for lang in LANGUAGES:
        name = f"vetapp-it-{lang}"
        for old in [g for g in glossaries if g.get("name") == name]:
            try:
                call("DELETE", f"/v2/glossaries/{old['glossary_id']}")
            except (HTTPError, URLError):
                print(f"Could not delete the previous glossary {name}.")
        entries = "\n".join(f"{t['it']}\t{t[lang]}" for t in terms)
        try:
            created = call(
                "POST",
                "/v2/glossaries",
                {
                    "name": name,
                    "source_lang": "IT",
                    "target_lang": DEEPL_BASE[lang],
                    "entries": entries,
                    "entries_format": "tsv",
                },
            )
        except (HTTPError, URLError) as error:
            code = getattr(error, "code", "network")
            print(f"Glossary {name} refused ({code}): drafts go without it.")
            continue
        assert isinstance(created, dict)
        lines.append(f"DEEPL_GLOSSARY_{lang.upper()}={created['glossary_id']}")
        print(f"Glossary {name}: {len(terms)} terms.")
    if github_env is not None and lines:
        with github_env.open("a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("mode", choices=("check", "render", "deepl-sync"))
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--soft", action="store_true", help="check: also list non-blocking hints")
    parser.add_argument("--check", action="store_true", help="render: fail if the doc is outdated")
    parser.add_argument("--github-env", type=Path, help="deepl-sync: file to append the ids to")
    args = parser.parse_args()
    if args.mode == "check":
        problems = strict_problems(args.root)
        for problem in problems:
            print("GLOSSARY:", problem)
        if args.soft:
            hints = soft_problems(args.root)
            for hint in hints:
                print("hint:", hint)
            print(f"{len(hints)} non-blocking hint(s).")
        if not problems:
            print("Glossary: all feature names match.")
        return int(bool(problems))
    if args.mode == "render":
        ok = render_into_doc(args.root, check=args.check)
        if not ok:
            print(f"{DOC} is outdated: run `python scripts/i18n/glossary.py render`.")
        return int(not ok)
    return deepl_sync(args.github_env)


if __name__ == "__main__":
    sys.exit(main())
