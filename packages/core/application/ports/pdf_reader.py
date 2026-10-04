from typing import Protocol

from pydantic import BaseModel, Field


class PdfContent(BaseModel):
    page_count: int
    text: str = ""
    """Text extracted from the first pages, empty for a scanned document."""
    page_images: list[bytes] = Field(default_factory=list)
    """JPEG images embedded in the first pages (how a scanner or a phone
    scanning app stores each page) — the fallback when there is no text."""


class PdfReader(Protocol):
    def read(self, content: bytes) -> PdfContent:
        """Raises ValidationError("pdf_unreadable: ...") for a corrupt or
        password-protected file."""
        ...
