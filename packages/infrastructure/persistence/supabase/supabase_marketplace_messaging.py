"""Mercatino messages on Supabase (service-role client): tables created by
scripts/setup/marketplace_messages.sql. The service role ignores row-level
security, so who may read what is decided in
packages/core/application/services/marketplace_messaging.py. Message text is
never logged here."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceUserBlock,
    ParticipantRole,
)

if TYPE_CHECKING:
    from supabase import Client

_CONVERSATIONS = "marketplace_conversations"
_MESSAGES = "marketplace_messages"
_BLOCKS = "marketplace_user_blocks"
_REPORTS = "marketplace_conversation_reports"


def _rows(response: Any) -> list[dict[str, Any]]:
    return cast(list[dict[str, Any]], response.data or [])


class SupabaseMarketplaceMessagingRepository:
    def __init__(self, client: Client) -> None:
        self._client = client

    def find_conversation(self, listing_id: str, buyer_id: str) -> MarketplaceConversation | None:
        response = (
            self._client.table(_CONVERSATIONS)
            .select("*")
            .eq("listing_id", listing_id)
            .eq("buyer_id", buyer_id)
            .limit(1)
            .execute()
        )
        rows = _rows(response)
        return MarketplaceConversation.model_validate(rows[0]) if rows else None

    def get_conversation(self, conversation_id: str) -> MarketplaceConversation | None:
        response = (
            self._client.table(_CONVERSATIONS)
            .select("*")
            .eq("id", conversation_id)
            .limit(1)
            .execute()
        )
        rows = _rows(response)
        return MarketplaceConversation.model_validate(rows[0]) if rows else None

    def create_conversation(self, conversation: MarketplaceConversation) -> MarketplaceConversation:
        # The unique index on (listing_id, buyer_id) settles a race: the second
        # request inserts nothing and reads back the first one's row.
        self._client.table(_CONVERSATIONS).upsert(
            conversation.model_dump(mode="json"),
            on_conflict="listing_id,buyer_id",
            ignore_duplicates=True,
        ).execute()
        if conversation.listing_id is None:
            return conversation
        stored = self.find_conversation(conversation.listing_id, conversation.buyer_id)
        return stored if stored is not None else conversation

    def list_conversations(self, user_id: str, limit: int) -> list[MarketplaceConversation]:
        rows: list[dict[str, Any]] = []
        for column in ("buyer_id", "seller_id"):
            response = (
                self._client.table(_CONVERSATIONS)
                .select("*")
                .eq(column, user_id)
                .order("last_message_at", desc=True)
                .limit(limit)
                .execute()
            )
            rows.extend(_rows(response))
        conversations = [MarketplaceConversation.model_validate(row) for row in rows]
        conversations.sort(key=lambda item: item.last_message_at, reverse=True)
        return conversations[:limit]

    def conversation_start_times(self, buyer_id: str, since: datetime) -> list[datetime]:
        response = (
            self._client.table(_CONVERSATIONS)
            .select("created_at")
            .eq("buyer_id", buyer_id)
            .gte("created_at", since.isoformat())
            .execute()
        )
        return [datetime.fromisoformat(str(row["created_at"])) for row in _rows(response)]

    def unread_total(self, user_id: str) -> int:
        total = 0
        for owner_column, unread_column in (
            ("buyer_id", "buyer_unread"),
            ("seller_id", "seller_unread"),
        ):
            response = (
                self._client.table(_CONVERSATIONS)
                .select(unread_column)
                .eq(owner_column, user_id)
                .gt(unread_column, 0)
                .execute()
            )
            total += sum(int(row[unread_column]) for row in _rows(response))
        return total

    def add_message(self, message: MarketplaceMessage) -> MarketplaceMessage:
        self._client.table(_MESSAGES).insert(message.model_dump(mode="json")).execute()
        return message

    def list_messages(self, conversation_id: str, limit: int) -> list[MarketplaceMessage]:
        response = (
            self._client.table(_MESSAGES)
            .select("*")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        messages = [MarketplaceMessage.model_validate(row) for row in _rows(response)]
        messages.reverse()
        return messages

    def record_message(
        self, conversation_id: str, at: datetime, recipient: ParticipantRole, unread: int
    ) -> None:
        # Only these two columns: a whole-row write could undo the other
        # participant's "read" arriving at the same moment.
        self._update(
            conversation_id,
            {"last_message_at": at.isoformat(), f"{recipient}_unread": unread},
        )

    def clear_unread(self, conversation_id: str, role: ParticipantRole) -> None:
        self._update(conversation_id, {f"{role}_unread": 0})

    def set_moderation_closed(self, conversation_id: str, at: datetime | None) -> None:
        self._update(conversation_id, {"moderation_closed_at": at.isoformat() if at else None})

    def _update(self, conversation_id: str, fields: dict[str, Any]) -> None:
        self._client.table(_CONVERSATIONS).update(fields).eq("id", conversation_id).execute()

    def blocks_involving(self, user_id: str) -> list[MarketplaceUserBlock]:
        rows: list[dict[str, Any]] = []
        for column in ("blocker_id", "blocked_id"):
            rows.extend(
                _rows(self._client.table(_BLOCKS).select("*").eq(column, user_id).execute())
            )
        return [MarketplaceUserBlock.model_validate(row) for row in rows]

    def add_block(self, block: MarketplaceUserBlock) -> None:
        self._client.table(_BLOCKS).upsert(
            block.model_dump(mode="json"), on_conflict="blocker_id,blocked_id"
        ).execute()

    def remove_block(self, blocker_id: str, blocked_id: str) -> None:
        self._client.table(_BLOCKS).delete().eq("blocker_id", blocker_id).eq(
            "blocked_id", blocked_id
        ).execute()

    def find_report(
        self, conversation_id: str, reporter_id: str
    ) -> MarketplaceConversationReport | None:
        response = (
            self._client.table(_REPORTS)
            .select("*")
            .eq("conversation_id", conversation_id)
            .eq("reporter_id", reporter_id)
            .limit(1)
            .execute()
        )
        rows = _rows(response)
        return MarketplaceConversationReport.model_validate(rows[0]) if rows else None

    def get_report(self, report_id: str) -> MarketplaceConversationReport | None:
        response = self._client.table(_REPORTS).select("*").eq("id", report_id).limit(1).execute()
        rows = _rows(response)
        return MarketplaceConversationReport.model_validate(rows[0]) if rows else None

    def save_report(self, report: MarketplaceConversationReport) -> MarketplaceConversationReport:
        self._client.table(_REPORTS).upsert(report.model_dump(mode="json")).execute()
        return report

    def list_reports(self, limit: int) -> list[MarketplaceConversationReport]:
        response = (
            self._client.table(_REPORTS)
            .select("*")
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return [MarketplaceConversationReport.model_validate(row) for row in _rows(response)]
