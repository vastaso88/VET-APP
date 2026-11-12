from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.account_eraser import AccountEraser, ErasureReport
from packages.shared.errors.base import AuthenticationError

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


class DeleteAccountService:
    """Right to erasure (GDPR art. 17, App Store 5.1.1(v), Google Play account
    deletion policy): the owner's data first, the sign-in identity last.
    If anything fails before the identity is removed, the owner can still
    sign in and ask again."""

    def __init__(self, eraser: AccountEraser) -> None:
        self._eraser = eraser

    def execute(self, data: DeleteAccountInput) -> ErasureReport:
        now = data.now or datetime.now(UTC)
        if data.signed_in_at is None or now - data.signed_in_at > RECENT_SIGN_IN_WINDOW:
            raise RecentSignInRequired("Riaccedi per confermare l'eliminazione dell'account.")
        report = self._eraser.erase_data(data.owner_id)
        self._eraser.delete_identity(data.owner_id)
        return report
