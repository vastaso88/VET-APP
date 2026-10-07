"""Retroactive metadata cleanup of images already sitting in storage.

Since 2026-10-06 new uploads are cleaned (the app re-encodes photos without
EXIF; the server runs `strip_image_metadata` on every chat/record attachment).
Files uploaded before that still carry GPS position, date and phone model.
This module walks the buckets, applies THE SAME server-side cleaner and, only
when something was really removed and the result is verifiably a complete
image, writes the cleaned bytes back.

Principles:
- fail closed on the cleaner, fail SAFE on the owner's data: the server cleaner
  may return a truncated file for a corrupt input (an unreadable upload is
  acceptable, a leaked position is not). Here the original is the owner's only
  copy, so a cleaned result that is not a complete image of the same kind is
  never written - the file is reported as "unsafe" and left as it was.
- nothing personal in the output: object paths hold owner and pet ids, so they
  are reported as a short hash only.
- resumable: finished objects are remembered (as hashes) and skipped on a
  rerun.
- videos are never touched; PDFs only on request.
"""

from __future__ import annotations

import hashlib
import json
import os
import struct
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

from packages.core.domain.conversation.media_privacy import strip_image_metadata
from packages.core.domain.conversation.media_type import (
    IMAGE_TYPES,
    JPEG,
    PDF,
    PNG,
    WEBP,
    detect_media_type,
)

VIDEO_EXTENSIONS = frozenset({"mp4", "m4v", "mov", "3gp", "3g2", "webm", "mkv", "avi"})
DEFAULT_MAX_BYTES = 60 * 1000 * 1000
_PNG_TAIL = b"IEND\xaeB`\x82"
_EXIF_GPS_POINTER = 0x8825
_XMP_GPS_MARKERS = (b"GPSLatitude", b"GPSLongitude")
_SAVE_EVERY = 25


class BucketStorage(Protocol):
    """The three storage calls the cleanup needs - a fake in tests, a
    Supabase bucket in `SupabaseBucketStorage`."""

    def list_entries(self, prefix: str, offset: int, limit: int) -> list[dict[str, Any]]: ...

    def download(self, path: str) -> bytes: ...

    def upload(self, path: str, content: bytes, content_type: str) -> None: ...


class SupabaseBucketStorage:
    def __init__(self, client: Any, bucket: str) -> None:
        self._bucket = client.storage.from_(bucket)

    def list_entries(self, prefix: str, offset: int, limit: int) -> list[dict[str, Any]]:
        entries = self._bucket.list(
            prefix,
            {"limit": limit, "offset": offset, "sortBy": {"column": "name", "order": "asc"}},
        )
        return list(entries or [])

    def download(self, path: str) -> bytes:
        return bytes(self._bucket.download(path))

    def upload(self, path: str, content: bytes, content_type: str) -> None:
        self._bucket.upload(path, content, {"content-type": content_type, "upsert": "true"})


@dataclass(frozen=True)
class ObjectInfo:
    path: str
    size: int | None = None
    mimetype: str | None = None


def iter_objects(
    storage: BucketStorage, prefix: str = "", *, page_size: int = 100
) -> Iterator[ObjectInfo]:
    """Every object under `prefix`, folders followed (a Supabase listing is
    one level deep and marks a folder with a null id)."""
    offset = 0
    while True:
        entries = storage.list_entries(prefix, offset, page_size)
        for entry in entries:
            name = str(entry.get("name", ""))
            if not name:
                continue
            path = f"{prefix}/{name}" if prefix else name
            if entry.get("id") is None:
                yield from iter_objects(storage, path, page_size=page_size)
                continue
            if name.startswith("."):  # ".emptyFolderPlaceholder"
                continue
            metadata = entry.get("metadata") or {}
            size = metadata.get("size")
            yield ObjectInfo(
                path=path,
                size=int(size) if isinstance(size, int | float) else None,
                mimetype=metadata.get("mimetype"),
            )
        if len(entries) < page_size:
            return
        offset += page_size


# --- looking at an image --------------------------------------------------------


def _tiff_has_gps(tiff: bytes) -> bool:
    """True when the TIFF/EXIF block's first directory points to a GPS one."""
    try:
        if tiff[:2] == b"II":
            order = "<"
        elif tiff[:2] == b"MM":
            order = ">"
        else:
            return False
        ifd_offset = struct.unpack(order + "I", tiff[4:8])[0]
        count = struct.unpack(order + "H", tiff[ifd_offset : ifd_offset + 2])[0]
        for index in range(min(count, 512)):
            entry = ifd_offset + 2 + index * 12
            tag = struct.unpack(order + "H", tiff[entry : entry + 2])[0]
            if tag == _EXIF_GPS_POINTER:
                return True
    except (struct.error, IndexError, ValueError):
        return False
    return False


def _has_xmp_gps(data: bytes) -> bool:
    return any(marker in data for marker in _XMP_GPS_MARKERS)


def _jpeg_has_gps(content: bytes) -> bool:
    position = 2
    while position + 4 <= len(content) and content[position] == 0xFF:
        marker = content[position + 1]
        if marker == 0xFF:
            position += 1
            continue
        if marker in (0x01, *range(0xD0, 0xD8)):
            position += 2
            continue
        if marker in (0xDA, 0xD9):
            return False
        length = struct.unpack(">H", content[position + 2 : position + 4])[0]
        if length < 2:
            return False
        segment = content[position + 4 : position + 2 + length]
        if marker == 0xE1:
            if segment[:6] == b"Exif\x00\x00" and _tiff_has_gps(segment[6:]):
                return True
            if _has_xmp_gps(segment):
                return True
        position += 2 + length
    return False


def _png_has_gps(content: bytes) -> bool:
    position = 8
    while position + 8 <= len(content):
        length = struct.unpack(">I", content[position : position + 4])[0]
        kind = content[position + 4 : position + 8]
        body = content[position + 8 : position + 8 + length]
        if kind == b"eXIf" and _tiff_has_gps(body):
            return True
        if kind in (b"tEXt", b"zTXt", b"iTXt") and _has_xmp_gps(body):
            return True
        position += 12 + length
    return False


def _webp_has_gps(content: bytes) -> bool:
    position = 12
    while position + 8 <= len(content):
        kind = content[position : position + 4]
        length = struct.unpack("<I", content[position + 4 : position + 8])[0]
        body = content[position + 8 : position + 8 + length]
        if kind == b"EXIF":
            tiff = body[6:] if body[:6] == b"Exif\x00\x00" else body
            if _tiff_has_gps(tiff):
                return True
        if kind == b"XMP " and _has_xmp_gps(body):
            return True
        position += 8 + length + (length & 1)
    return False


def image_has_gps(content: bytes, media_type: str) -> bool:
    """Whether the image still carries a GPS position (EXIF or XMP). Never
    raises: an unreadable structure counts as 'no GPS found'."""
    try:
        if media_type == JPEG:
            return _jpeg_has_gps(content)
        if media_type == PNG:
            return _png_has_gps(content)
        if media_type == WEBP:
            return _webp_has_gps(content)
    except (struct.error, IndexError, ValueError):
        return False
    return False


def is_complete_image(content: bytes, media_type: str) -> bool:
    """A cheap structural check that the cleaned bytes are a whole image of
    the same kind, not the truncated output the server cleaner gives for a
    corrupt input."""
    if detect_media_type(content) != media_type:
        return False
    if media_type == JPEG:
        return content.endswith(b"\xff\xd9")
    if media_type == PNG:
        return content.endswith(_PNG_TAIL)
    if media_type == WEBP:
        return len(content) >= 12 and struct.unpack("<I", content[4:8])[0] == len(content) - 8
    return False


@dataclass(frozen=True)
class ImageInspection:
    media_type: str
    has_metadata: bool
    has_gps: bool
    cleaned: bytes
    safe_to_write: bool


def inspect_image(content: bytes, media_type: str) -> ImageInspection:
    """Applies the server's cleaner and says what it would change and whether
    writing the result back is safe."""
    cleaned = strip_image_metadata(content, media_type)
    has_metadata = cleaned != content
    safe = (
        has_metadata
        and is_complete_image(cleaned, media_type)
        and not image_has_gps(cleaned, media_type)
    )
    return ImageInspection(
        media_type=media_type,
        has_metadata=has_metadata,
        has_gps=image_has_gps(content, media_type),
        cleaned=cleaned,
        safe_to_write=safe,
    )


# --- PDFs (opt-in) --------------------------------------------------------------


def pdf_has_metadata(content: bytes) -> bool:
    """Author, producer, title... in the Info dictionary or an XMP packet."""
    import io

    from pypdf import PdfReader

    try:
        reader = PdfReader(io.BytesIO(content))
        return bool(reader.metadata) or reader.xmp_metadata is not None
    except Exception:
        return False


def pdf_cleaning_is_safe(original: bytes, cleaned: bytes) -> bool:
    import io

    from pypdf import PdfReader

    try:
        before = PdfReader(io.BytesIO(original))
        after = PdfReader(io.BytesIO(cleaned))
        return (
            cleaned.lstrip().startswith(b"%PDF-")
            and len(after.pages) == len(before.pages)
            and not (bool(after.metadata) or after.xmp_metadata is not None)
        )
    except Exception:
        return False


# --- resumable state ------------------------------------------------------------


def object_fingerprint(bucket: str, path: str) -> str:
    """A short, non-reversible id for logs and the resume file: object paths
    contain owner and pet ids."""
    return hashlib.sha256(f"{bucket}/{path}".encode()).hexdigest()[:16]


class CleanupState:
    """Objects already handled, as fingerprints. `path=None` keeps it in
    memory only (dry run, tests)."""

    def __init__(self, path: Path | None = None) -> None:
        self._path = path
        self._done: set[str] = set()
        self._unsaved = 0
        if path is not None and path.exists():
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                self._done = {str(item) for item in data.get("done", [])}
            except (OSError, ValueError):
                self._done = set()

    def is_done(self, fingerprint: str) -> bool:
        return fingerprint in self._done

    def mark(self, fingerprint: str) -> None:
        self._done.add(fingerprint)
        self._unsaved += 1
        if self._unsaved >= _SAVE_EVERY:
            self.save()

    def save(self) -> None:
        if self._path is None or self._unsaved == 0:
            return
        self._path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self._path.with_suffix(self._path.suffix + ".tmp")
        temporary.write_text(json.dumps({"done": sorted(self._done)}), encoding="utf-8")
        os.replace(temporary, self._path)
        self._unsaved = 0

    def __len__(self) -> int:
        return len(self._done)


# --- the run --------------------------------------------------------------------


@dataclass
class BucketReport:
    bucket: str
    objects: int = 0
    already_done: int = 0
    videos_skipped: int = 0
    too_big_skipped: int = 0
    images: int = 0
    images_with_metadata: int = 0
    images_with_gps: int = 0
    images_cleaned: int = 0
    images_unsafe: int = 0
    pdfs: int = 0
    pdfs_with_metadata: int = 0
    pdfs_cleaned: int = 0
    pdfs_unsafe: int = 0
    other: int = 0
    errors: int = 0
    problems: list[str] = field(default_factory=list)

    @property
    def needs_attention(self) -> bool:
        return bool(self.errors or self.images_unsafe or self.pdfs_unsafe)


PdfCleaner = Callable[[bytes], bytes]


def process_bucket(
    storage: BucketStorage,
    bucket: str,
    *,
    apply: bool,
    state: CleanupState,
    include_pdf: bool = False,
    pdf_cleaner: PdfCleaner | None = None,
    max_bytes: int = DEFAULT_MAX_BYTES,
    limit: int | None = None,
    progress: Callable[[BucketReport], None] | None = None,
) -> BucketReport:
    """Walks one bucket. Dry run (`apply=False`) downloads and inspects but
    writes nothing, neither to storage nor to the resume state."""
    report = BucketReport(bucket=bucket)
    handled = 0
    try:
        for info in iter_objects(storage):
            fingerprint = object_fingerprint(bucket, info.path)
            report.objects += 1
            if apply and state.is_done(fingerprint):
                report.already_done += 1
                continue
            if limit is not None and handled >= limit:
                break
            handled += 1
            _process_object(
                storage, bucket, info, fingerprint, report,
                apply=apply, state=state, include_pdf=include_pdf,
                pdf_cleaner=pdf_cleaner, max_bytes=max_bytes,
            )  # fmt: skip
            if progress is not None and handled % 25 == 0:
                progress(report)
    finally:
        state.save()
    return report


def _process_object(
    storage: BucketStorage,
    bucket: str,
    info: ObjectInfo,
    fingerprint: str,
    report: BucketReport,
    *,
    apply: bool,
    state: CleanupState,
    include_pdf: bool,
    pdf_cleaner: PdfCleaner | None,
    max_bytes: int,
) -> None:
    extension = info.path.rsplit(".", 1)[-1].lower() if "." in info.path else ""
    if extension in VIDEO_EXTENSIONS or (info.mimetype or "").startswith("video/"):
        report.videos_skipped += 1
        return
    if info.size is not None and info.size > max_bytes:
        report.too_big_skipped += 1
        return

    try:
        content = storage.download(info.path)
    except Exception as exc:
        report.errors += 1
        report.problems.append(f"{fingerprint}: download non riuscito ({type(exc).__name__})")
        return

    media_type = detect_media_type(content)
    try:
        if media_type in IMAGE_TYPES:
            done = _handle_image(storage, info, fingerprint, content, media_type, report, apply)
        elif media_type == PDF:
            done = _handle_pdf(
                storage, info, fingerprint, content, report, apply, include_pdf, pdf_cleaner
            )
        else:
            report.other += 1
            done = True
    except Exception as exc:
        report.errors += 1
        report.problems.append(f"{fingerprint}: errore ({type(exc).__name__})")
        return
    if apply and done:
        state.mark(fingerprint)


def _handle_image(
    storage: BucketStorage,
    info: ObjectInfo,
    fingerprint: str,
    content: bytes,
    media_type: str,
    report: BucketReport,
    apply: bool,
) -> bool:
    """Returns True when the object needs no further attention (clean, or
    cleaned now) so a rerun can skip it."""
    report.images += 1
    inspection = inspect_image(content, media_type)
    if inspection.has_gps:
        report.images_with_gps += 1
    if not inspection.has_metadata:
        return True
    report.images_with_metadata += 1
    if not inspection.safe_to_write:
        report.images_unsafe += 1
        report.problems.append(f"{fingerprint}: pulizia non verificabile, file lasciato com'era")
        return False
    if not apply:
        return False
    storage.upload(info.path, inspection.cleaned, media_type)
    report.images_cleaned += 1
    return True


def _handle_pdf(
    storage: BucketStorage,
    info: ObjectInfo,
    fingerprint: str,
    content: bytes,
    report: BucketReport,
    apply: bool,
    include_pdf: bool,
    pdf_cleaner: PdfCleaner | None,
) -> bool:
    report.pdfs += 1
    if not include_pdf or pdf_cleaner is None:
        return True
    if not pdf_has_metadata(content):
        return True
    report.pdfs_with_metadata += 1
    cleaned = pdf_cleaner(content)
    if not pdf_cleaning_is_safe(content, cleaned):
        report.pdfs_unsafe += 1
        report.problems.append(f"{fingerprint}: PDF non verificabile, file lasciato com'era")
        return False
    if not apply:
        return False
    storage.upload(info.path, cleaned, PDF)
    report.pdfs_cleaned += 1
    return True
