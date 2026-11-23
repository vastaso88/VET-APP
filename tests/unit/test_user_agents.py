"""Every program that reads the web names itself honestly (Normativa docs/compliance/20
§20.12, 20/11/2026): never a browser's name ("Mozilla/...") and never Anthropic's ("Claude").
The reading done by the claude program itself is its own and is not set by our code.

Checks the repository's code and, when present on this computer, the local eval tools
(.local/chat_eval, .local/synthetic_users).
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from packages.shared.config.settings import Settings

ROOT = Path(__file__).resolve().parents[2]
FOLDERS = ("scripts", "packages", "apps/api", ".local/chat_eval", ".local/synthetic_users")
FORBIDDEN = re.compile(r"mozilla|claude", re.IGNORECASE)

# a literal User-Agent header, a UA constant, or a *_user_agent setting default
_HEADER = re.compile(r"""["']User-Agent["']\s*:\s*(?:f?["']([^"']+)["'])""", re.IGNORECASE)
_CONSTANT = re.compile(
    r"""^\s*(?:UA\w*|\w*USER_AGENT\w*|\w*_UA)\s*(?::\s*str\s*)?=\s*\(?\s*f?["']([^"']+)["']""",
    re.MULTILINE,
)
_SETTING = re.compile(
    r"""\w*user_agent\s*:\s*str\s*=\s*Field\(\s*default\s*=\s*\(?\s*["']([^"']+)["']""",
    re.IGNORECASE,
)


def _python_files() -> list[Path]:
    files: list[Path] = []
    for folder in FOLDERS:
        base = ROOT / folder
        if base.is_dir():
            files += [p for p in base.rglob("*.py") if ".venv" not in p.parts]
    return files


def user_agents(text: str) -> list[str]:
    return [m.group(1) for rx in (_HEADER, _CONSTANT, _SETTING) for m in rx.finditer(text)]


# Everything of ours that reaches a site names itself "Quokka..." (Normativa 20/11, CLAUDE.md
# "Richieste a siti esterni"): this covers every borrowed name (Googlebot, Chrome, Safari,
# other companies), not only two. Product code included since 23/11/2026.
QUOKKA_FOLDERS = (
    "scripts",
    "packages",
    "apps/api",
    ".local/chat_eval",
    ".local/synthetic_users",
    ".local/cercafonti",
)


def test_everything_that_reaches_a_site_names_itself_quokka() -> None:
    offenders = []
    for folder in QUOKKA_FOLDERS:
        base = ROOT / folder
        if not base.is_dir():
            continue
        for path in base.rglob("*.py"):
            for agent in user_agents(path.read_text("utf-8", errors="replace")):
                if not agent.startswith("Quokka"):
                    offenders.append(f"{path.relative_to(ROOT)}: {agent}")
    assert not offenders, "\n".join(offenders)


def test_the_configurable_names_start_with_quokka_by_default() -> None:
    defaults = {
        name: field.default
        for name, field in Settings.model_fields.items()
        if name.endswith("user_agent")
    }
    assert defaults, "no *_user_agent setting found"
    assert all(str(value).startswith("Quokka") for value in defaults.values()), defaults


# Programs that only reach our own Supabase project or this computer.
OWN_HOSTS_ONLY = {
    "apps/api/routes/admin_users.py",
    "scripts/eval/synthetic_users/client.py",
    "scripts/setup/check_schema.py",
    "scripts/setup/seed_demo_supabase.py",
    "scripts/setup/seed_source_registry.py",
}
_OUTGOING = re.compile(r"urlopen\(|httpx\.(?:Client|AsyncClient|get|post|put|stream)\(")
_NAMES_ITSELF = re.compile(r"User-Agent", re.IGNORECASE)


def test_no_program_reaches_a_site_without_a_name() -> None:
    """A request without a User-Agent leaves as "Python-urllib" or "python-httpx"."""
    offenders = []
    for folder in ("scripts", "packages", "apps/api"):
        for path in (ROOT / folder).rglob("*.py"):
            relative = path.relative_to(ROOT).as_posix()
            text = path.read_text("utf-8", errors="replace")
            if relative in OWN_HOSTS_ONLY or not _OUTGOING.search(text):
                continue
            if not _NAMES_ITSELF.search(text):
                offenders.append(relative)
    assert not offenders, "\n".join(offenders)


def test_no_user_agent_borrows_a_browser_or_anthropic_name() -> None:
    offenders = []
    for path in _python_files():
        text = path.read_text("utf-8", errors="replace")
        for agent in user_agents(text):
            if FORBIDDEN.search(agent):
                offenders.append(f"{path.relative_to(ROOT)}: {agent}")
        if re.search(r"""["'][^"'\n]*Mozilla/\d""", text):
            offenders.append(f"{path.relative_to(ROOT)}: a 'Mozilla/' string")
    assert not offenders, "\n".join(offenders)


@pytest.mark.parametrize(
    ("snippet", "found"),
    [
        ('UA = "Mozilla/5.0 (Windows NT 10.0)"', "Mozilla/5.0 (Windows NT 10.0)"),
        ('headers={"User-Agent": "Claude-User/1.0"}', "Claude-User/1.0"),
        ('USER_AGENT = "VetApp/1.0"', "VetApp/1.0"),
        (
            'overpass_user_agent: str = Field(default="VET-APP/1.0 (+x)")',
            "VET-APP/1.0 (+x)",
        ),
    ],
)
def test_the_scanner_finds_user_agents(snippet: str, found: str) -> None:
    assert found in user_agents(snippet)
