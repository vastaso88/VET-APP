"""The e-mail seven days before a yearly plan renews (owner decision of 25 November 2026).

A service message, with the same machinery, the same switch (EMAIL_SENDING_ENABLED, off by
default) and the same rules as the exit e-mails (`notice_mailer`). For each yearly renewal that
is exactly seven days away:

  1. not booked yet for this renewal (register of the store events, inserted once);
  2. the owner may have a paid plan: an adult, or a minor with a parent's confirmation;
  3. the STORE is asked again, right then: still yearly, active, renewing, on that day. Whoever
     cancelled a minute ago gets nothing;
  4. the amount is the one the store states in that answer. If it does not state it, nothing is
     sent («amount_unknown»): no amount is ever computed or taken from the app;
  5. only then the notice is booked and written, in the language of the account.

Numbers only in the answer and in the logs: no address, no text, no id, no amount.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime
from functools import partial

from packages.core.application.ports.renewal_notice_log import RenewalNoticeLog
from packages.core.application.ports.store_billing import (
    StoreEntitlementRepository,
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.application.services.notice_mailer import (
    FAILED,
    SKIPPED,
    NoticeCounts,
    NoticeMailer,
    NoticeOutcome,
    Recipient,
    SendBudget,
    send_booked,
)
from packages.core.application.services.store_billing import (
    StoreBillingService,
    UnknownProductError,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.exit_notices import layout
from packages.core.domain.localization import SUPPORTED_LOCALES
from packages.core.domain.subscription import renewal_notice
from packages.core.domain.subscription.store import StoreEntitlement, StorePrice

logger = logging.getLogger(__name__)


class RenewalNoticeService:
    def __init__(
        self,
        billing: StoreBillingService,
        entitlements: StoreEntitlementRepository,
        log: RenewalNoticeLog,
        mailer: NoticeMailer,
        paid_plan_allowed: Callable[[str], bool],
    ) -> None:
        self._billing = billing
        self._entitlements = entitlements
        self._log = log
        self._mailer = mailer
        self._paid_plan_allowed = paid_plan_allowed

    def send_notices(
        self, now: datetime | None = None, budget: SendBudget | None = None
    ) -> NoticeCounts:
        """Never raises: the exit e-mails of the same run must not depend on this one. With
        sending off (or the wording not configured) it only counts: no store is asked."""
        now = now or utc_now()
        counts = NoticeCounts()
        try:
            due = [
                e
                for e in self._log.yearly_renewing_between(*renewal_notice.renewal_day(now))
                if renewal_notice.is_due(e, now)
                and not self._log.booked_since(
                    e.store, e.store_subscription_id, now - renewal_notice.SAME_PERIOD
                )
            ]
        except Exception:  # noqa: BLE001 - a read that failed is told as a number, never raised
            logger.warning("could not read the yearly renewals", exc_info=False)
            counts.blocked = "read_failed"
            return counts
        counts.due = len(due)
        if not self._mailer.ready:
            counts.blocked = self._mailer.blocked_reason
            return counts
        budget = budget or SendBudget(len(due))
        for entitlement in due:
            if budget.exhausted:
                counts.postponed += 1
                continue
            outcome = self._ask_the_store(entitlement, now)
            if isinstance(outcome, NoticeOutcome):
                counts.add(outcome)
                continue
            renews_on, price = outcome
            keep_going = send_booked(
                self._mailer,
                entitlement.owner_id,
                now,
                partial(self._send, entitlement, renews_on, price),
                book=partial(self._book, entitlement, now),
                release=partial(
                    self._log.release,
                    entitlement.store,
                    renewal_notice.event_id(entitlement),
                    entitlement.owner_id,
                ),
                counts=counts,
                budget=budget,
                languages=SUPPORTED_LOCALES,
            )
            if not keep_going:
                break
        return counts

    def _ask_the_store(
        self, entitlement: StoreEntitlement, now: datetime
    ) -> tuple[datetime, StorePrice] | NoticeOutcome:
        """The day and the amount the store confirms now, or why nothing is sent."""
        try:
            if not self._paid_plan_allowed(entitlement.owner_id):
                return NoticeOutcome(SKIPPED, "paid_plan_not_allowed")
            purchase, product = self._billing.store_says(entitlement)
        except StoreTemporaryError:
            return NoticeOutcome(SKIPPED, "store_unavailable")
        except (StoreRejectedError, UnknownProductError):
            return NoticeOutcome(SKIPPED, "store_rejected")
        except Exception:  # noqa: BLE001 - one subscription must not stop the others
            logger.warning("could not check a yearly renewal with its store", exc_info=False)
            return NoticeOutcome(FAILED, "exception")
        confirmed = entitlement.model_copy(
            update={
                "period": product.period,
                "state": purchase.state,
                "auto_renew": purchase.auto_renew,
                "expires_at": purchase.expires_at,
            }
        )
        if not renewal_notice.is_due(confirmed, now) or confirmed.expires_at is None:
            return NoticeOutcome(SKIPPED, "not_renewing")
        if purchase.renewal_price is None:
            return NoticeOutcome(SKIPPED, "amount_unknown")
        return confirmed.expires_at, purchase.renewal_price

    def _book(self, entitlement: StoreEntitlement, now: datetime) -> bool:
        return self._entitlements.record_event(
            event_id=renewal_notice.event_id(entitlement),
            store=entitlement.store,
            notification_type=renewal_notice.EVENT_TYPE,
            owner_id=entitlement.owner_id,
            store_subscription_id=entitlement.store_subscription_id,
            signed_at=now,
            outcome="notice_booked",
        )

    def _send(
        self,
        entitlement: StoreEntitlement,
        renews_on: datetime,
        price: StorePrice,
        recipient: Recipient,
    ) -> NoticeOutcome:
        def render() -> layout.RenderedEmail:
            subject, paragraphs = renewal_notice.compose(
                recipient.language,
                first_name=recipient.first_name,
                renews_on=renews_on,
                price=price,
                store=entitlement.store,
            )
            return layout.render_message(
                subject,
                paragraphs,
                language=recipient.language,
                footer_line=self._mailer.config.footer_line(recipient.language),
            )

        return self._mailer.deliver_rendered(recipient, render)
