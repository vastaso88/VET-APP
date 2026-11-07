"""The messages of the Mercatino. Everything an owner can do goes through here,
so the rules do not depend on the app:

* the backend uses the service role, so row-level security does not protect
  these tables: every method takes the caller's id from the token and answers
  [ConversationNotFoundError] to anyone who is not a participant, exactly as for
  an id that does not exist;
* what leaves here never carries an account id: `mine` and `role` are all the app
  needs, so neither side learns who the other one is;
* the seller cannot write first, because a conversation is created only by a
  buyer's message;
* nobody can open a conversation with a seller who could not answer (no active
  plan, or kept out by the team): the refusal looks like any other unavailable
  ad, so whether someone pays is never revealed;
* someone the team kept out of the Mercatino reads but does not write, and is
  told why ([MarketplaceRestrictedError]).
"""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.domain.localization import translate
from packages.core.domain.marketplace.messaging import (
    CONVERSATIONS_LIST_LIMIT,
    MESSAGE_MAX_LENGTH,
    THREAD_MESSAGES_LIMIT,
    WRITABLE_LISTING_STATUSES,
    ConversationClosure,
    ConversationReportReason,
    MarketplaceConversation,
    MarketplaceConversationReport,
    MarketplaceMessage,
    MarketplaceRestriction,
    MarketplaceRestrictionReason,
    MarketplaceUserBlock,
    ParticipantRole,
)
from packages.core.domain.subscription.limits import MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY
from packages.shared.errors.base import (
    MarketplaceRestrictedError,
    QuotaExceededError,
    ValidationError,
    VetAppError,
)


class ConversationNotFoundError(VetAppError):
    """Missing, not the caller's, or not available to them: the same answer."""


class ConversationClosedError(VetAppError):
    """The ad is closed or someone blocked someone: readable, not writable."""


class ConversationView(BaseModel):
    id: str
    listing_id: str | None
    listing_title: str
    role: ParticipantRole
    unread_count: int
    can_write: bool
    closed_reason: ConversationClosure | None
    created_at: datetime
    last_message_at: datetime


class MessageView(BaseModel):
    id: str
    body: str
    mine: bool
    created_at: datetime


class ThreadView(BaseModel):
    conversation: ConversationView
    messages: list[MessageView]


class SentMessage(BaseModel):
    conversation: ConversationView
    message: MessageView


class ListingMessaging(BaseModel):
    """What the ad's page needs: the caller's conversation about it, if any, and
    whether a new one can be opened. `can_start` is false for one reason or
    another (closed ad, own ad, a block, a seller who could not answer) and never
    says which."""

    conversation: ConversationView | None
    can_start: bool


def raise_if_restricted(restriction: MarketplaceRestriction | None) -> None:
    if restriction is not None and restriction.active:
        raise MarketplaceRestrictedError(
            reason=restriction.reason, since=restriction.created_at.isoformat()
        )


class MarketplaceMessagingService:
    def __init__(
        self,
        repository: MarketplaceMessagingRepository,
        listings: MarketplaceListingRepository,
        seller_can_answer: Callable[[str], bool] = lambda _owner_id: True,
    ) -> None:
        self._repository = repository
        self._listings = listings
        # Whether this owner's plan lets them write (trial, plan or public test).
        self._seller_can_answer = seller_can_answer

    def restriction_of(self, owner_id: str) -> MarketplaceRestriction | None:
        """The team's restriction of this owner, only while it is in force."""
        restriction = self._repository.get_restriction(owner_id)
        return restriction if restriction is not None and restriction.active else None

    # -- writing ---------------------------------------------------------

    def start_or_continue(
        self, listing_id: str, buyer_id: str, text: str, locale: str | None
    ) -> SentMessage:
        """The buyer's message about an ad: it opens the conversation the first
        time, then continues the same one. An ad that cannot be written about
        (missing, closed, the caller's own, or its seller blocked the caller)
        gives one answer, so a block cannot be told from a missing ad."""
        body = self._clean(text)
        raise_if_restricted(self._repository.get_restriction(buyer_id))
        existing = self._repository.find_conversation(listing_id, buyer_id)
        if existing is not None:
            return self._send(existing, buyer_id, body)

        listing = self._listings.get(listing_id)
        if listing is None or not self._can_start(listing.owner_id, listing.status, buyer_id):
            raise ConversationNotFoundError

        self._enforce_daily_limit(buyer_id, locale)
        conversation = self._repository.create_conversation(
            MarketplaceConversation(
                listing_id=listing.id,
                listing_title=listing.title,
                buyer_id=buyer_id,
                seller_id=listing.owner_id,
            )
        )
        return self._send(conversation, buyer_id, body)

    def send(self, conversation_id: str, user_id: str, text: str) -> SentMessage:
        body = self._clean(text)
        conversation = self._participant_conversation(conversation_id, user_id)
        raise_if_restricted(self._repository.get_restriction(user_id))
        return self._send(conversation, user_id, body)

    def _send(
        self, conversation: MarketplaceConversation, sender_id: str, body: str
    ) -> SentMessage:
        closure = self._closure(conversation, sender_id)
        if closure == "restricted":
            raise_if_restricted(self._repository.get_restriction(sender_id))
        if closure is not None:
            raise ConversationClosedError

        message = self._repository.add_message(
            MarketplaceMessage(conversation_id=conversation.id, sender_id=sender_id, body=body)
        )
        role = conversation.role_of(sender_id)
        recipient: ParticipantRole = "seller" if role == "buyer" else "buyer"
        unread = (
            conversation.seller_unread if recipient == "seller" else conversation.buyer_unread
        ) + 1
        self._repository.record_message(conversation.id, message.created_at, recipient, unread)
        updated = conversation.model_copy(
            update={
                "last_message_at": message.created_at,
                f"{recipient}_unread": unread,
            }
        )
        return SentMessage(
            conversation=self._view(updated, sender_id),
            message=self._message_view(message, sender_id),
        )

    # -- reading ---------------------------------------------------------

    def find_for_listing(self, listing_id: str, buyer_id: str) -> ListingMessaging:
        """The caller's own conversation about an ad, if they ever wrote, and
        whether they could open one now."""
        conversation = self._repository.find_conversation(listing_id, buyer_id)
        if conversation is not None:
            return ListingMessaging(
                conversation=self._view(conversation, buyer_id), can_start=False
            )
        listing = self._listings.get(listing_id)
        can_start = (
            listing is not None
            and self.restriction_of(buyer_id) is None
            and self._can_start(listing.owner_id, listing.status, buyer_id)
        )
        return ListingMessaging(conversation=None, can_start=can_start)

    def list_conversations(self, user_id: str) -> list[ConversationView]:
        conversations = self._repository.list_conversations(user_id, CONVERSATIONS_LIST_LIMIT)
        statuses = self._listings.statuses(
            [item.listing_id for item in conversations if item.listing_id is not None]
        )
        blocks = self._repository.blocks_involving(user_id)
        restricted = self._repository.restricted_among(
            [user_id, *(item.other_participant(user_id) for item in conversations)]
        )
        return [
            self._view(item, user_id, statuses=statuses, blocks=blocks, restricted=restricted)
            for item in conversations
        ]

    def unread_total(self, user_id: str) -> int:
        return self._repository.unread_total(user_id)

    def thread(self, conversation_id: str, user_id: str) -> ThreadView:
        conversation = self._participant_conversation(conversation_id, user_id)
        messages = self._repository.list_messages(conversation.id, THREAD_MESSAGES_LIMIT)
        return ThreadView(
            conversation=self._view(conversation, user_id),
            messages=[self._message_view(item, user_id) for item in messages],
        )

    def mark_read(self, conversation_id: str, user_id: str) -> None:
        conversation = self._participant_conversation(conversation_id, user_id)
        role = conversation.role_of(user_id)
        if role is not None:
            self._repository.clear_unread(conversation.id, role)

    # -- safety ----------------------------------------------------------

    def block(self, conversation_id: str, user_id: str) -> ConversationView:
        conversation = self._participant_conversation(conversation_id, user_id)
        self._repository.add_block(
            MarketplaceUserBlock(
                blocker_id=user_id, blocked_id=conversation.other_participant(user_id)
            )
        )
        return self._view(conversation, user_id)

    def unblock(self, conversation_id: str, user_id: str) -> ConversationView:
        conversation = self._participant_conversation(conversation_id, user_id)
        self._repository.remove_block(user_id, conversation.other_participant(user_id))
        return self._view(conversation, user_id)

    def report(
        self, conversation_id: str, user_id: str, reason: ConversationReportReason
    ) -> MarketplaceConversationReport:
        """One report per person per conversation: reporting twice changes nothing."""
        conversation = self._participant_conversation(conversation_id, user_id)
        existing = self._repository.find_report(conversation.id, user_id)
        if existing is not None:
            return existing
        return self._repository.save_report(
            MarketplaceConversationReport(
                conversation_id=conversation.id, reporter_id=user_id, reason=reason
            )
        )

    # -- rules -----------------------------------------------------------

    @staticmethod
    def _clean(text: str) -> str:
        body = text.strip()
        if not body:
            raise ValidationError("message is empty")
        if len(body) > MESSAGE_MAX_LENGTH:
            raise ValidationError("message is too long")
        return body

    def _participant_conversation(
        self, conversation_id: str, user_id: str
    ) -> MarketplaceConversation:
        conversation = self._repository.get_conversation(conversation_id)
        if conversation is None or conversation.role_of(user_id) is None:
            raise ConversationNotFoundError
        return conversation

    def _can_start(self, seller_id: str, listing_status: str, buyer_id: str) -> bool:
        """A new conversation needs an open ad of someone else, no block between
        the two, and a seller who could answer."""
        return (
            listing_status == "active"
            and seller_id != buyer_id
            and not self._blocked_either_way(buyer_id, seller_id)
            and self.restriction_of(seller_id) is None
            and self._seller_can_answer(seller_id)
        )

    def _blocked_either_way(self, user_id: str, other_id: str) -> bool:
        return any(
            other_id in (block.blocker_id, block.blocked_id)
            for block in self._repository.blocks_involving(user_id)
        )

    def _enforce_daily_limit(self, buyer_id: str, locale: str | None) -> None:
        now = datetime.now(UTC)
        window = timedelta(days=1)
        started = self._repository.conversation_start_times(buyer_id, now - window)
        if len(started) < MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY:
            return
        retry_after = int((min(started) + window - now).total_seconds())
        raise QuotaExceededError(
            "marketplace_new_conversations",
            limit=MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY,
            retry_after_seconds=max(retry_after, 1),
            message=translate(
                "marketplace_new_conversations_limit",
                locale,
                limit=MAX_NEW_MARKETPLACE_CONVERSATIONS_PER_DAY,
            ),
        )

    def _closure(
        self,
        conversation: MarketplaceConversation,
        user_id: str,
        *,
        statuses: dict[str, str] | None = None,
        blocks: list[MarketplaceUserBlock] | None = None,
        restricted: set[str] | None = None,
    ) -> ConversationClosure | None:
        other = conversation.other_participant(user_id)
        if restricted is None:
            restricted = self._repository.restricted_among([user_id, other])
        if user_id in restricted:
            return "restricted"
        if other in restricted:
            return "closed"
        if blocks is None:
            blocks = self._repository.blocks_involving(user_id)
        if any(b.blocker_id == user_id and b.blocked_id == other for b in blocks):
            return "blocked_by_me"
        if any(b.blocker_id == other and b.blocked_id == user_id for b in blocks):
            return "closed"
        if conversation.moderation_closed_at is not None or conversation.listing_id is None:
            return "closed"
        if statuses is None:
            statuses = self._listings.statuses([conversation.listing_id])
        if statuses.get(conversation.listing_id) not in WRITABLE_LISTING_STATUSES:
            return "closed"
        return None

    def _view(
        self,
        conversation: MarketplaceConversation,
        user_id: str,
        *,
        statuses: dict[str, str] | None = None,
        blocks: list[MarketplaceUserBlock] | None = None,
        restricted: set[str] | None = None,
    ) -> ConversationView:
        role = conversation.role_of(user_id)
        if role is None:
            raise ConversationNotFoundError
        closure = self._closure(
            conversation, user_id, statuses=statuses, blocks=blocks, restricted=restricted
        )
        return ConversationView(
            id=conversation.id,
            listing_id=conversation.listing_id,
            listing_title=conversation.listing_title,
            role=role,
            unread_count=(
                conversation.buyer_unread if role == "buyer" else conversation.seller_unread
            ),
            can_write=closure is None,
            closed_reason=closure,
            created_at=conversation.created_at,
            last_message_at=conversation.last_message_at,
        )

    @staticmethod
    def _message_view(message: MarketplaceMessage, user_id: str) -> MessageView:
        return MessageView(
            id=message.id,
            body=message.body,
            mine=message.sender_id == user_id,
            created_at=message.created_at,
        )


class MarketplaceMessagingModerationService:
    """The portal's queue of reported conversations. The team reads a thread
    only here, only after one of the two participants reported it (the app says
    so in the report dialog). Admin check: apps/api/routes/admin.py."""

    def __init__(self, repository: MarketplaceMessagingRepository) -> None:
        self._repository = repository

    def queue(self, limit: int = 100) -> list[dict[str, object]]:
        rows: list[dict[str, object]] = []
        for report in self._repository.list_reports(limit):
            conversation = self._repository.get_conversation(report.conversation_id)
            rows.append(
                {
                    **report.model_dump(mode="json"),
                    "listing_title": conversation.listing_title if conversation else None,
                }
            )
        return rows

    def detail(self, report_id: str) -> dict[str, object] | None:
        report = self._repository.get_report(report_id)
        if report is None:
            return None
        conversation = self._repository.get_conversation(report.conversation_id)
        messages = (
            self._repository.list_messages(conversation.id, THREAD_MESSAGES_LIMIT)
            if conversation is not None
            else []
        )
        return {
            **report.model_dump(mode="json"),
            "conversation": conversation.model_dump(mode="json") if conversation else None,
            "messages": [
                {
                    "id": message.id,
                    "body": message.body,
                    "created_at": message.created_at.isoformat(),
                    "role": conversation.role_of(message.sender_id) if conversation else None,
                }
                for message in messages
            ],
        }

    def resolve(
        self, report_id: str, action: str, note: str | None, admin_id: str
    ) -> MarketplaceConversationReport | None:
        report = self._repository.get_report(report_id)
        if report is None:
            return None
        now = datetime.now(UTC)
        updates: dict[str, object] = {
            "resolution_note": note,
            "resolved_by_admin_id": admin_id,
            "resolved_at": now,
            "resolution_action": action,
        }
        if action == "close_conversation":
            self._repository.set_moderation_closed(report.conversation_id, now)
            updates["status"] = "resolved"
        elif action == "dismiss_report":
            updates["status"] = "dismissed"
        else:  # reopen_report: as if never handled, conversation open again
            self._repository.set_moderation_closed(report.conversation_id, None)
            updates.update({"status": "open", "resolved_at": None, "resolution_action": None})
        return self._repository.save_report(report.model_copy(update=updates))

    # -- keeping someone out of the Mercatino --------------------------------

    def restrictions(self, limit: int = 200) -> list[dict[str, object]]:
        return [item.model_dump(mode="json") for item in self._repository.list_restrictions(limit)]

    def restrict(
        self,
        owner_id: str,
        reason: MarketplaceRestrictionReason,
        note: str | None,
        admin_id: str,
    ) -> MarketplaceRestriction:
        """From now on [owner_id] cannot publish, edit an ad or write a message.
        Restricting again replaces the reason and the date."""
        return self._repository.save_restriction(
            MarketplaceRestriction(
                owner_id=owner_id,
                reason=reason,
                note=note.strip() if note and note.strip() else None,
                created_by_admin_id=admin_id,
            )
        )

    def lift(self, owner_id: str, admin_id: str) -> MarketplaceRestriction | None:
        restriction = self._repository.get_restriction(owner_id)
        if restriction is None:
            return None
        if not restriction.active:
            return restriction
        return self._repository.save_restriction(
            restriction.model_copy(
                update={"lifted_at": datetime.now(UTC), "lifted_by_admin_id": admin_id}
            )
        )
