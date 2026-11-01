"""Tiny Markdown-to-HTML converter, just enough for docs/compliance/<lang>/*.md.

Supports headings, paragraphs, bold, inline code, links, bullet/numbered lists,
tables, blockquotes and horizontal rules. Everything is HTML-escaped first, so
no markup from the source files can reach the page. Placeholders such as
``[TITOLARE]`` or ``[da verificare: ...]`` are wrapped in ``<mark>`` so they are
impossible to miss on a draft page.
"""

from __future__ import annotations

import html
import re

_PLACEHOLDER = re.compile(r"\[(?:[A-Z][A-Z0-9_]+|(?:da|togliere)\s[^\]]*)\]")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
_BOLD = re.compile(r"\*\*(.+?)\*\*")
_CODE = re.compile(r"`([^`]+)`")


def slug(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text).lower()
    text = re.sub(r"[^a-z0-9àèéìòù]+", "-", text).strip("-")
    return text or "sezione"


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = _CODE.sub(r"<code>\1</code>", text)
    text = _LINK.sub(lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>', text)
    text = _BOLD.sub(r"<strong>\1</strong>", text)
    return _PLACEHOLDER.sub(lambda m: f"<mark>{m.group(0)}</mark>", text)


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def convert(source: str) -> tuple[str, list[tuple[str, str]]]:
    """Return ``(html, headings)`` where headings is a list of ``(id, text)`` for h2."""
    lines = source.splitlines()
    out: list[str] = []
    toc: list[tuple[str, str]] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
        elif stripped == "---":
            out.append("<hr>")
            i += 1
        elif stripped.startswith("#"):
            level = len(stripped) - len(stripped.lstrip("#"))
            text = stripped[level:].strip()
            ident = slug(text)
            out.append(f'<h{level} id="{ident}">{inline(text)}</h{level}>')
            if level == 2:
                toc.append((ident, inline(text)))
            i += 1
        elif stripped.startswith("|"):
            block = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                block.append(lines[i])
                i += 1
            head, rows = _cells(block[0]), [_cells(r) for r in block[2:]]
            for row in rows:
                if len(row) != len(head):
                    raise ValueError(
                        f"table row has {len(row)} cells, expected {len(head)}: {row[:2]}"
                    )
            th = "".join(f'<th scope="col">{inline(c)}</th>' for c in head)
            body = "".join(
                "<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>" for row in rows
            )
            out.append(
                '<div class="table-wrap" tabindex="0" role="region" aria-label="Tabella">'
                f"<table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table></div>"
            )
        elif re.match(r"^(-|\d+\.)\s", stripped):
            ordered = stripped[0].isdigit()
            items = []
            while i < len(lines) and re.match(r"^(-|\d+\.)\s", lines[i].strip()):
                items.append(re.sub(r"^(-|\d+\.)\s+", "", lines[i].strip()))
                i += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(t)}</li>" for t in items) + f"</{tag}>")
        elif stripped.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip().lstrip(">").strip())
                i += 1
            out.append(f"<blockquote><p>{inline(' '.join(quote))}</p></blockquote>")
        else:
            para = []
            while (
                i < len(lines)
                and lines[i].strip()
                and not re.match(r"^(#|\||>|---$|-\s|\d+\.\s)", lines[i].strip())
            ):
                para.append(lines[i].strip())
                i += 1
            out.append(f"<p>{inline(' '.join(para))}</p>")
    return "\n".join(out), toc
