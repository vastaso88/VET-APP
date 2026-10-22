#!/usr/bin/env python3
"""Guards for the app's translations.

1. Hard-coded Italian: finds Italian user-facing strings written directly in
   the Dart code (outside ``lib/l10n``). Heuristic: a string literal that
   contains an accented Italian letter or that is made of frequent Italian
   words. Justified leftovers live in ``scripts/i18n/allowlist.txt``.
2. Missing keys: every ``lib/l10n/app_xx.arb`` must define all the keys of the
   template ``app_it.arb`` (same placeholders). Extra keys are reported too.

Usage (from the repo root)::

    python scripts/i18n/check_i18n.py            # both checks, exit 1 on problems
    python scripts/i18n/check_i18n.py --arb-only # only the ARB comparison
    python scripts/i18n/check_i18n.py --hardcoded-only
    python scripts/i18n/check_i18n.py --list-missing de   # keys to translate

See docs/i18n/README.md.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps" / "mobile_app"
LIB = APP / "lib"
L10N = LIB / "l10n"
TEMPLATE = L10N / "app_it.arb"
ALLOWLIST = Path(__file__).with_name("allowlist.txt")

ACCENTED = re.compile(r"[àèéìòùÀÈÉÌÒÙ]")

# Frequent Italian words that are not also common in English/identifiers.
ITALIAN_WORDS = {
    "il",
    "lo",
    "la",
    "gli",
    "le",
    "un",
    "una",
    "uno",
    "di",
    "del",
    "della",
    "dei",
    "delle",
    "dello",
    "degli",
    "che",
    "per",
    "con",
    "non",
    "nel",
    "nella",
    "nei",
    "nelle",
    "sono",
    "hai",
    "ho",
    "ha",
    "tuo",
    "tua",
    "tuoi",
    "tue",
    "mio",
    "mia",
    "questo",
    "questa",
    "questi",
    "queste",
    "più",
    "già",
    "ancora",
    "anche",
    "come",
    "quando",
    "dove",
    "puoi",
    "vuoi",
    "sei",
    "siamo",
    "stai",
    "devi",
    "prova",
    "riprova",
    "salva",
    "annulla",
    "elimina",
    "aggiungi",
    "modifica",
    "chiudi",
    "conferma",
    "nessun",
    "nessuna",
    "tutti",
    "tutte",
    "oggi",
    "ieri",
    "domani",
    "cane",
    "gatto",
    "animale",
    "animali",
    "passeggiata",
    "promemoria",
    "impostazioni",
    "scegli",
    "inserisci",
    "seleziona",
    "errore",
    "caricamento",
    "attendi",
    "accedi",
    "registrati",
    "password",
    "dimenticata",
    "continua",
    "indietro",
    "avanti",
    "salta",
    "fatto",
    "sì",
    "giorno",
    "giorni",
    "mese",
    "mesi",
    "anno",
    "anni",
    "ora",
    "ore",
    "minuti",
    "secondi",
}
STRONG_WORDS = {
    "annulla",
    "salva",
    "elimina",
    "aggiungi",
    "modifica",
    "chiudi",
    "conferma",
    "riprova",
    "nessun",
    "nessuna",
    "impostazioni",
    "promemoria",
    "passeggiata",
    "caricamento",
    "errore",
    "scegli",
    "inserisci",
    "seleziona",
    "accedi",
    "registrati",
    "continua",
    "indietro",
}

STRING_LITERAL = re.compile(
    r"""r?(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""",
)
SKIP_LINE_PREFIX = ("import ", "export ", "part ", "library ", "//", "///", "*", "/*")
SKIP_CONTEXT = re.compile(
    r"(debugPrint|print\(|log\(|developer\.log|Exception\(|StateError\(|ArgumentError|"
    r"UnimplementedError|assert\(|RegExp\(|@visibleForTesting|code:\s*'|key:\s*Key|"
    r"ValueKey|MethodChannel|SharedPreferences|_storageKey|Uri\.|http|\.json|\.dart)",
)


def load_allowlist() -> tuple[list[str], list[tuple[str, str]]]:
    """Return (whole-file globs, (file glob, substring) pairs)."""
    files: list[str] = []
    lines: list[tuple[str, str]] = []
    if not ALLOWLIST.exists():
        return files, lines
    for raw in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        entry = raw.split("#", 1)[0].strip()
        if not entry:
            continue
        if "::" in entry:
            glob, needle = entry.split("::", 1)
            lines.append((glob.strip(), needle.strip()))
        else:
            files.append(entry)
    return files, lines


def italian_score(text: str) -> bool:
    if ACCENTED.search(text):
        return True
    words = re.findall(r"[A-Za-zÀ-ÿ']+", text.lower())
    if not words:
        return False
    hits = [w for w in words if w in ITALIAN_WORDS]
    if any(w in STRONG_WORDS for w in hits):
        return True
    return len(hits) >= 2


UI_ARGUMENT = re.compile(
    r"(?:\bText\(\s*|\bTextSpan\(\s*text:\s*|(?:title|subtitle|label|labelText|hintText|helperText|"
    r"errorText|tooltip|semanticsLabel|semanticLabel|message|buttonText|actionLabel|"
    r"placeholder|description)\s*:\s*)(?:const\s+Text\(\s*)?"
    r"""(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""",
)


def looks_like_ui_text(text: str) -> bool:
    """Human-readable text in UI arguments, regardless of language/casing."""
    technical = {
        "VetApp",
        "VET APP",
        "OSM",
        "OpenStreetMap",
        "PDF",
        "GPS",
        "km",
        "m",
        "kg",
        "g",
        "cm",
        "ml",
        "L",
        "min",
        "s",
        "°C",
        "°F",
    }
    if text in technical:
        return False
    without_variables = re.sub(r"\$\{[^}]*\}|\$\w+", "", text)
    return bool(re.search(r"[A-Za-zÀ-ÿ]{2,}", without_variables))


def strip_comment(line: str) -> str:
    """Drop a trailing // comment (naive, but good enough outside strings)."""
    in_single = in_double = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_double and (i == 0 or line[i - 1] != "\\"):
            in_single = not in_single
        elif ch == '"' and not in_single and (i == 0 or line[i - 1] != "\\"):
            in_double = not in_double
        elif ch == "/" and not in_single and not in_double and line[i : i + 2] == "//":
            return line[:i]
    return line


def find_hardcoded() -> list[tuple[str, int, str]]:
    file_globs, line_rules = load_allowlist()
    found: list[tuple[str, int, str]] = []
    for path in sorted(LIB.rglob("*.dart")):
        rel = path.relative_to(APP).as_posix()
        if rel.startswith("lib/l10n/"):
            continue
        if any(fnmatch.fnmatch(rel, g) for g in file_globs):
            continue
        in_block = False
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        code_lines = [""] * len(raw_lines)
        for number, raw in enumerate(raw_lines, 1):
            stripped = raw.strip()
            if in_block:
                if "*/" in stripped:
                    in_block = False
                continue
            if stripped.startswith("/*"):
                in_block = "*/" not in stripped
                continue
            if stripped.startswith(SKIP_LINE_PREFIX):
                continue
            line = strip_comment(raw)
            if SKIP_CONTEXT.search(line):
                continue
            code_lines[number - 1] = line
            ui_literals = {
                (m.group(1) if m.group(1) is not None else m.group(2))
                for m in UI_ARGUMENT.finditer(line)
            }
            for match in STRING_LITERAL.finditer(line):
                text = match.group(1) if match.group(1) is not None else match.group(2)
                if not text or len(text) < 2:
                    continue
                if not (italian_score(text) or (text in ui_literals and looks_like_ui_text(text))):
                    continue
                if any(fnmatch.fnmatch(rel, g) and needle in raw for g, needle in line_rules):
                    continue
                found.append((rel, number, text))
        # Also match widgets whose literal begins on the following line.
        code = "\n".join(code_lines)
        for match in UI_ARGUMENT.finditer(code):
            text = match.group(1) if match.group(1) is not None else match.group(2)
            if not looks_like_ui_text(text):
                continue
            number = code.count("\n", 0, match.start()) + 1
            raw = match.group(0)
            if any(fnmatch.fnmatch(rel, g) and needle in raw for g, needle in line_rules):
                continue
            entry = (rel, number, text)
            if entry not in found:
                found.append(entry)
    return found


def arb_placeholders(message: str) -> set[str]:
    # A plural branch such as =1{day} contains text, not a {day} variable.
    message = re.sub(
        r"(?<!\w)(?:=\d+|zero|one|two|few|many|other)\s*\{([^{}]*)\}",
        lambda match: match.group(1),
        message,
    )
    return set(re.findall(r"\{(\w+)(?:,|\})", message))


def load_arb(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@")}


def compare_arbs() -> tuple[dict[str, list[str]], dict[str, list[str]], dict[str, list[str]]]:
    template = load_arb(TEMPLATE)
    missing: dict[str, list[str]] = {}
    extra: dict[str, list[str]] = {}
    mismatched: dict[str, list[str]] = {}
    invalid_source = [
        key for key, value in template.items() if not isinstance(value, str) or not value.strip()
    ]
    if invalid_source:
        missing["it"] = []
        extra["it"] = []
        mismatched["it"] = invalid_source
    for language in ("en", "es", "fr"):
        if not (L10N / f"app_{language}.arb").exists():
            missing[language] = list(template)
            extra[language] = []
            mismatched[language] = []
    for path in sorted(L10N.glob("app_*.arb")):
        if path == TEMPLATE:
            continue
        lang = path.stem.removeprefix("app_")
        other = load_arb(path)
        missing[lang] = [k for k in template if k not in other]
        extra[lang] = [k for k in other if k not in template]
        mismatched[lang] = [
            k
            for k in template
            if k in other
            and (
                not isinstance(other[k], str)
                or not other[k].strip()
                or arb_placeholders(template[k]) != arb_placeholders(other[k])
            )
        ]
    return missing, extra, mismatched


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("--arb-only", action="store_true")
    parser.add_argument("--hardcoded-only", action="store_true")
    parser.add_argument("--list-missing", metavar="LANG", help="print the keys LANG still lacks")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]

    if args.list_missing:
        template = load_arb(TEMPLATE)
        path = L10N / f"app_{args.list_missing}.arb"
        have = load_arb(path) if path.exists() else {}
        for key, text in template.items():
            if key not in have:
                print(f"{key}\t{text}")
        return 0

    problems = 0
    if not args.arb_only:
        found = find_hardcoded()
        if found:
            problems += len(found)
            print(f"Hard-coded UI strings outside lib/l10n: {len(found)}")
            for rel, number, text in found:
                print(f"  {rel}:{number}: {text[:90]!r}")
            print("  -> move them to app_it.arb, or justify them in scripts/i18n/allowlist.txt")
        else:
            print("No hard-coded UI strings found.")
    if not args.hardcoded_only:
        missing, extra, mismatched = compare_arbs()
        if not missing:
            print("Only the template ARB exists: nothing to compare.")
        for lang in missing:
            if missing[lang]:
                problems += len(missing[lang])
                print(f"app_{lang}.arb is missing {len(missing[lang])} keys:")
                for key in missing[lang]:
                    print(f"  {key}")
            if mismatched[lang]:
                problems += len(mismatched[lang])
                print(
                    f"app_{lang}.arb has empty/invalid values or different placeholders for: "
                    + ", ".join(mismatched[lang])
                )
            if extra[lang]:
                problems += len(extra[lang])
                print(f"app_{lang}.arb has {len(extra[lang])} keys not in the template:")
                for key in extra[lang]:
                    print(f"  {key}")
            if not missing[lang] and not mismatched[lang] and not extra[lang]:
                print(f"app_{lang}.arb: complete.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
