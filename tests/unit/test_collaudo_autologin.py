"""The collaudo automatic sign-in can only be in collaudo builds (agreed with the Auth session,
22/11/2026; the repository is public)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "apps" / "mobile_app" / "lib"
ENTRY = LIB / "main_collaudo.dart"
GUARD = LIB / "collaudo" / "auto_login_guard.dart"

# Where a normal build, its distribution or its instructions live: none may name the
# collaudo entry point or its build values. scripts/collaudo is the collaudo itself.
NORMAL_BUILD_PLACES = (
    ".github",
    "scripts",
    "docs/runbooks",
    "apps/mobile_app/android",
    "apps/mobile_app/ios",
    "apps/mobile_app/web",
)
TEXT_SUFFIXES = {
    ".yml",
    ".yaml",
    ".py",
    ".ps1",
    ".sh",
    ".md",
    ".gradle",
    ".kts",
    ".json",
    ".xml",
    ".html",
    ".js",
    ".txt",
    ".properties",
}


def _dart_files() -> list[Path]:
    return [p for p in LIB.rglob("*.dart") if p.is_file()]


def test_the_normal_entry_point_never_reaches_the_collaudo_code() -> None:
    main = (LIB / "main.dart").read_text(encoding="utf-8")
    assert "collaudo" not in main.lower()
    for path in _dart_files():
        if path in (ENTRY, GUARD):
            continue
        text = path.read_text(encoding="utf-8")
        assert "main_collaudo" not in text, path
        assert "collaudo/auto_login_guard" not in text, path


def test_collaudo_build_values_are_read_only_by_the_collaudo_entry_point() -> None:
    for path in _dart_files():
        if path != ENTRY:
            assert "COLLAUDO_" not in path.read_text(encoding="utf-8"), path


def test_no_default_account_is_written_in_the_entry_point() -> None:
    text = ENTRY.read_text(encoding="utf-8")
    reads = re.findall(r"String\.fromEnvironment\(\s*'COLLAUDO_[A-Z_]+'([^)]*)\)", text)
    assert len(reads) == 3
    assert all("defaultValue" not in rest for rest in reads)
    assert "@example.com'" not in text and "password:" not in text.replace(
        "password: _password", ""
    )


def test_the_guard_allows_only_the_twin_and_refuses_production() -> None:
    guard = GUARD.read_text(encoding="utf-8")
    for ref in ("ywbuzgwbkrmkukkpysbz", "dkzzcoastheciitvkiuo", "noulpaaonqjvprfddipn"):
        assert f"'{ref}'" in guard
    assert "'$ref.supabase.co'" in guard
    assert "@example.com" in guard and "'production'" in guard


def test_normal_builds_and_their_distribution_never_name_the_collaudo_entry_point() -> None:
    offenders = []
    for place in NORMAL_BUILD_PLACES:
        base = ROOT / place
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
                continue
            if "collaudo" in path.relative_to(ROOT).parts:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if "main_collaudo" in text or "COLLAUDO_" in text:
                offenders.append(str(path.relative_to(ROOT)))
    makefile = ROOT / "Makefile"
    if makefile.is_file() and "main_collaudo" in makefile.read_text(encoding="utf-8"):
        offenders.append("Makefile")
    assert offenders == []


def test_the_test_accounts_file_stays_out_of_the_repository() -> None:
    ignored = (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert ".local/" in [line.strip() for line in ignored]
