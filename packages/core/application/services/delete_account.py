import logging
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_eraser import AccountEraser, ErasureReport
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.application.services.notice_mailer import NoticeMailer, Recipient
from packages.core.domain.account_deletion.log import DeletionReason
from packages.shared.errors.base import AuthenticationError

logger = logging.getLogger(__name__)

# The app signs the owner in again with their password right before asking,
# so a legitimate request always carries a fresh sign-in.
RECENT_SIGN_IN_WINDOW = timedelta(minutes=5)


class RecentSignInRequired(AuthenticationError):
    """The token is valid but the sign-in behind it is too old to delete an account."""


class DeleteAccountInput(BaseModel):
    owner_id: str
    # When the caller last signed in with their credentials; None = unknown.
    signed_in_at: datetime | None = None
    now: datetime | None = None
    # Why it is erased, for the register of deletions (a closed under-age
    # account that its owner erases says so).
    reason: str = DeletionReason.USER_NOW


class DeleteAccountService:
    """Right to erasure (GDPR art. 17, App Store 5.1.1(v), Google Play account
    deletion policy): the owner's data first, the sign-in identity last.
    If anything fails before the identity is removed, the owner can still
    sign in and ask again."""

    def __init__(
        self,
        eraser: AccountEraser,
        log: DeletionLogService | None = None,
        mailer: NoticeMailer | None = None,
    ) -> None:
        self._eraser = eraser
        self._log = log
        self._mailer = mailer

    def execute(
        self,
        data: DeleteAccountInput,
        defer: Callable[[Callable[[], None]], None] | None = None,
    ) -> ErasureReport:
        """Erases the account. For «Elimina subito» (the owner's own request, never an account
        closed for age) the closing e-mail (D4, docs/compliance/18 §5) is written after the
        erase to the address read BEFORE it; [defer], when given, is how the caller runs
        it after the answer (a background task), so the e-mail can never delay or fail the
        deletion. Without [defer] it runs here, and still never raises."""
        now = data.now or datetime.now(UTC)
        if data.signed_in_at is None or now - data.signed_in_at > RECENT_SIGN_IN_WINDOW:
            raise RecentSignInRequired("Riaccedi per confermare l'eliminazione dell'account.")
        recipient = self._recipient_before_erase(data, now)
        if self._log is not None:
            report = self._log.erase_account(self._eraser, data.owner_id, data.reason, now)
        else:
            report = self._eraser.erase_data(data.owner_id)
            self._eraser.delete_identity(data.owner_id)
        if recipient is not None:
            send = lambda: self._send_closing(recipient)  # noqa: E731
            if defer is not None:
                defer(send)
            else:
                send()
        return report

    def _recipient_before_erase(self, data: DeleteAccountInput, now: datetime) -> Recipient | None:
        # Only the owner's own immediate deletion writes the closing e-mail: an account closed
        # for age (under 14) never gets any.
        if data.reason != DeletionReason.USER_NOW:
            return None
        if self._mailer is None or not self._mailer.ready:
            return None
        try:
            found = self._mailer.recipient_for(data.owner_id, now)
        except Exception:  # noqa: BLE001 - the erase goes on without it
            return None
        return found if isinstance(found, Recipient) else None

    def _send_closing(self, recipient: Recipient) -> None:
        if self._mailer is None:
            return
        try:
            self._mailer.deliver(recipient, "D4", {})
        except Exception:  # noqa: BLE001 - the deletion is done; this is only a courtesy
            logger.warning("the closing e-mail could not be sent", exc_info=False)
