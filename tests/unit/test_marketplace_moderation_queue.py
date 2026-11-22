"""QK-06: the moderation queue loads its conversations in one read, not one per
report. Counts the reads on both adapters (in-memory double and the Supabase code
against a small stand-in client) and compares the rows with the old one-by-one
behaviour. Synthetic data only."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.application.services.marketplace_messaging import (
    MarketplaceMessagingModerationService,
)
from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
)
from packages.infrastructure.persistence.in_memory_marketplace_messaging import (
    InMemoryMarketplaceMessagingRepository,
)
from packages.infrastructure.persistence.supabase.supabase_marketplace_messaging import (
    SupabaseMarketplaceMessagingRepository,
)

T0 = datetime(2026, 11, 22, 10, 0, tzinfo=UTC)


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, client: _Client, rows: list[dict[str, Any]]) -> None:
        self._client = client
        self._rows = rows
        self._in: tuple[str, list[str]] | None = None
        self._eq: tuple[str, object] | None = None
        self._order_desc: bool = False
        self._limit: int | None = None

    def select(self, columns: str) -> _Query:
        self._client.selects.append(columns)
        return self

    def eq(self, column: str, value: object) -> _Query:
        self._eq = (column, value)
        return self

    def in_(self, column: str, values: list[str]) -> _Query:
        self._in = (column, values)
        return self

    def order(self, _column: str, *, desc: bool = False) -> _Query:
        self._order_desc = desc
        return self

    def limit(self, count: int) -> _Query:
        self._limit = count
        return self

    def execute(self) -> _Response:
        self._client.reads += 1
        rows = self._rows
        if self._in is not None:
            column, values = self._in
            rows = [row for row in rows if row[column] in values]
        if self._eq is not None:
            column, value = self._eq
            rows = [row for row in rows if row[column] == value]
        if self._order_desc:
            rows = sorted(rows, key=lambda row: row["created_at"], reverse=True)
        return _Response([dict(row) for row in rows[: self._limit]])


class _Client:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict[str, Any]]] = {}
        self.reads = 0
        self.selects: list[str] = []

    def table(self, name: str) -> _Query:
        return _Query(self, self.tables.setdefault(name, []))


class _CountingInMemory(InMemoryMarketplaceMessagingRepository):
    def __init__(self) -> None:
        super().__init__()
        self.reads = 0

    def list_reports(self, limit: int) -> list[MarketplaceConversationReport]:
        self.reads += 1
        return super().list_reports(limit)

    def get_conversation(self, conversation_id: str) -> MarketplaceConversation | None:
        self.reads += 1
        return super().get_conversation(conversation_id)

    def get_reported_conversations(self, conversation_ids: list[str]) -> Any:
        self.reads += 1
        return super().get_reported_conversations(conversation_ids)


class _Harness:
    """A repository plus a way to seed it and to read the read counter."""

    def __init__(self, kind: str) -> None:
        self.kind = kind
        self.client = _Client()
        self.memory = _CountingInMemory()
        self.repository: MarketplaceMessagingRepository = (
            self.memory
            if kind == "in_memory"
            else SupabaseMarketplaceMessagingRepository(self.client)  # type: ignore[arg-type]
        )

    def add_conversation(self, conversation: MarketplaceConversation) -> None:
        if self.kind == "in_memory":
            self.memory.conversations[conversation.id] = conversation
        else:
            self.client.tables.setdefault("marketplace_conversations", []).append(
                conversation.model_dump(mode="json")
            )

    def add_report(self, report: MarketplaceConversationReport) -> None:
        if self.kind == "in_memory":
            self.memory.reports[report.id] = report
        else:
            self.client.tables.setdefault("marketplace_conversation_reports", []).append(
                report.model_dump(mode="json")
            )

    @property
    def reads(self) -> int:
        return self.memory.reads if self.kind == "in_memory" else self.client.reads


@pytest.fixture(params=["in_memory", "supabase"])
def harness(request: pytest.FixtureRequest) -> _Harness:
    return _Harness(request.param)


def _conversation(index: int) -> MarketplaceConversation:
    return MarketplaceConversation(
        id=f"conv-{index}",
        listing_id=f"ad-{index}",
        listing_title=f"Cuccia {index}",
        buyer_id=f"buyer-{index}",
        seller_id=f"seller-{index}",
        created_at=T0,
        last_message_at=T0,
    )


def _report(index: int, conversation_id: str, reporter_id: str) -> MarketplaceConversationReport:
    return MarketplaceConversationReport(
        id=f"rep-{index:03d}",
        conversation_id=conversation_id,
        reporter_id=reporter_id,
        reason="spam",
        created_at=T0 + timedelta(minutes=index),
    )


def _old_queue(repository: MarketplaceMessagingRepository, limit: int) -> list[dict[str, object]]:
    """The queue as it was before QK-06: one lookup per report."""
    rows: list[dict[str, object]] = []
    for report in repository.list_reports(limit):
        conversation = repository.get_conversation(report.conversation_id)
        rows.append(
            {
                **report.model_dump(mode="json"),
                "listing_title": conversation.listing_title if conversation else None,
                "subject_owner_id": (
                    conversation.seller_id
                    if report.reporter_id == conversation.buyer_id
                    else conversation.buyer_id
                )
                if conversation
                else None,
            }
        )
    return rows


def test_a_hundred_reports_take_two_reads_even_with_repeated_conversations(
    harness: _Harness,
) -> None:
    # 100 reports on 40 conversations: both participants report some of them.
    for index in range(40):
        harness.add_conversation(_conversation(index))
    for index in range(100):
        conversation = _conversation(index % 40)
        reporter = conversation.buyer_id if index % 2 == 0 else conversation.seller_id
        harness.add_report(_report(index, conversation.id, reporter))
    harness.memory.reads = 0
    harness.client.reads = 0

    rows = MarketplaceMessagingModerationService(harness.repository).queue(100)

    assert len(rows) == 100
    assert harness.reads <= 2
    # Newest first, as before.
    assert [row["id"] for row in rows] == [f"rep-{index:03d}" for index in range(99, -1, -1)]


def test_rows_match_the_old_one_by_one_queue_including_a_missing_conversation(
    harness: _Harness,
) -> None:
    for index in range(5):
        harness.add_conversation(_conversation(index))
    harness.add_report(_report(1, "conv-0", "buyer-0"))  # subject: the seller
    harness.add_report(_report(2, "conv-1", "seller-1"))  # subject: the buyer
    harness.add_report(_report(3, "conv-gone", "someone"))  # conversation deleted
    harness.add_report(_report(4, "conv-1", "buyer-1"))  # repeated conversation

    new = MarketplaceMessagingModerationService(harness.repository).queue(100)
    old = _old_queue(harness.repository, 100)

    assert new == old
    by_id = {row["id"]: row for row in new}
    assert by_id["rep-001"]["subject_owner_id"] == "seller-0"
    assert by_id["rep-002"]["subject_owner_id"] == "buyer-1"
    assert by_id["rep-003"]["listing_title"] is None
    assert by_id["rep-003"]["subject_owner_id"] is None


def test_an_empty_queue_looks_up_no_conversation(harness: _Harness) -> None:
    harness.add_conversation(_conversation(0))  # a conversation but no report

    rows = MarketplaceMessagingModerationService(harness.repository).queue(100)

    assert rows == []
    assert harness.reads == 1  # only the list of reports


def test_the_supabase_read_asks_only_for_the_columns_the_queue_shows() -> None:
    harness = _Harness("supabase")
    harness.add_conversation(_conversation(0))
    harness.add_report(_report(1, "conv-0", "buyer-0"))

    MarketplaceMessagingModerationService(harness.repository).queue(100)

    assert harness.client.selects[-1] == "id,listing_title,buyer_id,seller_id"


def test_more_ids_than_one_request_holds_are_split_and_still_complete() -> None:
    harness = _Harness("supabase")
    for index in range(250):
        harness.add_conversation(_conversation(index))

    found = harness.repository.get_reported_conversations(
        [f"conv-{index}" for index in range(250)] * 2
    )

    assert len(found) == 250
    assert harness.client.reads == 3  # 100 + 100 + 50 distinct ids
