"""In-app messages of the Mercatino: a buyer writes to the seller of one ad and
neither learns the other's phone number, e-mail or account id. The owner chose
this on 2026-11-07 over a phone field and a masked e-mail."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now

MESSAGE_MAX_LENGTH = 1000
# The thread shows the most recent messages; the list the most recent chats.
THREAD_MESSAGES_LIMIT = 200
CONVERSATIONS_LIST_LIMIT = 100
# An ad in these states still accepts messages. Anything else (sold, removed,
# hidden by the animal rule, or the ad deleted) leaves the conversation readable.
WRITABLE_LISTING_STATUSES = frozenset({"active", "reserved"})

ParticipantRole = Literal["buyer", "seller"]
# Why the app says a conversation cannot be written to. A block by the other
# person is deliberately reported as "closed", so nobody learns they were blocked.
ConversationClosure = Literal["closed", "blocked_by_me"]
ConversationReportReason = Literal["spam", "scam", "harassment", "inappropriate", "other"]
ConversationReportStatus = Literal["open", "dismissed", "resolved"]


class MarketplaceConversation(BaseModel):
    id: str = Field(default_factory=new_id)
    # Null once the ad has been deleted: the title below keeps the thread readable.
    listing_id: str | None
    listing_title: str
    buyer_id: str
    seller_id: str
    buyer_unread: int = 0
    seller_unread: int = 0
    # Set by the team from the moderation portal: nobody can write any more.
    moderation_closed_at: datetime | None = None
    created_at: datetime = Field(default_factory=utc_now)
    last_message_at: datetime = Field(default_factory=utc_now)

    def role_of(self, user_id: str) -> ParticipantRole | None:
        if user_id == self.buyer_id:
            return "buyer"
        if user_id == self.seller_id:
            return "seller"
        return None

    def other_participant(self, user_id: str) -> str:
        return self.seller_id if user_id == self.buyer_id else self.buyer_id


class MarketplaceMessage(BaseModel):
    id: str = Field(default_factory=new_id)
    conversation_id: str
    sender_id: str
    body: str
    created_at: datetime = Field(default_factory=utc_now)


class MarketplaceUserBlock(BaseModel):
    blocker_id: str
    blocked_id: str
    created_at: datetime = Field(default_factory=utc_now)


class MarketplaceConversationReport(BaseModel):
    id: str = Field(default_factory=new_id)
    conversation_id: str
    reporter_id: str
    reason: ConversationReportReason
    status: ConversationReportStatus = "open"
    resolution_action: str | None = None
    resolution_note: str | None = None
    resolved_at: datetime | None = None
    resolved_by_admin_id: str | None = None
    created_at: datetime = Field(default_factory=utc_now)
