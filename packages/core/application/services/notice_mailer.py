"""Sending one service e-mail to one owner: the part every notice sequence shares.

Used by the deletion notices (docs/compliance/18) and ready for the 120-day notices
(Pricing). It reads the address at the moment of sending and never keeps it; it never raises;
it answers with an outcome code, never with an address, a subject or a text.

Rules, in the order they are checked:
  1. sending is switched on and the legal wording is configured (company, contact, links);
  2. the account can be reached: an address, confirmed;
  3. an account whose declared age is under the minimum is never written to (closed account);
  4. only Italian exists for now: another language is skipped, not sent in the wrong one;
  5. the recipient rules of the sender (reserved domains, allow-list) have the last word.
A skipped or failed notice is never recorded as sent, so the next run looks at it again.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime

from pydantic import BaseModel, Field

from packages.core.application.ports.email_sender import (
    NOT_SENT,
    REJECTED,
    EmailMessage,
    EmailSender,
)
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.domain.age.models import AgeBand, band_for
from packages.core.domain.exit_notices import layout, texts

logger = logging.getLogger(__name__)

SENT = "sent"
SKIPPED = "skipped"
FAILED = "failed"


@dataclass(frozen=True)
class NoticeConfig:
    """What the texts say about who writes and where to sign in. All of it comes from the
    environment (never from the repository); an empty value means "not configured"."""

    legal_entity: str = ""
    contact: str = ""
    login_url: str = ""
    privacy_url: str = ""
    proof_years: int = 5

    def is_complete(self) -> bool:
        # The wording needs where to sign in and where the privacy notice is. Who writes (company,
        # contact) is NOT required: the e-mails are signed «Il team di Quokka», and the footer
        # shows the company and the contact only if both are configured.
        return bool(
            self.login_url.startswith("https://") and self.privacy_url.startswith("https://")
        )

    def footer_line(self) -> str:
        entity, contact = self.legal_entity.strip(), self.contact.strip()
        return f"Quokka è un servizio di {entity} · {contact}" if entity and contact else ""


@dataclass(frozen=True)
class Recipient:
    """Read just before writing, held in memory for the one send, never stored or logged."""

    address: str = field(repr=False)
    first_name: str | None = field(default=None, repr=False)


@dataclass(frozen=True)
class NoticeOutcome:
    kind: str  # SENT | SKIPPED | FAILED
    reason: str | None = None
    # For a notice that did not go: True when it CERTAINLY did not (safe to try again), False
    # when it may have been delivered anyway (a timeout while handing it over): then it must
    # not be sent again.
    certain: bool = True
    # The recipient or the server refused for good (a mailbox that does not exist, a
    # message the server will never take): trying again is pointless, so it is booked as
    # tried and the sequence goes on (docs/compliance/18 §8.9).
    definitive: bool = False


class NoticeCounts(BaseModel):
    """What a run did, as numbers only."""

    due: int = 0
    sent: int = 0
    skipped: int = 0
    failed: int = 0
    # Not part of `failed`: the message may have gone, so it is never sent again.
    uncertain: int = 0
    # Refused for good: booked as tried, never sent again.
    rejected: int = 0
    # Booked as tried without a confirmed delivery (rejected, uncertain, or a recipient
    # that can never be written to): it counts as done for the sequence.
    attempted: int = 0
    # Notices that should have gone by now and have not, by name: numbers for the team.
    overdue: dict[str, int] = Field(default_factory=dict)
    skipped_by_reason: dict[str, int] = Field(default_factory=dict)
    # Stopped before sending: "sending_off", "not_configured", "no_notice_log", "record_failed".
    blocked: str | None = None
    # Not sent this run because the cap of the run was reached (next run).
    postponed: int = 0

    def add(self, outcome: NoticeOutcome) -> None:
        if outcome.kind == SENT:
            self.sent += 1
        elif outcome.kind == SKIPPED:
            self.skipped += 1
            reason = outcome.reason or "unknown"
            self.skipped_by_reason[reason] = self.skipped_by_reason.get(reason, 0) + 1
        elif not outcome.certain:
            self.uncertain += 1
            self.attempted += 1
        elif outcome.definitive:
            self.rejected += 1
            self.attempted += 1
        else:
            self.failed += 1


class SendBudget:
    """How many e-mails one run may send: the mailbox has a daily limit, and so does the time
    a scheduled call may take. Shared by every sequence of the run."""

    def __init__(self, limit: int) -> None:
        self._left = limit

    @property
    def left(self) -> int:
        return self._left

    @property
    def exhausted(self) -> bool:
        return self._left <= 0

    def spend(self) -> None:
        """One real attempt was made (a skipped notice costs nothing)."""
        self._left -= 1


# What the sender says when a message must not go out for a reason that is not a failure.
_SKIP_REASONS = frozenset({"disabled", "reserved_recipient", "recipient_not_allowed"})


class NoticeMailer:
    def __init__(
        self,
        sender: EmailSender,
        contacts: OwnerContactLookup,
        config: NoticeConfig,
        enabled: bool,
        recipient_check: Callable[[str], str | None] | None = None,
        logo: bytes = b"",
    ) -> None:
        self._logo = logo
        self._recipient_check = recipient_check
        self._sender = sender
        self._contacts = contacts
        self._config = config
        self._enabled = enabled

    # -- state -----------------------------------------------------------------------------

    @property
    def enabled(self) -> bool:
        return self._enabled

    @property
    def ready(self) -> bool:
        """Switched on AND the legal wording is configured."""
        return self._enabled and self._config.is_complete()

    @property
    def blocked_reason(self) -> str | None:
        if not self._enabled:
            return "sending_off"
        if not self._config.is_complete():
            return "not_configured"
        return None

    @property
    def config(self) -> NoticeConfig:
        return self._config

    # -- who ---------------------------------------------------------------------------------

    def recipient_for(self, owner_id: str, now: datetime | None = None) -> Recipient | str:
        """The person to write to, or the reason not to ("no_contact", "no_address",
        "unconfirmed", "closed_by_age", "language_not_ready")."""
        contact = self._contacts.get(owner_id)
        if contact is None:
            return "no_contact"
        if not contact.email:
            return "no_address"
        if not contact.email_confirmed:
            return "unconfirmed"
        today = (now or datetime.now(UTC)).date()
        if contact.birth_date is not None and band_for(contact.birth_date, today) == (
            AgeBand.UNDER_MINIMUM
        ):
            return "closed_by_age"
        if (contact.language or texts.LANGUAGE).lower().split("-")[0] != texts.LANGUAGE:
            return "language_not_ready"
        if self._recipient_check is not None:
            refused = self._recipient_check(contact.email)
            if refused:
                return refused
        return Recipient(address=contact.email, first_name=contact.display_name)

    # -- sending -----------------------------------------------------------------------------

    def deliver(
        self, recipient: Recipient, template_id: str, variables: dict[str, str]
    ) -> NoticeOutcome:
        """Writes one notice. Never raises. [variables] are the ones of the text (dates,
        durations); the greeting, the company, the contact and the links are added here."""
        if not self.ready:
            return NoticeOutcome(SKIPPED, self.blocked_reason)
        try:
            rendered = layout.render_email(
                template_id,
                {
                    **variables,
                    "saluto": texts.greeting(recipient.first_name),
                    "link_informativa": self._config.privacy_url,
                    "anni_registro": str(self._config.proof_years),
                },
                login_url=self._config.login_url,
                footer_line=self._config.footer_line(),
            )
            message = EmailMessage(
                to=recipient.address,
                subject=rendered.subject,
                text=rendered.text,
                html=rendered.html,
                inline_images={layout.LOGO_CID: self._logo} if self._logo else {},
                category="service",
            )
        except Exception:  # noqa: BLE001 - nothing reached the sender: it is safe to try again
            logger.warning("an exit notice could not be written", exc_info=False)
            return NoticeOutcome(FAILED, "exception")
        try:
            result = self._sender.send(message)
        except Exception:  # noqa: BLE001 - the sender broke at an unknown point: it may have gone
            logger.warning("an exit notice may not have been sent", exc_info=False)
            return NoticeOutcome(FAILED, "uncertain", certain=False)
        if result.sent:
            return NoticeOutcome(SENT)
        if result.reason in _SKIP_REASONS:
            return NoticeOutcome(SKIPPED, result.reason)
        if result.reason == NOT_SENT:
            return NoticeOutcome(FAILED, result.reason)
        if result.reason in (REJECTED, "invalid"):
            return NoticeOutcome(FAILED, result.reason, definitive=True)
        # "uncertain", or a reason nobody planned: it may have been delivered, so it stays booked.
        return NoticeOutcome(FAILED, result.reason or "uncertain", certain=False)

    def send_to_owner(
        self,
        owner_id: str,
        template_id: str,
        variables: dict[str, str],
        now: datetime | None = None,
    ) -> NoticeOutcome:
        """Looks the owner up and writes. Nothing is read when sending is off."""
        if not self.ready:
            return NoticeOutcome(SKIPPED, self.blocked_reason)
        try:
            recipient = self.recipient_for(owner_id, now)
        except Exception:  # noqa: BLE001 - a failed lookup is a failure, not "no address"
            logger.warning("could not read the contact of an account", exc_info=False)
            return NoticeOutcome(FAILED, "contact_lookup")
        if isinstance(recipient, str):
            return NoticeOutcome(SKIPPED, recipient)
        return self.deliver(recipient, template_id, variables)


def deliver_booked(
    mailer: NoticeMailer,
    owner_id: str,
    now: datetime,
    template_id: str,
    variables: dict[str, str],
    *,
    book: Callable[[], bool],
    release: Callable[[], None],
    counts: NoticeCounts,
    budget: SendBudget,
    attempted_when: frozenset[str] = frozenset(),
) -> bool:
    """One notice of a sequence, booked BEFORE it is sent so two runs can never both send it.

    1. who: an account that cannot or must not be written to is counted as skipped and nothing
       is booked;
    2. [book] is a conditional update on the row: if it does not succeed somebody else has the
       notice, and nothing is sent;
    3. the message goes; if it CERTAINLY did not go (refused before sending, or by the server)
       the booking is given back and the next run tries again; if it did go the booking
       stays; if the outcome is UNCERTAIN (a timeout while handing it over) the booking also
       stays and it is not sent again.

    A recipient who can NEVER be written to ([attempted_when]: no address, a reserved
    domain) is booked as tried without sending, so a sequence that waits for the notice
    (the pause) does not wait for ever. A refusal for good by the server is kept too.

    Returns False when the run must stop (the booking cannot be written or given back)."""
    try:
        recipient = mailer.recipient_for(owner_id, now)
    except Exception:  # noqa: BLE001 - a failed lookup is a failure, not "no address"
        logger.warning("could not read the contact of an account", exc_info=False)
        counts.add(NoticeOutcome(FAILED, "contact_lookup"))
        return True
    if isinstance(recipient, str):
        counts.add(NoticeOutcome(SKIPPED, recipient))
        if recipient not in attempted_when:
            return True
        try:
            if book():
                counts.attempted += 1
        except Exception:  # noqa: BLE001 - see below
            logger.warning("could not book an exit notice", exc_info=False)
            counts.blocked = "record_failed"
            return False
        return True
    try:
        booked = book()
    except Exception:  # noqa: BLE001 - without a booking the notice would be sent again and again
        logger.warning("could not book an exit notice", exc_info=False)
        counts.blocked = "record_failed"
        return False
    if not booked:
        counts.add(NoticeOutcome(SKIPPED, "already_booked"))
        return True
    outcome = mailer.deliver(recipient, template_id, variables)
    counts.add(outcome)
    if outcome.kind != SKIPPED:
        budget.spend()
    if outcome.kind == SENT or not outcome.certain or outcome.definitive:
        return True
    try:
        release()
    except Exception:  # noqa: BLE001 - the notice would stay booked without having been sent
        logger.warning("could not give back an exit notice", exc_info=False)
        counts.blocked = "release_failed"
        return False
    return True
