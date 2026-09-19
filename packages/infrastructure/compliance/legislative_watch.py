"""Weekly watch over official AI/privacy legislative sources.

Detects changes via a plain text diff against the last saved snapshot and
writes a dated report for a human to review. It never modifies application
code or behaviour on its own — interpreting whether a legislative change
requires product changes is a decision left to a person.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import re
import subprocess
import textwrap
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from urllib import request
from urllib.error import URLError

_SCRIPT_OR_STYLE_RE = re.compile(r"<(script|style)\b[^>]*>.*?</\1>", re.IGNORECASE | re.DOTALL)
_TAG_RE = re.compile(r"<[^>]+>")
_WHITESPACE_RE = re.compile(r"\s+")


def extract_visible_text(html: str) -> str:
    """Reduce a fetched page to its visible text, re-wrapped into fixed-width lines.

    Pages built on a CMS (script nonces, per-request auth tokens, churning
    element ids, inconsistent blank-line placement between requests) change
    on every fetch even when nothing editorial changed. Diffing raw HTML —
    or even text that keeps the original line breaks — would report that
    churn as a "legislative change" on every run. Collapsing everything to
    single-spaced text and re-wrapping it ourselves removes the original
    (unstable) line structure entirely, so only real wording changes remain.
    """
    without_script_or_style = _SCRIPT_OR_STYLE_RE.sub(" ", html)
    text_only = _TAG_RE.sub(" ", without_script_or_style)
    flat_text = _WHITESPACE_RE.sub(" ", text_only).strip()
    return "\n".join(textwrap.wrap(flat_text, width=100))

REPO_ROOT = Path(__file__).resolve().parents[3]
SNAPSHOTS_DIR = REPO_ROOT / "docs" / "compliance" / "legislative-watch" / "snapshots"
REPORTS_DIR = REPO_ROOT / "docs" / "compliance" / "legislative-watch" / "reports"


@dataclass(frozen=True)
class LegislativeSource:
    slug: str
    name: str
    url: str


SOURCES: list[LegislativeSource] = [
    LegislativeSource(
        slug="eu-ai-act-policy",
        name="European Commission - AI Act regulatory framework",
        url="https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai",
    ),
    LegislativeSource(
        slug="garante-privacy-ia",
        name="Garante Privacy - Intelligenza Artificiale",
        url="https://www.garanteprivacy.it/temi/intelligenza-artificiale",
    ),
]


@dataclass(frozen=True)
class ChangeReport:
    source: LegislativeSource
    diff: str
    fetched_at: datetime


def fetch_source(url: str, *, timeout: int = 30) -> str:
    req = request.Request(url, headers={"User-Agent": "VetApp-LegislativeWatch/1.0"})
    with request.urlopen(req, timeout=timeout) as response:  # noqa: S310 - fixed https sources
        body: bytes = response.read()
        return body.decode("utf-8", errors="replace")


def compute_hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def _snapshot_path(source: LegislativeSource) -> Path:
    return SNAPSHOTS_DIR / f"{source.slug}.txt"


def load_last_snapshot(source: LegislativeSource) -> str | None:
    path = _snapshot_path(source)
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def save_snapshot(source: LegislativeSource, content: str) -> None:
    SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)
    _snapshot_path(source).write_text(content, encoding="utf-8")


def run(sources: list[LegislativeSource] | None = None) -> list[ChangeReport]:
    """Fetch each source and return a ChangeReport for every one that changed.

    A source seen for the first time only establishes the baseline snapshot;
    it is not reported as a change since there is nothing to diff against.
    """
    changes: list[ChangeReport] = []
    now = datetime.now(UTC)
    for source in sources or SOURCES:
        try:
            raw_content = fetch_source(source.url)
        except URLError as exc:
            print(f"[legislative-watch] failed to fetch {source.name}: {exc}")
            continue
        content = extract_visible_text(raw_content)

        previous = load_last_snapshot(source)
        if previous is None:
            save_snapshot(source, content)
            print(f"[legislative-watch] baseline snapshot saved for {source.name}")
            continue

        if compute_hash(previous) == compute_hash(content):
            continue

        diff = "\n".join(
            difflib.unified_diff(
                previous.splitlines(),
                content.splitlines(),
                fromfile=f"{source.slug} (previous)",
                tofile=f"{source.slug} (current)",
                lineterm="",
            )
        )
        save_snapshot(source, content)
        changes.append(ChangeReport(source=source, diff=diff, fetched_at=now))
    return changes


def write_report(change: ChangeReport) -> Path:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    date_label = change.fetched_at.strftime("%Y-%m-%d")
    path = REPORTS_DIR / f"{date_label}-{change.source.slug}.md"
    path.write_text(
        f"# Legislative watch: {change.source.name}\n\n"
        "Snapshot automatico — richiede revisione legale umana. "
        "Nessuna modifica al codice viene applicata automaticamente.\n\n"
        f"Fonte: {change.source.url}\n"
        f"Rilevato: {change.fetched_at.isoformat()}\n\n"
        f"```diff\n{change.diff}\n```\n",
        encoding="utf-8",
    )
    return path


def open_issue(report_path: Path, change: ChangeReport) -> None:
    title = f"Legislative watch: {change.source.name} è cambiato"
    try:
        subprocess.run(
            ["gh", "issue", "create", "--title", title, "--body-file", str(report_path)],
            check=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError) as exc:
        print(f"[legislative-watch] could not open GitHub issue: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Monitor official AI/privacy legislative sources for changes."
    )
    parser.add_argument(
        "--no-issue",
        action="store_true",
        help="Write the report file but skip opening a GitHub issue.",
    )
    args = parser.parse_args()

    changes = run()
    if not changes:
        print("[legislative-watch] no changes detected.")
        return

    for change in changes:
        report_path = write_report(change)
        print(f"[legislative-watch] report written: {report_path}")
        if not args.no_issue:
            open_issue(report_path, change)


if __name__ == "__main__":
    main()
