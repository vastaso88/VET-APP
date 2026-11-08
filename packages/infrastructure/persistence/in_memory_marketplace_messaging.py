from datetime import datetime

from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceRestriction,
    MarketplaceUserBlock,
    ModerationAccess,
    ParticipantRole,
)


class InMemoryMarketplaceMessagingRepository:
    def __init__(self) -> None:
        self.conversations: dict[str, MarketplaceConversation] = {}
        self.messages: list[MarketplaceMessage] = []
        self.blocks: list[MarketplaceUserBlock] = []
        self.reports: dict[str, MarketplaceConversationReport] = {}
        self.restrictions: dict[str, MarketplaceRestriction] = {}
        self.moderation_accesses: list[ModerationAccess] = []

    def find_conversation(self, listing_id: str, buyer_id: str) -> MarketplaceConversation | None:
        for item in self.conversations.values():
            if item.listing_id == listing_id and item.buyer_id == buyer_id:
                return item
        return None

    def get_conversation(self, conversation_id: str) -> MarketplaceConversation | None:
        return self.conversations.get(conversation_id)

    def create_conversation(self, conversation: MarketplaceConversation) -> MarketplaceConversation:
        if conversation.listing_id is not None:
            existing = self.find_conversation(conversation.listing_id, conversation.buyer_id)
            if existing is not None:
                return existing
        self.conversations[conversation.id] = conversation
        return conversation

    def list_conversations(self, user_id: str, limit: int) -> list[MarketplaceConversation]:
        mine = [item for item in self.conversations.values() if item.role_of(user_id) is not None]
        mine.sort(key=lambda item: item.last_message_at, reverse=True)
        return mine[:limit]

    def conversation_start_times(self, buyer_id: str, since: datetime) -> list[datetime]:
        return [
            item.created_at
            for item in self.conversations.values()
            if item.buyer_id == buyer_id and item.created_at >= since
        ]

    def unread_total(self, user_id: str) -> int:
        total = 0
        for item in self.conversations.values():
            if item.buyer_id == user_id:
                total += item.buyer_unread
            elif item.seller_id == user_id:
                total += item.seller_unread
        return total

    def add_message(self, message: MarketplaceMessage) -> MarketplaceMessage:
        self.messages.append(message)
        return message

    def list_messages(self, conversation_id: str, limit: int) -> list[MarketplaceMessage]:
        rows = [item for item in self.messages if item.conversation_id == conversation_id]
        rows.sort(key=lambda item: item.created_at)
        return rows[-limit:]

    def record_message(
        self, conversation_id: str, at: datetime, recipient: ParticipantRole, unread: int
    ) -> None:
        self._update(conversation_id, {"last_message_at": at, f"{recipient}_unread": unread})

    def clear_unread(self, conversation_id: str, role: ParticipantRole) -> None:
        self._update(conversation_id, {f"{role}_unread": 0})

    def set_moderation_closed(self, conversation_id: str, at: datetime | None) -> None:
        self._update(conversation_id, {"moderation_closed_at": at})

    def _update(self, conversation_id: str, fields: dict[str, object]) -> None:
        item = self.conversations.get(conversation_id)
        if item is not None:
            self.conversations[conversation_id] = item.model_copy(update=fields)

    def blocks_involving(self, user_id: str) -> list[MarketplaceUserBlock]:
        return [item for item in self.blocks if user_id in (item.blocker_id, item.blocked_id)]

    def add_block(self, block: MarketplaceUserBlock) -> None:
        self.remove_block(block.blocker_id, block.blocked_id)
        self.blocks.append(block)

    def remove_block(self, blocker_id: str, blocked_id: str) -> None:
        self.blocks = [
            item
            for item in self.blocks
            if not (item.blocker_id == blocker_id and item.blocked_id == blocked_id)
        ]

    def find_report(
        self, conversation_id: str, reporter_id: str
    ) -> MarketplaceConversationReport | None:
        for item in self.reports.values():
            if item.conversation_id == conversation_id and item.reporter_id == reporter_id:
                return item
        return None

    def get_report(self, report_id: str) -> MarketplaceConversationReport | None:
        return self.reports.get(report_id)

    def save_report(self, report: MarketplaceConversationReport) -> MarketplaceConversationReport:
        self.reports[report.id] = report
        return report

    def list_reports(self, limit: int) -> list[MarketplaceConversationReport]:
        rows = sorted(self.reports.values(), key=lambda item: item.created_at, reverse=True)
        return rows[:limit]

    def get_restriction(self, owner_id: str) -> MarketplaceRestriction | None:
        return self.restrictions.get(owner_id)

    def save_restriction(self, restriction: MarketplaceRestriction) -> MarketplaceRestriction:
        self.restrictions[restriction.owner_id] = restriction
        return restriction

    def restricted_among(self, owner_ids: list[str]) -> set[str]:
        return {
            owner_id
            for owner_id in owner_ids
            if (item := self.restrictions.get(owner_id)) is not None and item.active
        }

    def list_restrictions(self, limit: int) -> list[MarketplaceRestriction]:
        rows = sorted(self.restrictions.values(), key=lambda item: item.created_at, reverse=True)
        return rows[:limit]

    def log_moderation_access(self, access: ModerationAccess) -> None:
        self.moderation_accesses.append(access)

    def list_moderation_accesses(self, report_id: str) -> list[ModerationAccess]:
        rows = [item for item in self.moderation_accesses if item.report_id == report_id]
        return sorted(rows, key=lambda item: item.accessed_at, reverse=True)
