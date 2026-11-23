"""Check that an APK really contains the expected strings in its compiled Dart code.

Usage:
    python -m scripts.collaudo.apk_strings <app.apk> --expect "text" [--expect "text" ...]
        [--not-sha256 <hash of the previous libapp.so>] [--file strings.txt]

Exit code 0 only if every expected string is in every ``lib/<abi>/libapp.so`` of the APK
(and, with ``--not-sha256``, no ``libapp.so`` equals the old one). Anything else exits 1,
so a stale package (old Gradle build cache, wrong flavor or ABI) is caught before install.
Prints SHA-256 of each ``libapp.so``; never prints the APK's other content.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import zipfile
from pathlib import Path


def _encodings(text: str) -> list[bytes]:
    """Dart AOT stores strings as one-byte (Latin-1/ASCII) or UTF-16; try all forms."""
    forms = [text.encode("utf-8"), text.encode("utf-16-le")]
    try:
        forms.append(text.encode("latin-1"))
    except UnicodeEncodeError:
        pass
    return forms


def check_apk(apk: Path, expected: list[str], old_sha256: set[str]) -> list[str]:
    """Return a list of problems (empty = APK is good)."""
    problems: list[str] = []
    with zipfile.ZipFile(apk) as z:
        libs = sorted(n for n in z.namelist() if n.startswith("lib/") and n.endswith("/libapp.so"))
        if not libs:
            return [f"{apk.name}: no lib/<abi>/libapp.so inside"]
        for name in libs:
            data = z.read(name)
            digest = hashlib.sha256(data).hexdigest()
            print(f"{name}  sha256={digest}  {len(data)} bytes")
            if digest in old_sha256:
                problems.append(f"{name}: identical to the old libapp.so")
            for text in expected:
                if not any(form in data for form in _encodings(text)):
                    problems.append(f"{name}: string not found: {text!r}")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("apk", type=Path)
    parser.add_argument("--expect", action="append", default=[], help="string that must be present")
    parser.add_argument("--file", type=Path, help="UTF-8 file, one expected string per line")
    parser.add_argument("--not-sha256", action="append", default=[], dest="old")
    parser.add_argument(
        "--commit",
        type=Path,
        help="COMMIT.txt of the folder the APK was built from; printed in the result",
    )
    args = parser.parse_args(argv)
    if args.commit:
        commit = args.commit.read_text(encoding="utf-8").strip() if args.commit.is_file() else "?"
        print(f"built from commit: {commit or '?'}")

    expected: list[str] = list(args.expect)
    if args.file:
        expected += [
            line for line in args.file.read_text(encoding="utf-8").splitlines() if line.strip()
        ]
    if not expected and not args.old:
        print("nothing to check: pass --expect, --file or --not-sha256", file=sys.stderr)
        return 1
    problems = check_apk(args.apk, expected, {h.lower() for h in args.old})
    for problem in problems:
        print("FAIL", problem, file=sys.stderr)
    print("OK" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
