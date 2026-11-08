from datetime import datetime
from typing import Protocol

from packages.core.domain.marketplace.messaging import (
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceRestriction,
    MarketplaceUserBlock,
    ModerationAccess,
    ParticipantRole,
)


class MarketplaceMessagingRepository(Protocol):
    def find_conversation(
        self, listing_id: str, buyer_id: str
    ) -> MarketplaceConversation | None: ...

    def get_conversation(self, conversation_id: str) -> MarketplaceConversation | None: ...

    def create_conversation(self, conversation: MarketplaceConversation) -> MarketplaceConversation:
        """Returns the stored row: when two requests race for the same ad and
        buyer, the one that got there first."""
        ...

    def list_conversations(self, user_id: str, limit: int) -> list[MarketplaceConversation]:
        """As buyer or seller, the most recently active first."""
        ...

    def conversation_start_times(self, buyer_id: str, since: datetime) -> list[datetime]: ...

    def unread_total(self, user_id: str) -> int: ...

    def add_message(self, message: MarketplaceMessage) -> MarketplaceMessage: ...

    def list_messages(self, conversation_id: str, limit: int) -> list[MarketplaceMessage]:
        """The most recent [limit] messages, oldest first."""
        ...

    def record_message(
        self, conversation_id: str, at: datetime, recipient: ParticipantRole, unread: int
    ) -> None: ...

    def clear_unread(self, conversation_id: str, role: ParticipantRole) -> None: ...

    def set_moderation_closed(self, conversation_id: str, at: datetime | None) -> None: ...

    def blocks_involving(self, user_id: str) -> list[MarketplaceUserBlock]: ...

    def add_block(self, block: MarketplaceUserBlock) -> None: ...

    def remove_block(self, blocker_id: str, blocked_id: str) -> None: ...

    def find_report(
        self, conversation_id: str, reporter_id: str
    ) -> MarketplaceConversationReport | None: ...

    def get_report(self, report_id: str) -> MarketplaceConversationReport | None: ...

    def save_report(
        self, report: MarketplaceConversationReport
    ) -> MarketplaceConversationReport: ...

    def list_reports(self, limit: int) -> list[MarketplaceConversationReport]:
        """For the moderation queue, the most recent first."""
        ...

    def get_restriction(self, owner_id: str) -> MarketplaceRestriction | None: ...

    def save_restriction(self, restriction: MarketplaceRestriction) -> MarketplaceRestriction: ...

    def restricted_among(self, owner_ids: list[str]) -> set[str]:
        """Which of [owner_ids] the team currently keeps out of the Mercatino."""
        ...

    def list_restrictions(self, limit: int) -> list[MarketplaceRestriction]:
        """For the portal, the most recent first, lifted ones included."""
        ...

    def log_moderation_access(self, access: ModerationAccess) -> None: ...

    def list_moderation_accesses(self, report_id: str) -> list[ModerationAccess]:
        """The trail of one report, the most recent first."""
        ...
