"""robots.txt secondo la RFC 9309 (doc 20 §23.1): regola più specifica, a parità Allow."""

from __future__ import annotations

from pathlib import Path

import pytest

from scripts.sources import fetcher as F
from scripts.sources.robots9309 import Robots9309

# Esempio della RFC 9309 (§5.1/§5.2): gruppi per foobot, barbot e bazbot, e per tutti gli altri.
RFC = """User-Agent: *
Allow: /

User-Agent: foobot
Disallow: /
Allow: /example/page/
Disallow: /example/page/disallowed.gif

User-Agent: barbot
User-Agent: bazbot
Disallow: /example/page/
"""


@pytest.mark.parametrize(
    ("agent", "path", "expected"),
    [
        ("foobot", "/", False),
        ("foobot", "/example/page/", True),
        ("foobot", "/example/page/disallowed.gif", False),
        ("foobot", "/example/page/other.gif", True),
        ("barbot", "/example/page/", False),
        ("bazbot", "/example/page/x", False),
        ("bazbot", "/other", True),
        ("otherbot", "/example/page/disallowed.gif", True),
    ],
)
def test_rfc_examples(agent: str, path: str, expected: bool) -> None:
    assert Robots9309(RFC).can_fetch(agent, f"https://x.example{path}") is expected


def test_the_longest_rule_wins_and_allow_wins_a_tie() -> None:
    robots = Robots9309("User-agent: *\nDisallow: /a\nAllow: /a/b\nDisallow: /same\nAllow: /same\n")
    assert robots.can_fetch("q", "https://x.example/a/b/c")  # Allow più lungo
    assert not robots.can_fetch("q", "https://x.example/a/z")
    assert robots.can_fetch("q", "https://x.example/same")  # parità: Allow


def test_wildcards_end_anchor_and_percent_encoding() -> None:
    robots = Robots9309("User-agent: *\nDisallow: /*.gif$\nDisallow: /tmp*/x\nAllow: /ok%2Fx\n")
    assert not robots.can_fetch("q", "https://x.example/a/b.gif")
    assert robots.can_fetch("q", "https://x.example/a/b.gif?size=1")  # «$» = fine del percorso
    assert not robots.can_fetch("q", "https://x.example/tmp123/x")
    assert robots.can_fetch("q", "https://x.example/ok/x")


def test_data_gov_au_pages_are_closed_but_the_api_is_open() -> None:
    robots = Robots9309("# robots.txt\nUser-agent: *\nDisallow: /\nAllow: /data/api/\n")
    assert not robots.can_fetch("QuokkaCercafonti", "https://data.gov.au/data/dataset/dog-parks")
    assert robots.can_fetch(
        "QuokkaCercafonti", "https://data.gov.au/data/api/3/action/package_show?id=dog-parks"
    )
    assert robots.can_fetch("QuokkaCercafonti", "https://data.gov.au/robots.txt")


def test_our_own_group_replaces_the_star_group() -> None:
    robots = Robots9309("User-agent: QuokkaCercafonti\nDisallow: /\n\nUser-agent: *\nAllow: /\n")
    assert not robots.can_fetch("QuokkaCercafonti", "https://x.example/p")
    assert robots.can_fetch("OtherBot", "https://x.example/p")


def test_empty_disallow_and_empty_file_allow_everything() -> None:
    assert Robots9309("User-agent: *\nDisallow:\n").can_fetch("q", "https://x.example/p")
    assert Robots9309("").can_fetch("q", "https://x.example/p")


@pytest.mark.parametrize(
    "text",
    ["Disallow: /\n", "User-agent: *\nDisallow: /\n��", "<html><body>no</body></html>"],
)
def test_an_ambiguous_or_unreadable_file_means_stop(text: str) -> None:
    robots = Robots9309(text)
    assert robots.ambiguous
    assert not robots.can_fetch("q", "https://x.example/p")


def test_fetcher_stops_the_host_on_an_ambiguous_robots_file(tmp_path: Path) -> None:
    from test_cercafonti import make  # noqa: PLC0415

    fetcher, opener, _ = make(
        tmp_path, {"https://a.example.org/robots.txt": (200, "Disallow: /\n", "text/plain")}
    )
    with pytest.raises(F.Blocked, match="ambiguo"):
        fetcher.get("https://a.example.org/p")
    assert fetcher.is_stopped("a.example.org")
    assert [url for url, _ in opener.seen] == ["https://a.example.org/robots.txt"]


def test_fetcher_reads_the_api_but_not_the_pages_of_a_portal(tmp_path: Path) -> None:
    from test_cercafonti import make  # noqa: PLC0415

    robots = "User-agent: *\nDisallow: /\nAllow: /data/api/\n"
    table = {
        "https://data.example.au/robots.txt": (200, robots, "text/plain"),
        "https://data.example.au/data/api/3/x": (200, "{}", "application/json"),
    }
    fetcher, _, _ = make(tmp_path, table)
    assert fetcher.get("https://data.example.au/data/api/3/x").status == 200
    with pytest.raises(F.Blocked, match="robots.txt non permette"):
        fetcher.get("https://data.example.au/data/dataset/x")


def test_gouv_fr_is_an_umbrella_suffix_and_data_gouv_fr_is_its_own_host(tmp_path: Path) -> None:
    from test_cercafonti import make  # noqa: PLC0415

    assert "gouv.fr" in F.UMBRELLA_SUFFIXES
    assert F.umbrella_of("www.data.gouv.fr") == "gouv.fr"
    assert F.registrable_domain("www.data.gouv.fr") == "data.gouv.fr"
    assert F.registrable_domain("www.legifrance.gouv.fr") == "legifrance.gouv.fr"
    table = {
        "https://www.legifrance.gouv.fr/robots.txt": (404, ""),
        "https://www.legifrance.gouv.fr/p": (403, "no"),
    }
    blocked, _, _ = make(tmp_path, table)
    with pytest.raises(F.Blocked):
        blocked.get("https://www.legifrance.gouv.fr/p")
    other, _, _ = make(tmp_path, {})
    assert other.is_stopped("www.legifrance.gouv.fr")  # Légifrance resta fermo
    assert other.is_stopped("www.data.gouv.fr") is None  # data.gouv.fr è un host a sé
    table2 = {
        "https://www.data.gouv.fr/robots.txt": (404, ""),
        "https://www.data.gouv.fr/p": (403, "x"),
    }
    second, _, _ = make(tmp_path, table2)
    with pytest.raises(F.Blocked):
        second.get("https://www.data.gouv.fr/p")
    assert second.is_stopped(
        "www.cnil.gouv.fr"
    )  # secondo ente bloccato lo stesso giorno: tutto il suffisso
