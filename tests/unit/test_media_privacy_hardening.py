"""Findings of gestore git's fuzzing of media_privacy.py (2026-10-06):
the stripper must fail CLOSED and must not harm colour information."""

import struct

from test_media_privacy import PHONE_MODEL, _exif_segments, _segment, exif_block, phone_jpeg

from packages.core.domain.conversation.media_privacy import strip_image_metadata
from packages.core.domain.conversation.media_type import JPEG, detect_media_type

SOI = b"\xff\xd8"
EOI = b"\xff\xd9"
SCAN = _segment(0xDA, b"\x01\x01\x00\x00\x3f\x00") + b"\x12\x34\x56" + EOI


def test_a_malformed_exif_is_dropped_instead_of_leaking_the_whole_file() -> None:
    # IFD offset far beyond the block: parsing the orientation fails.
    broken_tiff = b"II*\x00" + struct.pack("<I", 0x00FFFFFF) + PHONE_MODEL + b"GPS" * 20
    jpeg = SOI + _segment(0xE1, b"Exif\x00\x00" + broken_tiff) + SCAN

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert b"TelefonoDiProva" not in cleaned
    assert b"GPS" not in cleaned
    assert _exif_segments(cleaned) == []
    assert cleaned == SOI + SCAN
    assert detect_media_type(cleaned) == JPEG


def test_a_second_image_appended_after_the_end_marker_is_dropped() -> None:
    # MPF / "motion photo": a whole second JPEG, with its own EXIF, after EOI.
    first = phone_jpeg(orientation=1)
    jpeg = first + phone_jpeg(orientation=6)

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert cleaned.count(EOI) == 1
    assert cleaned.endswith(EOI)
    assert b"TelefonoDiProva" not in cleaned
    assert len(cleaned) < len(first)


def test_the_adobe_app14_segment_is_kept() -> None:
    adobe = _segment(0xEE, b"Adobe\x00\x64\x00\x00\x00\x00\x01")
    jpeg = SOI + _segment(0xE1, b"Exif\x00\x00" + exif_block(1)) + adobe + SCAN

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert adobe in cleaned
    assert b"TelefonoDiProva" not in cleaned


def test_a_jfif_declaring_more_bytes_than_the_file_has_gets_nothing_appended() -> None:
    truncated_jfif = bytes((0xFF, 0xE0)) + struct.pack(">H", 0x0400) + b"JFIF\x00\x01\x02"
    jpeg = SOI + _segment(0xE1, b"Exif\x00\x00" + exif_block(6)) + truncated_jfif

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert cleaned == SOI
    assert b"Exif" not in cleaned


def test_a_file_truncated_before_its_scan_gets_no_orientation_exif_either() -> None:
    jpeg = SOI + _segment(0xE0, b"JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00")
    jpeg += _segment(0xE1, b"Exif\x00\x00" + exif_block(6))
    jpeg += _segment(0xDB, b"\x00" + bytes(range(64)))  # ends here: no SOS, no EOI

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert _exif_segments(cleaned) == []
    assert b"TelefonoDiProva" not in cleaned
    assert cleaned.startswith(SOI + b"\xff\xe0")


def test_garbage_after_the_start_marker_yields_only_what_was_understood() -> None:
    jpeg = SOI + _segment(0xE1, b"Exif\x00\x00" + exif_block(1)) + b"\x01\x02\x03\x04\x05"

    cleaned = strip_image_metadata(jpeg, JPEG)

    assert cleaned == SOI
    assert b"TelefonoDiProva" not in cleaned


def test_something_that_is_not_a_jpeg_at_all_is_left_alone() -> None:
    assert strip_image_metadata(b"not an image", JPEG) == b"not an image"
