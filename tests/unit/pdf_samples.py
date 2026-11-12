"""Tiny hand-built PDFs for tests — no fixture files, no extra library."""

import io

from pypdf import PdfWriter

# A minimal but valid JPEG header is all the reader needs: it extracts the
# embedded image bytes without decoding them.
JPEG_PAGE_SCAN = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 200 + b"\xff\xd9"


def _assemble(objects: list[bytes]) -> bytes:
    """Serializes numbered objects with a correct cross-reference table."""
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode() + body + b"\nendobj\n"
    xref_at = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n".encode()
    out += f"startxref\n{xref_at}\n%%EOF\n".encode()
    return bytes(out)


def _stream(dictionary: str, data: bytes) -> bytes:
    return f"<< {dictionary} /Length {len(data)} >>\nstream\n".encode() + data + b"\nendstream"


def text_pdf(lines: list[str]) -> bytes:
    """One page whose text layer contains `lines` (ASCII only)."""
    commands = ["BT", "/F1 12 Tf", "72 720 Td"]
    for line in lines:
        escaped = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        commands += [f"({escaped}) Tj", "0 -18 Td"]
    commands.append("ET")
    content = "\n".join(commands).encode("ascii")
    return _assemble(
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            b"/Resources << /Font << /F1 5 0 R >> >> >>",
            _stream("", content),
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ]
    )


def scanned_pdf(page_image: bytes = JPEG_PAGE_SCAN) -> bytes:
    """One page with no text layer, only an embedded JPEG — what a scanner
    or a phone scanning app produces."""
    return _assemble(
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
            b"/Resources << /XObject << /Im1 5 0 R >> >> >>",
            _stream("", b"q 612 0 0 792 0 0 cm /Im1 Do Q"),
            _stream(
                "/Type /XObject /Subtype /Image /Width 8 /Height 8 /ColorSpace /DeviceRGB "
                "/BitsPerComponent 8 /Filter /DCTDecode",
                page_image,
            ),
        ]
    )


def blank_pdf(pages: int, *, password: str | None = None) -> bytes:
    writer = PdfWriter()
    for _ in range(pages):
        writer.add_blank_page(width=200, height=200)
    if password is not None:
        writer.encrypt(password)
    buffer = io.BytesIO()
    writer.write(buffer)
    return buffer.getvalue()
