"""Strips the metadata an owner's phone writes into a photo.

Found 2026-10-06 ("Gestione mappe per pet"): photos carried their EXIF —
GPS position, date, phone model — all the way into storage. Files sent to
POST /chat-attachments (chat photos, photographed reports) are cleaned
here BEFORE being stored and before reaching the vision model, whatever
the app did on its side.

Done at byte level, without an image library (Pillow would be a heavy
dependency on the serverless runtime): the pixel data is never decoded
or re-encoded, so the picture itself is untouched.

JPEG: every APPn segment except JFIF (APP0) and the ICC colour profile
(APP2 "ICC_PROFILE") is dropped, and so are comments. The one thing worth
keeping from EXIF is the Orientation tag — without it a vertical phone
photo shows up rotated, to the owner and to the vision model — so it is
written back as a minimal EXIF holding that single tag.
PNG: textual, time and eXIf chunks are dropped.
WEBP: EXIF and XMP chunks are dropped and the container flags updated.
"""

from __future__ import annotations

import struct
import zlib

from packages.core.domain.conversation.media_type import JPEG, PNG, WEBP

_JPEG_SOI = b"\xff\xd8"
_JPEG_EOI = 0xD9
_JPEG_SOS = 0xDA
_JPEG_APP0 = 0xE0
_JPEG_APP1 = 0xE1
_JPEG_APP2 = 0xE2
_JPEG_COM = 0xFE
_JPEG_STANDALONE = {0x01, *range(0xD0, 0xD8)}  # TEM, RSTn: no length field
_ICC_PROFILE = b"ICC_PROFILE\x00"
_EXIF_HEADER = b"Exif\x00\x00"
_ORIENTATION_TAG = 0x0112
_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
_PNG_METADATA_CHUNKS = {b"eXIf", b"tEXt", b"zTXt", b"iTXt", b"tIME"}
_WEBP_METADATA_CHUNKS = {b"EXIF", b"XMP "}
_WEBP_FLAG_EXIF = 0x08
_WEBP_FLAG_XMP = 0x04


def strip_image_metadata(content: bytes, media_type: str) -> bytes:
    """The same image without EXIF/XMP/IPTC/comments. Anything this code
    cannot parse is returned unchanged rather than damaged."""
    try:
        if media_type == JPEG:
            return _strip_jpeg(content)
        if media_type == PNG:
            return _strip_png(content)
        if media_type == WEBP:
            return _strip_webp(content)
    except (struct.error, IndexError, ValueError):
        return content
    return content


# --- JPEG ---------------------------------------------------------------------


def _strip_jpeg(content: bytes) -> bytes:
    if not content.startswith(_JPEG_SOI):
        return content
    out = bytearray(_JPEG_SOI)
    position = 2
    orientation = 1
    while position + 4 <= len(content):
        if content[position] != 0xFF:
            raise ValueError("not a JPEG segment")
        marker = content[position + 1]
        if marker == 0xFF:  # fill byte
            position += 1
            continue
        if marker in _JPEG_STANDALONE:
            out += content[position : position + 2]
            position += 2
            continue
        length = struct.unpack(">H", content[position + 2 : position + 4])[0]
        segment = content[position : position + 2 + length]
        position += 2 + length
        if marker == _JPEG_SOS:
            # Entropy-coded data follows until the end: copied as is.
            out += segment + content[position:]
            break
        if marker == _JPEG_APP1 and segment[4:10] == _EXIF_HEADER:
            orientation = _exif_orientation(segment[10:]) or orientation
            continue
        if _JPEG_APP0 <= marker <= 0xEF or marker == _JPEG_COM:
            keep = marker == _JPEG_APP0 or (
                marker == _JPEG_APP2 and segment[4 : 4 + len(_ICC_PROFILE)] == _ICC_PROFILE
            )
            if not keep:
                continue
        out += segment
    else:
        out += content[position:]
    if orientation != 1:
        # Right after SOI (and JFIF, if present), where EXIF belongs.
        insert_at = 2
        if out[2:4] == bytes((0xFF, _JPEG_APP0)):
            insert_at = 4 + struct.unpack(">H", out[4:6])[0]
        out[insert_at:insert_at] = _orientation_only_exif(orientation)
    return bytes(out)


def _exif_orientation(tiff: bytes) -> int | None:
    """The Orientation tag of an EXIF TIFF block, if present and sane."""
    if tiff[:2] == b"II":
        order = "<"
    elif tiff[:2] == b"MM":
        order = ">"
    else:
        return None
    ifd_offset = struct.unpack(order + "I", tiff[4:8])[0]
    count = struct.unpack(order + "H", tiff[ifd_offset : ifd_offset + 2])[0]
    for index in range(count):
        entry = ifd_offset + 2 + index * 12
        tag, kind, _count = struct.unpack(order + "HHI", tiff[entry : entry + 8])
        if tag == _ORIENTATION_TAG and kind == 3:
            value = struct.unpack(order + "H", tiff[entry + 8 : entry + 10])[0]
            return value if 1 <= value <= 8 else None
    return None


def _orientation_only_exif(orientation: int) -> bytes:
    tiff = (
        b"II*\x00"
        + struct.pack("<I", 8)
        + struct.pack("<H", 1)
        + struct.pack("<HHIHH", _ORIENTATION_TAG, 3, 1, orientation, 0)
        + struct.pack("<I", 0)
    )
    payload = _EXIF_HEADER + tiff
    return bytes((0xFF, _JPEG_APP1)) + struct.pack(">H", len(payload) + 2) + payload


# --- PNG ------------------------------------------------------------------------


def _strip_png(content: bytes) -> bytes:
    if not content.startswith(_PNG_SIGNATURE):
        return content
    out = bytearray(_PNG_SIGNATURE)
    position = len(_PNG_SIGNATURE)
    while position + 8 <= len(content):
        length = struct.unpack(">I", content[position : position + 4])[0]
        kind = content[position + 4 : position + 8]
        chunk = content[position : position + 12 + length]
        position += 12 + length
        if kind not in _PNG_METADATA_CHUNKS:
            out += chunk
    # Whatever trails the last whole chunk is kept as is.
    out += content[position:]
    return bytes(out)


# --- WEBP ---------------------------------------------------------------------


def _strip_webp(content: bytes) -> bytes:
    if content[:4] != b"RIFF" or content[8:12] != b"WEBP":
        return content
    chunks = bytearray()
    position = 12
    while position + 8 <= len(content):
        kind = content[position : position + 4]
        length = struct.unpack("<I", content[position + 4 : position + 8])[0]
        padded = length + (length & 1)
        chunk = bytearray(content[position : position + 8 + padded])
        position += 8 + padded
        if kind in _WEBP_METADATA_CHUNKS:
            continue
        if kind == b"VP8X" and len(chunk) >= 9:
            chunk[8] &= ~(_WEBP_FLAG_EXIF | _WEBP_FLAG_XMP) & 0xFF
        chunks += chunk
    chunks += content[position:]
    return b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WEBP" + bytes(chunks)


def png_text_chunk(keyword: bytes, text: bytes) -> bytes:
    """A tEXt chunk — for tests that need a PNG carrying metadata."""
    body = keyword + b"\x00" + text
    return (
        struct.pack(">I", len(body))
        + b"tEXt"
        + body
        + struct.pack(">I", zlib.crc32(b"tEXt" + body) & 0xFFFFFFFF)
    )
