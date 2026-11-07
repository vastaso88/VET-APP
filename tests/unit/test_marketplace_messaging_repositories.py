"""The same behaviour from the in-memory double and from the Supabase repository.
Tests never reach a real database, so the Supabase code runs here against a small
stand-in for the client: it checks the columns and the queries the code asks for."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceRestriction,
    MarketplaceUserBlock,
)
from packages.infrastructure.persistence.in_memory_marketplace_messaging import (
    InMemoryMarketplaceMessagingRepository,
)
from packages.infrastructure.persistence.supabase.supabase_marketplace_messaging import (
    SupabaseMarketplaceMessagingRepository,
)

T0 = datetime(2026, 11, 7, 10, 0, tzinfo=UTC)


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows
        self._filters: list[Callable[[dict[str, Any]], bool]] = []
        self._order: tuple[str, bool] | None = None
        self._limit: int | None = None
        self._write: Callable[[], list[dict[str, Any]]] | None = None

    def select(self, _columns: str) -> _Query:
        return self

    def eq(self, column: str, value: object) -> _Query:
        self._filters.append(lambda row: row.get(column) == value)
        return self

    def gt(self, column: str, value: int) -> _Query:
        self._filters.append(lambda row: row[column] > value)
        return self

    def is_(self, column: str, value: str) -> _Query:
        assert value == "null"
        self._filters.append(lambda row: row.get(column) is None)
        return self

    def in_(self, column: str, values: list[str]) -> _Query:
        self._filters.append(lambda row: row.get(column) in values)
        return self

    def gte(self, column: str, value: str) -> _Query:
        since = datetime.fromisoformat(value)
        self._filters.append(lambda row: datetime.fromisoformat(row[column]) >= since)
        return self

    def order(self, column: str, *, desc: bool = False) -> _Query:
        self._order = (column, desc)
        return self

    def limit(self, count: int) -> _Query:
        self._limit = count
        return self

    def insert(self, row: dict[str, Any]) -> _Query:
        self._write = lambda: self._append(row)
        return self

    def upsert(
        self, row: dict[str, Any], *, on_conflict: str = "id", ignore_duplicates: bool = False
    ) -> _Query:
        def write() -> list[dict[str, Any]]:
            keys = on_conflict.split(",")
            for existing in self._rows:
                if all(existing.get(key) == row.get(key) for key in keys):
                    if not ignore_duplicates:
                        existing.update(row)
                    return [existing]
            return self._append(row)

        self._write = write
        return self

    def update(self, fields: dict[str, Any]) -> _Query:
        def write() -> list[dict[str, Any]]:
            matching = self._matching()
            for row in matching:
                row.update(fields)
            return matching

        self._write = write
        return self

    def delete(self) -> _Query:
        def write() -> list[dict[str, Any]]:
            matching = self._matching()
            for row in matching:
                self._rows.remove(row)
            return matching

        self._write = write
        return self

    def _append(self, row: dict[str, Any]) -> list[dict[str, Any]]:
        self._rows.append(dict(row))
        return [row]

    def _matching(self) -> list[dict[str, Any]]:
        return [row for row in self._rows if all(check(row) for check in self._filters)]

    def execute(self) -> _Response:
        if self._write is not None:
            return _Response(self._write())
        rows = self._matching()
        if self._order is not None:
            column, descending = self._order
            rows = sorted(rows, key=lambda row: row[column], reverse=descending)
        return _Response([dict(row) for row in rows[: self._limit]])


class _Client:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict[str, Any]]] = {}

    def table(self, name: str) -> _Query:
        return _Query(self.tables.setdefault(name, []))


@pytest.fixture(params=["in_memory", "supabase"])
def repository(request: pytest.FixtureRequest) -> MarketplaceMessagingRepository:
    if request.param == "in_memory":
        return InMemoryMarketplaceMessagingRepository()
    return SupabaseMarketplaceMessagingRepository(_Client())  # type: ignore[arg-type]


def _conversation(
    conversation_id: str,
    *,
    listing: str = "ad",
    buyer: str = "buyer",
    seller: str = "seller",
    at: datetime = T0,
) -> MarketplaceConversation:
    return MarketplaceConversation(
        id=conversation_id,
        listing_id=listing,
        listing_title="Cuccia",
        buyer_id=buyer,
        seller_id=seller,
        created_at=at,
        last_message_at=at,
    )


def test_a_second_create_for_the_same_ad_and_buyer_returns_the_first(
    repository: MarketplaceMessagingRepository,
) -> None:
    first = repository.create_conversation(_conversation("first"))

    second = repository.create_conversation(_conversation("second"))

    assert first.id == "first"
    assert second.id == "first"
    assert repository.get_conversation("second") is None
    found = repository.find_conversation("ad", "buyer")
    assert found is not None and found.id == "first"
    assert repository.find_conversation("ad", "someone-else") is None


def test_the_list_holds_both_roles_with_the_most_recent_first(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.create_conversation(_conversation("old", listing="a", at=T0))
    repository.create_conversation(
        _conversation("new", listing="b", buyer="other", seller="buyer", at=T0 + timedelta(hours=1))
    )
    repository.create_conversation(_conversation("not-mine", listing="c", buyer="x", seller="y"))

    assert [item.id for item in repository.list_conversations("buyer", 10)] == ["new", "old"]
    assert [item.id for item in repository.list_conversations("buyer", 1)] == ["new"]


def test_the_counters_move_only_their_own_column(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.create_conversation(_conversation("c1", listing="a"))
    repository.create_conversation(_conversation("c2", listing="b"))
    later = T0 + timedelta(minutes=5)

    repository.record_message("c1", later, "seller", 2)
    repository.record_message("c2", later, "seller", 3)
    repository.record_message("c1", later, "buyer", 1)

    assert repository.unread_total("seller") == 5
    assert repository.unread_total("buyer") == 1
    conversation = repository.get_conversation("c1")
    assert conversation is not None
    assert conversation.last_message_at == later

    repository.clear_unread("c1", "seller")

    assert repository.unread_total("seller") == 3
    assert repository.unread_total("buyer") == 1


def test_only_the_last_messages_come_back_oldest_first(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.create_conversation(_conversation("c1"))
    for minute in range(5):
        repository.add_message(
            MarketplaceMessage(
                id=f"m{minute}",
                conversation_id="c1",
                sender_id="buyer",
                body=f"testo {minute}",
                created_at=T0 + timedelta(minutes=minute),
            )
        )
    repository.add_message(
        MarketplaceMessage(conversation_id="elsewhere", sender_id="x", body="altro")
    )

    assert [item.id for item in repository.list_messages("c1", 3)] == ["m2", "m3", "m4"]


def test_the_start_times_count_only_that_buyer_inside_the_window(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.create_conversation(_conversation("old", listing="a", at=T0 - timedelta(days=2)))
    repository.create_conversation(_conversation("new", listing="b", at=T0))
    repository.create_conversation(_conversation("other", listing="c", buyer="x", at=T0))

    started = repository.conversation_start_times("buyer", T0 - timedelta(days=1))

    assert started == [T0]


def test_blocks_are_seen_from_both_sides_and_can_be_removed(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.add_block(MarketplaceUserBlock(blocker_id="a", blocked_id="b"))
    repository.add_block(MarketplaceUserBlock(blocker_id="a", blocked_id="b"))
    repository.add_block(MarketplaceUserBlock(blocker_id="c", blocked_id="a"))

    assert len(repository.blocks_involving("a")) == 2
    assert [item.blocker_id for item in repository.blocks_involving("b")] == ["a"]

    repository.remove_block("a", "b")

    assert repository.blocks_involving("b") == []


def test_the_team_closes_and_reopens_a_conversation(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.create_conversation(_conversation("c1"))

    repository.set_moderation_closed("c1", T0)
    closed = repository.get_conversation("c1")
    assert closed is not None and closed.moderation_closed_at == T0

    repository.set_moderation_closed("c1", None)
    opened = repository.get_conversation("c1")
    assert opened is not None and opened.moderation_closed_at is None


def test_reports_are_found_saved_again_and_listed(
    repository: MarketplaceMessagingRepository,
) -> None:
    report = repository.save_report(
        MarketplaceConversationReport(
            id="r1", conversation_id="c1", reporter_id="buyer", reason="scam", created_at=T0
        )
    )
    repository.save_report(
        MarketplaceConversationReport(
            id="r2",
            conversation_id="c2",
            reporter_id="buyer",
            reason="spam",
            created_at=T0 + timedelta(hours=1),
        )
    )

    repository.save_report(report.model_copy(update={"status": "dismissed"}))

    found = repository.find_report("c1", "buyer")
    assert found is not None and found.status == "dismissed"
    assert repository.find_report("c1", "other") is None
    assert repository.get_report("missing") is None
    assert [item.id for item in repository.list_reports(10)] == ["r2", "r1"]


def test_a_restriction_counts_until_it_is_lifted(
    repository: MarketplaceMessagingRepository,
) -> None:
    repository.save_restriction(MarketplaceRestriction(owner_id="a", reason="scam", created_at=T0))
    repository.save_restriction(
        MarketplaceRestriction(owner_id="b", reason="spam", created_at=T0 + timedelta(hours=1))
    )

    assert repository.restricted_among(["a", "b", "c"]) == {"a", "b"}

    stored = repository.get_restriction("a")
    assert stored is not None and stored.active
    repository.save_restriction(stored.model_copy(update={"lifted_at": T0 + timedelta(days=1)}))

    assert repository.restricted_among(["a", "b"]) == {"b"}
    lifted = repository.get_restriction("a")
    assert lifted is not None and not lifted.active
    assert repository.get_restriction("c") is None
    assert repository.restricted_among([]) == set()
    assert [item.owner_id for item in repository.list_restrictions(10)] == ["b", "a"]
