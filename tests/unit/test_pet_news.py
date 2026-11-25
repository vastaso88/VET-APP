from datetime import UTC, datetime, timedelta

import pytest

from packages.core.application.ports.pet_news import PetNewsUnavailableError
from packages.core.application.services.get_pet_news import GetPetNewsService, classify_entries
from packages.core.domain.pet_news.models import PetNewsEntry, PetNewsSnapshot, RawNewsEntry
from packages.core.domain.pet_news.relevance import categories_for
from packages.infrastructure.news.feed_reader import HttpPetNewsFeedReader
from packages.infrastructure.news.feeds import FEEDS, NewsFeed
from packages.infrastructure.news.rss import FeedError, parse_feed
from packages.infrastructure.persistence.in_memory_pet_news import InMemoryPetNewsCacheRepository

NOW = datetime(2026, 10, 21, 12, 0, tzinfo=UTC)

RSS = b"""<?xml version="1.0"?>
<rss version="2.0"><channel><title>x</title>
<item><title>Il gatto  che &amp; ama l'acqua</title><link>https://ex.test/a</link>
<description>&lt;p&gt;Un gatto&lt;/p&gt;</description>
<pubDate>Tue, 20 Oct 2026 08:00:00 +0200</pubDate></item>
<item><title>Senza link</title></item>
</channel></rss>"""

ATOM = b"""<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Cani al parco</title>
<link rel="alternate" href="https://ex.test/b"/><published>2026-10-19T10:00:00Z</published>
<summary>Una giornata</summary></entry></feed>"""


def test_parse_rss_and_atom() -> None:
    rss = parse_feed(RSS)
    assert [e.title for e in rss] == ["Il gatto che & ama l'acqua"]
    assert rss[0].summary == "Un gatto"
    assert rss[0].published_at == datetime(2026, 10, 20, 6, 0, tzinfo=UTC)
    atom = parse_feed(ATOM)
    assert atom[0].url == "https://ex.test/b"
    assert atom[0].published_at == datetime(2026, 10, 19, 10, 0, tzinfo=UTC)


def test_parse_refuses_entities_and_garbage() -> None:
    bomb = b'<?xml version="1.0"?><!DOCTYPE x [<!ENTITY a "aaaa">]><rss><channel/></rss>'
    with pytest.raises(FeedError):
        parse_feed(bomb)
    with pytest.raises(FeedError):
        parse_feed(b"<html><body>Cloudflare</body>")


@pytest.mark.parametrize(
    ("title", "expected"),
    [
        ("Il cane salvato dal fiume", ["Cane"]),
        ("Cani e gatti: come vivono insieme", ["Cane", "Gatto"]),
        ("Coniglio alla cacciatora, la ricetta", []),
        ("Criceto domestico: come tenerlo in appartamento", ["Piccoli mammiferi"]),
        ("Fare da cavia in un test clinico", []),
        ("Il pappagallo che parla in gabbia", ["Uccello"]),
        ("Rana pescatrice in padella", []),
        ("Rinnovo organi statutari della Fondazione", []),
        ("Nuove regole sui veterinari per animali da compagnia", ["Generale"]),
        ("Caccia ai cinghiali, polemica in Trentino", []),
        ("Acquario domestico: pesce rosso e luce", ["Pesce"]),
    ],
)
def test_categories_for(title: str, expected: list[str]) -> None:
    assert categories_for(title) == expected


def test_classify_drops_off_topic_and_bad_links() -> None:
    raws = [
        RawNewsEntry(title="Il gatto dorme", source="A", url="https://ex.test/1"),
        RawNewsEntry(title="Il gatto dorme", source="A", url="javascript:alert(1)"),
        RawNewsEntry(title="Borsa in rialzo", source="A", url="https://ex.test/2"),
    ]
    items = classify_entries(raws)
    assert [(i.category, i.url) for i in items] == [("Gatto", "https://ex.test/1")]


class _Reader:
    def __init__(self, entries: list[RawNewsEntry] | None = None, fail: bool = False) -> None:
        self.entries = entries or []
        self.fail = fail
        self.calls = 0

    def has_feeds(self, country: str) -> bool:
        return country == "IT"

    def read_all(self, country: str) -> list[RawNewsEntry]:
        self.calls += 1
        if self.fail:
            raise PetNewsUnavailableError("down")
        return self.entries


def _raw(title: str, hours_ago: int = 1) -> RawNewsEntry:
    return RawNewsEntry(
        title=title,
        source="Fonte",
        url="https://ex.test/" + title.replace(" ", "-"),
        published_at=NOW - timedelta(hours=hours_ago),
    )


class _Clock:
    def __init__(self) -> None:
        self.now = NOW

    def __call__(self) -> datetime:
        return self.now


def _service(
    reader: _Reader, clock: _Clock
) -> tuple[GetPetNewsService, InMemoryPetNewsCacheRepository]:
    cache = InMemoryPetNewsCacheRepository()
    return GetPetNewsService(cache, reader, ttl=timedelta(hours=2), clock=clock), cache


def test_refreshes_when_empty_then_serves_cache_until_ttl() -> None:
    clock, reader = _Clock(), _Reader([_raw("Il cane corre"), _raw("Il gatto dorme")])
    service, _ = _service(reader, clock)

    first = service.get(categories=["Cane", "Gatto"], limit=5)
    assert [i.title for i in first.categories["Cane"]] == ["Il cane corre"]
    assert not first.stale
    service.get()
    assert reader.calls == 1

    clock.now = NOW + timedelta(hours=3)
    service.get()
    assert reader.calls == 2


def test_serves_last_snapshot_when_feeds_fail_and_backs_off() -> None:
    clock, reader = _Clock(), _Reader([_raw("Il cane corre")])
    service, _ = _service(reader, clock)
    service.get()

    clock.now = NOW + timedelta(hours=3)
    reader.fail = True
    result = service.get(categories=["Cane"])
    assert result.stale
    assert [i.title for i in result.categories["Cane"]] == ["Il cane corre"]
    service.get()
    assert reader.calls == 2  # the second failure is not retried within the back-off


def test_no_snapshot_and_no_feed_gives_an_empty_answer() -> None:
    result = _service(_Reader(fail=True), _Clock())[0].get(categories=["Cane"])
    assert result.categories == {}
    assert result.updated_at is None


def test_first_failed_read_with_no_copy_is_repeated_within_seconds_not_minutes() -> None:
    # The first request after a cold start found the feeds down: the Home must not
    # stay without headlines for the five minutes meant for a copy that exists.
    clock, reader = _Clock(), _Reader([_raw("Il cane corre")], fail=True)
    service, _ = _service(reader, clock)

    assert service.get(categories=["Cane"]).categories == {}
    assert reader.calls == 1
    clock.now = NOW + timedelta(seconds=5)
    service.get()
    assert reader.calls == 1  # still inside the short pause: no request storm

    reader.fail = False
    clock.now = NOW + timedelta(seconds=25)
    result = service.get(categories=["Cane"])
    assert reader.calls == 2
    assert [i.title for i in result.categories["Cane"]] == ["Il cane corre"]


def test_useless_refresh_keeps_old_snapshot() -> None:
    clock, reader = _Clock(), _Reader([_raw("Il cane corre")])
    service, _ = _service(reader, clock)
    service.get()
    clock.now = NOW + timedelta(hours=3)
    reader.entries = [_raw("Borsa in rialzo")]
    result = service.get(categories=["Cane"])
    assert result.stale
    assert len(result.categories["Cane"]) == 1


def test_merge_dedups_and_expires() -> None:
    clock, reader = _Clock(), _Reader([_raw("Il cane corre!", 1)])
    service, cache = _service(reader, clock)
    cache.put(
        PetNewsSnapshot(
            key="it",
            fetched_at=NOW - timedelta(hours=5),
            items=[
                PetNewsEntry(
                    category="Cane",
                    title="Il cane corre",
                    source="B",
                    url="https://old.test/1",
                    published_at=NOW - timedelta(hours=9),
                ),
                PetNewsEntry(
                    category="Cane",
                    title="Vecchia notizia di cani",
                    source="B",
                    url="https://old.test/2",
                    published_at=NOW - timedelta(days=40),
                ),
            ],
        )
    )
    titles = [i.title for i in service.get(categories=["Cane"]).categories["Cane"]]
    assert titles == ["Il cane corre!"]


def test_feed_reader_tolerates_a_broken_feed() -> None:
    feeds = (
        NewsFeed("ok", "Ok", "https://ok.test/f", "t", "IT"),
        NewsFeed("bad", "Bad", "https://bad.test/f", "t", "IT"),
    )

    def fetch(url: str) -> bytes:
        if "bad" in url:
            raise OSError("boom")
        return RSS

    entries = HttpPetNewsFeedReader(fetch=fetch, feeds=feeds).read_all("IT")
    assert [e.source for e in entries] == ["Ok"]

    def always_down(_url: str) -> bytes:
        raise OSError("down")

    with pytest.raises(PetNewsUnavailableError):
        HttpPetNewsFeedReader(fetch=always_down, feeds=feeds).read_all("IT")
    with pytest.raises(PetNewsUnavailableError):
        HttpPetNewsFeedReader(
            fetch=fetch, disabled_feed_keys=frozenset({"ok", "bad"}), feeds=feeds
        ).read_all("IT")


def test_a_feed_is_read_only_for_its_own_country() -> None:
    asked: list[str] = []

    def fetch(url: str) -> bytes:
        asked.append(url)
        return RSS

    reader = HttpPetNewsFeedReader(
        fetch=fetch,
        feeds=(
            NewsFeed("it", "It", "https://it.test/f", "t", "IT"),
            NewsFeed("fr", "Fr", "https://fr.test/f", "t", "FR"),
        ),
    )

    assert [e.source for e in reader.read_all("FR")] == ["Fr"]
    assert asked == ["https://fr.test/f"]
    assert (reader.has_feeds("IT"), reader.has_feeds("DE")) == (True, False)


def test_a_country_without_feeds_has_no_news_and_nothing_is_read_for_it() -> None:
    reader = _Reader([_raw("Il cane corre")])
    service, cache = _service(reader, _Clock())

    answer = service.get(categories=["Cane"], country="fr")

    assert (answer.categories, answer.country_has_news, answer.stale) == ({}, False, False)
    assert reader.calls == 0
    assert cache.get("fr") is None


def test_every_feed_of_today_is_italian_and_without_a_country_they_are_the_ones_served() -> None:
    assert {feed.country for feed in FEEDS} == {"IT"}
    service, cache = _service(_Reader([_raw("Il cane corre")]), _Clock())

    answer = service.get(categories=["Cane"])

    assert answer.country_has_news
    assert [item.title for item in answer.categories["Cane"]] == ["Il cane corre"]
    assert cache.get("it") is not None  # the key of the snapshots already stored
