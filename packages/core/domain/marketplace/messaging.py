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
# Who wrote, once that person deleted the account and the conversation was kept
# because it is under review (owner decision 2026-11-08, legal opinion
# docs/compliance/10 §2.3): the account id is replaced by the role.
DELETED_PARTICIPANT_IDS: dict[str, str] = {"buyer": "deleted-buyer", "seller": "deleted-seller"}
# A kept conversation lasts this long after the team's decision on the report.
KEPT_AFTER_DECISION_DAYS = 365
# Report states that keep a conversation after an account deletion: still open,
# or upheld by the team ("resolved"). A dismissed report keeps nothing.
KEEPING_REPORT_STATUSES = frozenset({"open", "resolved"})
# Why the app says a conversation cannot be written to. A block by the other
# person, or the team's restriction of the other person, is deliberately reported
# as "closed", so nobody learns about it; "restricted" is said only to the person
# the team restricted.
ConversationClosure = Literal["closed", "blocked_by_me", "restricted"]
ConversationReportReason = Literal["spam", "scam", "harassment", "inappropriate", "other"]
ConversationReportStatus = Literal["open", "dismissed", "resolved"]
# Why the team kept someone out of the Mercatino: a code, so the person reads it
# in their own language; the team's own words go in the note, never shown to them.
MarketplaceRestrictionReason = Literal["spam", "scam", "harassment", "prohibited_items", "other"]


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
    # Set when a participant deleted the account and the conversation was kept for
    # the report under review: only the moderation team sees it from then on.
    erased_participant_at: datetime | None = None
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


class MarketplaceRestriction(BaseModel):
    """The moderation team kept [owner_id] out of the Mercatino: no new ads, no
    edits, no messages. Lifting keeps the row (with who and when) for the record."""

    owner_id: str
    reason: MarketplaceRestrictionReason
    # The team's own words: shown in the portal, never in the app.
    note: str | None = Field(default=None, max_length=1000)
    created_at: datetime = Field(default_factory=utc_now)
    created_by_admin_id: str | None = None
    lifted_at: datetime | None = None
    lifted_by_admin_id: str | None = None

    @property
    def active(self) -> bool:
        return self.lifted_at is None


ModerationAccessAction = Literal["read", "close_conversation", "dismiss_report", "reopen_report"]


class ModerationAccess(BaseModel):
    """One look of the team at a reported conversation, or one decision on it: the
    trail the legal opinion asks for (docs/compliance/10 §2.3, point 5)."""

    id: str = Field(default_factory=new_id)
    admin_id: str
    report_id: str
    conversation_id: str
    action: ModerationAccessAction
    accessed_at: datetime = Field(default_factory=utc_now)
