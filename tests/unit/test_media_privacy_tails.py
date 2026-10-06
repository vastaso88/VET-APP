"""Second round of gestore git's fuzzing (2026-10-06): tails after the
image must not pass through, and a progressive JPEG must keep every scan."""

import struct

from test_media_privacy import (
    _exif_segments,
    _riff_chunk,
    _segment,
    exif_block,
    phone_jpeg,
    png_with_metadata,
    webp_with_metadata,
)

from packages.core.domain.conversation.media_privacy import png_text_chunk, strip_image_metadata
from packages.core.domain.conversation.media_type import JPEG, PNG, WEBP

SOI = b"\xff\xd8"
EOI = b"\xff\xd9"
JFIF = _segment(0xE0, b"JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00")
# Scan data with a stuffed FF 00 and a restart marker, as real scans have.
FIRST_SCAN = _segment(0xDA, b"\x01\x01\x00\x00\x3f\x00") + b"\x12\xff\x00\x34\xff\xd0\x56"
# A Huffman table whose payload happens to contain FF D9: a naive search
# for the end-of-image marker would stop here.
DHT_WITH_FAKE_EOI = _segment(0xC4, b"\x10" + b"\x01" * 6 + b"\xff\xd9" + b"\x02" * 6)
SECOND_SCAN = _segment(0xDA, b"\x01\x01\x10\x00\x3f\x01") + b"\x78\x9a\xbc"
PROGRESSIVE = (
    SOI
    + JFIF
    + _segment(0xE1, b"Exif\x00\x00" + exif_block(6))
    + _segment(0xDB, b"\x00" + bytes(range(64)))
    + FIRST_SCAN
    + DHT_WITH_FAKE_EOI
    + _segment(0xFE, b"commento tra due scan")
    + SECOND_SCAN
    + EOI
)


def test_a_progressive_jpeg_keeps_every_scan_and_ends_at_the_real_eoi() -> None:
    cleaned = strip_image_metadata(PROGRESSIVE + phone_jpeg(orientation=1), JPEG)

    assert cleaned.endswith(SECOND_SCAN + EOI)
    assert FIRST_SCAN in cleaned
    assert DHT_WITH_FAKE_EOI in cleaned
    assert b"commento tra due scan" not in cleaned
    assert b"TelefonoDiProva" not in cleaned
    # Exactly one trailing EOI: the appended second image is gone.
    assert cleaned.count(phone_jpeg(orientation=1)[:4]) == 1
    [exif] = _exif_segments(cleaned)
    assert exif.startswith(b"Exif")


def test_a_jpeg_that_ends_without_eoi_yields_what_it_has() -> None:
    truncated = SOI + JFIF + FIRST_SCAN + DHT_WITH_FAKE_EOI + SECOND_SCAN[:8]

    cleaned = strip_image_metadata(truncated, JPEG)

    assert cleaned.startswith(SOI + JFIF + FIRST_SCAN + DHT_WITH_FAKE_EOI)
    assert len(cleaned) <= len(truncated)


def test_a_png_tail_after_iend_is_dropped() -> None:
    png = png_with_metadata() + png_text_chunk(b"Comment", b"posizione nascosta") + b"EXTRA"

    cleaned = strip_image_metadata(png, PNG)

    assert cleaned.endswith(b"IEND\xaeB`\x82")
    assert b"posizione nascosta" not in cleaned and b"EXTRA" not in cleaned


def test_an_incomplete_png_chunk_is_not_copied() -> None:
    png = png_with_metadata()
    cut = png[: png.index(b"IEND") - 4]  # ends in the middle of the IDAT/IEND area
    cut += struct.pack(">I", 500) + b"iTXt" + b"gps=45.28"  # declares 500 bytes, has 9

    cleaned = strip_image_metadata(cut, PNG)

    assert b"gps=45.28" not in cleaned
    assert cleaned.startswith(b"\x89PNG\r\n\x1a\n")


def test_a_webp_tail_beyond_the_declared_riff_size_is_dropped() -> None:
    webp = webp_with_metadata() + _riff_chunk(b"EXIF", exif_block(1)) + b"TRAILING"

    cleaned = strip_image_metadata(webp, WEBP)

    assert b"TelefonoDiProva" not in cleaned
    assert b"TRAILING" not in cleaned
    assert struct.unpack("<I", cleaned[4:8])[0] == len(cleaned) - 8


def test_an_incomplete_webp_chunk_is_not_copied() -> None:
    body = (
        _riff_chunk(b"VP8L", b"\x2f\x00\x00\x00\x00")
        + b"EXIF"
        + struct.pack("<I", 400)
        + b"II*\x00gps"
    )
    webp = b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WEBP" + body

    cleaned = strip_image_metadata(webp, WEBP)

    assert b"gps" not in cleaned
    assert b"VP8L" in cleaned
