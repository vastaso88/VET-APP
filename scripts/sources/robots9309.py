"""Lettore di `robots.txt` secondo la RFC 9309 (Normativa, doc 20 §23.1 n. 1 e §22.10).

Il lettore standard di Python applica la PRIMA regola che combacia; la RFC dice un'altra cosa:
vince la regola più specifica, cioè il percorso più lungo; a parità vince `Allow`. Così
`Disallow: /` seguito da `Allow: /data/api/` permette l'API e vieta le pagine (caso data.gov.au).

Un file ambiguo o illeggibile vuol dire stop (`ambiguous`): una regola prima di qualsiasi
`User-agent`, un file che è una pagina HTML, byte che non si leggono come testo.
"""

from __future__ import annotations

import re
import urllib.parse
from dataclasses import dataclass, field

_HTML = re.compile(r"<html|<!doctype|<head|<body", re.IGNORECASE)


@dataclass
class _Group:
    agents: list[str] = field(default_factory=list)
    rules: list[tuple[bool, str]] = field(default_factory=list)  # (allow, percorso)


def _normalize(path: str) -> str:
    """Percorso (con query) confrontabile: i caratteri codificati valgono come se scritti."""
    return urllib.parse.unquote(path)


def _pattern_regex(pattern: str) -> re.Pattern[str]:
    anchored = pattern.endswith("$")
    body = pattern[:-1] if anchored else pattern
    regex = ".*".join(re.escape(part) for part in body.split("*"))
    return re.compile(regex + ("$" if anchored else ""))


class Robots9309:
    """`can_fetch(agente, url)` come `RobotFileParser`, ma con le regole della RFC 9309."""

    def __init__(self, text: str = "") -> None:
        self.ambiguous = False
        self.reason = ""
        self._groups: list[_Group] = []
        self._parse(text)

    def _fail(self, reason: str) -> None:
        if not self.ambiguous:
            self.ambiguous, self.reason = True, reason

    def _parse(self, text: str) -> None:
        if "�" in text:
            self._fail("byte che non si leggono come testo")
        if _HTML.search(text[:600]):
            self._fail("il file è una pagina HTML")
        group: _Group | None = None
        last_was_agent = False
        for raw in text.splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line or ":" not in line:
                continue
            key, value = line.split(":", 1)
            key, value = key.strip().lower(), value.strip()
            if key == "user-agent":
                if group is None or not last_was_agent:
                    group = _Group()
                    self._groups.append(group)
                group.agents.append(value.lower())
                last_was_agent = True
            elif key in ("allow", "disallow"):
                if group is None:
                    self._fail("regola prima di qualsiasi user-agent")
                    continue
                last_was_agent = False
                if value:  # «Disallow:» vuoto = nessun divieto; «Allow:» vuoto si ignora
                    group.rules.append((key == "allow", value))
            else:  # sitemap, crawl-delay, content-signal...: non cambiano le regole
                if key not in ("sitemap",):
                    last_was_agent = False

    def _rules_for(self, agent: str) -> list[tuple[bool, str]]:
        name = agent.lower()
        specific = [g for g in self._groups if any(a != "*" and a and a in name for a in g.agents)]
        chosen = specific or [g for g in self._groups if "*" in g.agents]
        return [rule for g in chosen for rule in g.rules]

    def can_fetch(self, agent: str, url: str) -> bool:
        if self.ambiguous:
            return False
        parts = urllib.parse.urlsplit(url)
        path = parts.path or "/"
        if path == "/robots.txt":
            return True
        target = _normalize(path + (f"?{parts.query}" if parts.query else ""))
        best_len, allowed = -1, True
        for allow, pattern in self._rules_for(agent):
            if not _pattern_regex(_normalize(pattern)).match(target):
                continue
            size = len(pattern)
            if size > best_len or (size == best_len and allow and not allowed):
                best_len, allowed = size, allow
        return allowed
