from datetime import datetime
from typing import Any, Protocol

from pydantic import BaseModel, Field

EXPORT_FORMAT_VERSION = "1"


class ExportedFile(BaseModel):
    """A stored file of the owner, reachable for a short while through a
    signed link (no login needed on the link itself, so it must expire)."""

    bucket: str
    path: str
    # "chat_attachment" (chat/medical-record upload), "pet_media" (gallery
    # photo or video), "profile_photo".
    kind: str
    url: str | None = None
    url_expires_at: datetime | None = None
    # Why there is no url (bucket unreachable, file already gone...).
    note: str | None = None


class AccountExport(BaseModel):
    """Everything the service holds about one owner (GDPR art. 15 access,
    art. 20 portability), as plain JSON. Tables are exported row by row with
    their real column names so the output stays truthful and needs no
    mapping layer that could silently drop a field."""

    format_version: str = EXPORT_FORMAT_VERSION
    generated_at: datetime
    owner_id: str
    # Sign-in identity: e-mail, display name, optional phone and the other
    # profile fields the identity provider keeps.
    account: dict[str, Any] = Field(default_factory=dict)
    # table name -> rows (every table the account deletion would erase).
    data: dict[str, list[dict[str, Any]]] = Field(default_factory=dict)
    files: list[ExportedFile] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)


class AccountExporter(Protocol):
    def export_data(self, owner_id: str) -> AccountExport:
        """Reads everything created by or about the owner. Read-only; the
        set of tables mirrors what [AccountEraser.erase_data] removes."""
        ...
