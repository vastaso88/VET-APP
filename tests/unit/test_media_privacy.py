"""Metadata never reaches storage or the vision model (2026-10-06)."""

import io
import struct

from pypdf import PdfReader, PdfWriter

from packages.core.application.services.upload_chat_attachment import (
    UploadChatAttachmentInput,
    UploadChatAttachmentService,
)
from packages.core.domain.conversation.media_privacy import (
    png_text_chunk,
    strip_image_metadata,
)
from packages.core.domain.conversation.media_type import JPEG, PNG, WEBP, detect_media_type
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryPetProfileRepository,
)

# --- fixtures built in code: a phone's EXIF with GPS, date, model -------------

GPS_LATITUDE = (45, 1, 28, 1, 1234, 100)  # 45 deg 28' 12.34" — a place, not a person
PHONE_MODEL = b"TelefonoDiProva X1\x00"
TAKEN_AT = b"2026:10:06 09:15:00\x00"


def _ifd(entries: list[tuple[int, int, int, bytes]], offset: int) -> tuple[bytes, bytes]:
    """Little-endian IFD: entries whose value fits in 4 bytes inline, the
    others in a data area placed right after the IFD."""
    data_start = offset + 2 + 12 * len(entries) + 4
    ifd, data = bytearray(struct.pack("<H", len(entries))), bytearray()
    for tag, kind, count, payload in entries:
        if len(payload) <= 4:
            ifd += struct.pack("<HHI", tag, kind, count) + payload.ljust(4, b"\x00")
        else:
            ifd += struct.pack("<HHII", tag, kind, count, data_start + len(data))
            data += payload
    ifd += struct.pack("<I", 0)
    return bytes(ifd), bytes(data)


def exif_block(orientation: int) -> bytes:
    gps_entries = [
        (0x0001, 2, 2, b"N\x00"),
        (0x0002, 5, 3, struct.pack("<6I", *GPS_LATITUDE)),
    ]
    # IFD0 holds Make, DateTime, Orientation and the pointer to the GPS IFD.
    ifd0_entries_count = 4
    ifd0_size = 2 + 12 * ifd0_entries_count + 4
    data_area = PHONE_MODEL + TAKEN_AT
    gps_offset = 8 + ifd0_size + len(data_area)
    ifd0 = bytearray(struct.pack("<H", ifd0_entries_count))
    ifd0 += struct.pack("<HHII", 0x010F, 2, len(PHONE_MODEL), 8 + ifd0_size)
    ifd0 += struct.pack("<HHII", 0x0112, 3, 1, orientation)
    ifd0 += struct.pack("<HHII", 0x0132, 2, len(TAKEN_AT), 8 + ifd0_size + len(PHONE_MODEL))
    ifd0 += struct.pack("<HHII", 0x8825, 4, 1, gps_offset)
    ifd0 += struct.pack("<I", 0)
    gps_ifd, gps_data = _ifd(gps_entries, gps_offset)
    return b"II*\x00" + struct.pack("<I", 8) + bytes(ifd0) + data_area + gps_ifd + gps_data


def _segment(marker: int, payload: bytes) -> bytes:
    return bytes((0xFF, marker)) + struct.pack(">H", len(payload) + 2) + payload


def phone_jpeg(orientation: int = 6, *, with_jfif: bool = True) -> bytes:
    """Structurally a JPEG (SOI, APP0, EXIF, ICC, IPTC, comment, DQT, SOS,
    EOI) — enough for a byte-level parser; nothing decodes the pixels."""
    parts = [b"\xff\xd8"]
    if with_jfif:
        parts.append(_segment(0xE0, b"JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00"))
    parts.append(_segment(0xE1, b"Exif\x00\x00" + exif_block(orientation)))
    parts.append(_segment(0xE1, b"http://ns.adobe.com/xap/1.0/\x00<x:xmpmeta>gps</x:xmpmeta>"))
    parts.append(_segment(0xE2, b"ICC_PROFILE\x00\x01\x01" + b"\x00" * 20))
    parts.append(_segment(0xED, b"Photoshop 3.0\x008BIM\x04\x04" + b"IPTC caption"))
    parts.append(_segment(0xFE, b"commento con indirizzo di casa"))
    parts.append(_segment(0xDB, b"\x00" + bytes(range(64))))
    parts.append(_segment(0xDA, b"\x01\x01\x00\x00\x3f\x00") + b"\x12\x34\x56" + b"\xff\xd9")
    return b"".join(parts)


def png_with_metadata() -> bytes:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + struct.pack(">I", len(ihdr))
        + b"IHDR"
        + ihdr
        + b"\x00\x00\x00\x00"
        + png_text_chunk(b"Comment", b"scattata a casa")
        + struct.pack(">I", 6)
        + b"eXIf"
        + b"II*\x00\x08\x00"
        + b"\x00\x00\x00\x00"
        + struct.pack(">I", 3)
        + b"IDAT"
        + b"\x08\x1d\x01"
        + b"\x00\x00\x00\x00"
        + struct.pack(">I", 0)
        + b"IEND"
        + b"\xaeB`\x82"
    )


def _riff_chunk(kind: bytes, payload: bytes) -> bytes:
    return kind + struct.pack("<I", len(payload)) + payload + (b"\x00" if len(payload) % 2 else b"")


def webp_with_metadata() -> bytes:
    vp8x = _riff_chunk(
        b"VP8X", bytes([0x08 | 0x04 | 0x10]) + b"\x00\x00\x00" + b"\x00\x00\x00\x00\x00\x00"
    )
    body = (
        vp8x
        + _riff_chunk(b"VP8L", b"\x2f\x00\x00\x00\x00")
        + _riff_chunk(b"EXIF", exif_block(1))
        + _riff_chunk(b"XMP ", b"<x:xmpmeta>gps</x:xmpmeta>")
    )
    return b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WEBP" + body


def pdf_with_metadata() -> bytes:
    writer = PdfWriter()
    writer.add_blank_page(width=200, height=200)
    writer.add_metadata(
        {"/Author": "Mario Rossi", "/Producer": "Scanner Pro 3", "/Title": "Referto"}
    )
    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()


def _exif_segments(content: bytes) -> list[bytes]:
    found, position = [], 2
    while position + 4 <= len(content) and content[position] == 0xFF:
        marker = content[position + 1]
        length = struct.unpack(">H", content[position + 2 : position + 4])[0]
        if marker == 0xE1:
            found.append(content[position + 4 : position + 2 + length])
        if marker == 0xDA:
            break
        position += 2 + length
    return found


# --- JPEG -----------------------------------------------------------------------


def test_a_phone_jpeg_loses_gps_date_model_xmp_iptc_and_comments() -> None:
    original = phone_jpeg(orientation=6)
    assert b"TelefonoDiProva" in original and b"2026:10:06" in original

    cleaned = strip_image_metadata(original, JPEG)

    for secret in (b"TelefonoDiProva", b"2026:10:06", b"xmpmeta", b"Photoshop", b"indirizzo"):
        assert secret not in cleaned
    assert struct.pack("<6I", *GPS_LATITUDE) not in cleaned
    assert detect_media_type(cleaned) == JPEG
    assert cleaned.endswith(b"\x12\x34\x56\xff\xd9")
    assert b"ICC_PROFILE" in cleaned  # colour profile is not personal
    assert b"JFIF" in cleaned


def test_the_orientation_survives_as_the_only_exif_tag() -> None:
    cleaned = strip_image_metadata(phone_jpeg(orientation=6), JPEG)

    [exif] = _exif_segments(cleaned)
    assert exif.startswith(b"Exif\x00\x00II*\x00")
    tiff = exif[6:]
    count = struct.unpack("<H", tiff[8:10])[0]
    assert count == 1
    tag, kind, number, value = struct.unpack("<HHIH", tiff[10:20])
    assert (tag, kind, number, value) == (0x0112, 3, 1, 6)


def test_an_upright_photo_gets_no_exif_at_all() -> None:
    cleaned = strip_image_metadata(phone_jpeg(orientation=1), JPEG)

    assert _exif_segments(cleaned) == []


def test_a_jpeg_without_jfif_still_gets_its_orientation_right_after_soi() -> None:
    cleaned = strip_image_metadata(phone_jpeg(orientation=8, with_jfif=False), JPEG)

    assert cleaned[2:4] == b"\xff\xe1"
    assert _exif_segments(cleaned)[0].startswith(b"Exif")


def test_an_unparseable_jpeg_never_passes_its_bytes_through_unread() -> None:
    # Fail closed (2026-10-06): a JPEG that cannot be parsed to the end
    # comes back only as far as it was understood, never as uploaded.
    garbage = b"\xff\xd8\xff" + b"\x01\x02\x03"
    assert strip_image_metadata(garbage, JPEG) == b"\xff\xd8\xff\x01"


# --- PNG / WEBP ---------------------------------------------------------------------


def test_a_png_loses_its_text_and_exif_chunks_and_stays_a_png() -> None:
    cleaned = strip_image_metadata(png_with_metadata(), PNG)

    assert b"scattata a casa" not in cleaned
    assert b"eXIf" not in cleaned
    assert b"IHDR" in cleaned and b"IDAT" in cleaned and cleaned.endswith(b"IEND\xaeB`\x82")
    assert detect_media_type(cleaned) == PNG


def test_a_webp_loses_exif_and_xmp_and_its_flags_say_so() -> None:
    cleaned = strip_image_metadata(webp_with_metadata(), WEBP)

    assert b"EXIF" not in cleaned and b"xmpmeta" not in cleaned
    assert b"TelefonoDiProva" not in cleaned
    assert detect_media_type(cleaned) == WEBP
    assert struct.unpack("<I", cleaned[4:8])[0] == len(cleaned) - 8
    flags = cleaned[cleaned.index(b"VP8X") + 8]
    assert flags & 0x08 == 0 and flags & 0x04 == 0
    assert flags & 0x10  # alpha flag untouched


# --- PDF ------------------------------------------------------------------------


def test_a_pdf_loses_author_and_producer_but_keeps_its_pages() -> None:
    original = pdf_with_metadata()
    assert b"Mario Rossi" in original

    cleaned = PypdfReader().strip_metadata(original)

    reader = PdfReader(io.BytesIO(cleaned))
    assert len(reader.pages) == 1
    assert b"Mario Rossi" not in cleaned and b"Scanner Pro" not in cleaned
    assert reader.metadata is None or not reader.metadata.get("/Author")


# --- the upload pipeline ---------------------------------------------------------


class _Storage:
    def __init__(self) -> None:
        self.saved: dict[str, bytes] = {}

    def save(self, key: str, content: bytes) -> None:
        self.saved[key] = content

    def read(self, key: str) -> bytes | None:
        return self.saved.get(key)


class _SeeingAnalyzer:
    def __init__(self) -> None:
        self.seen: list[bytes] = []

    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        self.seen.append(image_bytes)
        return "Un cane sul divano."


def test_neither_storage_nor_the_vision_model_receive_the_photos_metadata() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Thor", species="Cane"))
    storage, analyzer = _Storage(), _SeeingAnalyzer()
    service = UploadChatAttachmentService(
        pets, InMemoryChatAttachmentRepository(), storage, analyzer
    )

    result = service.execute(
        UploadChatAttachmentInput(
            owner_id="owner-1",
            pet_id="pet-1",
            file_bytes=phone_jpeg(orientation=6),
            filename="IMG_0001.jpg",
            content_type="application/octet-stream",
        )
    )

    stored = storage.saved[result.attachment.storage_key]
    [seen] = analyzer.seen
    for content in (stored, seen):
        assert b"TelefonoDiProva" not in content
        assert struct.pack("<6I", *GPS_LATITUDE) not in content
        assert b"2026:10:06" not in content
    assert len(_exif_segments(stored)) == 1  # orientation kept
