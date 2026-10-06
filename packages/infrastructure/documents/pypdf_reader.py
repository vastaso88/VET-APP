import io
import logging
from typing import Any

from pypdf import PdfReader as _PypdfReader
from pypdf import PdfWriter
from pypdf.errors import PyPdfError

from packages.core.application.ports.pdf_reader import PdfContent, PdfReader
from packages.shared.errors.base import ValidationError

logger = logging.getLogger("vetgpt.documents")

_JPEG_FILTER = "/DCTDecode"


class PypdfReader(PdfReader):
    """PDF text and embedded-scan extraction with pypdf (pure Python, so it
    runs on Vercel's serverless runtime with no native libraries).

    Scanned documents are not rasterized — that would need a native
    renderer. Instead the JPEG each scanned page is stored as is pulled
    out as-is, which covers what scanners and phone scanning apps produce;
    a scan stored in another image encoding simply yields no images.
    """

    def __init__(self, *, max_text_pages: int = 10, max_image_pages: int = 3) -> None:
        self._max_text_pages = max_text_pages
        self._max_image_pages = max_image_pages

    def read(self, content: bytes) -> PdfContent:
        try:
            reader = _PypdfReader(io.BytesIO(content))
            if reader.is_encrypted:
                raise ValidationError(
                    "pdf_unreadable: il PDF è protetto da password e non può essere letto."
                )
            pages = list(reader.pages)
            text_parts = [
                (page.extract_text() or "").strip() for page in pages[: self._max_text_pages]
            ]
            images = [
                image
                for page in pages[: self._max_image_pages]
                if (image := self._largest_jpeg(page)) is not None
            ]
        except ValidationError:
            raise
        except (PyPdfError, ValueError, KeyError, TypeError, AttributeError, RecursionError) as exc:
            # pypdf surfaces a malformed file through several exception
            # types; none of them is something the caller can act on other
            # than "this PDF can't be read".
            logger.info("unreadable pdf: %s", type(exc).__name__)
            raise ValidationError(
                "pdf_unreadable: il PDF è danneggiato o non può essere letto."
            ) from exc
        return PdfContent(
            page_count=len(pages),
            text="\n\n".join(part for part in text_parts if part),
            page_images=images,
        )

    def strip_metadata(self, content: bytes) -> bytes:
        # The document is cloned object by object (no content stream is
        # decoded or re-compressed) and written back without its Info
        # dictionary and XMP packet.
        try:
            writer = PdfWriter(clone_from=_PypdfReader(io.BytesIO(content)))
            writer.metadata = None
            writer.xmp_metadata = None
            buffer = io.BytesIO()
            writer.write(buffer)
            return buffer.getvalue()
        except (PyPdfError, ValueError, KeyError, TypeError, AttributeError, RecursionError):
            logger.warning("pdf metadata could not be stripped; file kept as uploaded")
            return content

    @staticmethod
    def _largest_jpeg(page: Any) -> bytes | None:
        resources = page.get("/Resources")
        if resources is None:
            return None
        xobjects = resources.get_object().get("/XObject")
        if xobjects is None:
            return None
        best: bytes | None = None
        for reference in xobjects.get_object().values():
            candidate = reference.get_object()
            if candidate.get("/Subtype") != "/Image":
                continue
            filters = candidate.get("/Filter")
            if filters != _JPEG_FILTER and filters != [_JPEG_FILTER]:
                continue
            data: bytes = candidate._data
            if best is None or len(data) > len(best):
                best = data
        return best
