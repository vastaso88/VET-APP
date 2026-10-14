from pydantic import BaseModel

from packages.core.application.ports.account_eraser import AccountEraser, ErasureReport


class DeleteAccountInput(BaseModel):
    owner_id: str


class DeleteAccountService:
    """Right to erasure (GDPR art. 17, App Store 5.1.1(v), Google Play account
    deletion policy): the owner's data first, the sign-in identity last.
    If anything fails before the identity is removed, the owner can still
    sign in and ask again."""

    def __init__(self, eraser: AccountEraser) -> None:
        self._eraser = eraser

    def execute(self, data: DeleteAccountInput) -> ErasureReport:
        report = self._eraser.erase_data(data.owner_id)
        self._eraser.delete_identity(data.owner_id)
        return report
