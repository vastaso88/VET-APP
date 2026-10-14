from typing import Protocol

from pydantic import BaseModel, Field


class ErasureReport(BaseModel):
    """What an account deletion removed, for the API response and the logs.
    Counts only, never the content."""

    rows_deleted: dict[str, int] = Field(default_factory=dict)
    files_removed: int = 0


class AccountEraser(Protocol):
    def erase_data(self, owner_id: str) -> ErasureReport:
        """Removes everything the owner created (rows and stored files).
        Idempotent: running it again on an already erased owner is a no-op."""
        ...

    def delete_identity(self, owner_id: str) -> None:
        """Removes the sign-in identity itself. Called only after
        [erase_data] succeeded, so a failure there leaves the account usable
        and the deletion can simply be retried."""
        ...
