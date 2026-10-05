"""Builds the synthetic report files used by the chat quality evaluation.

Source of truth: the .txt files in fixtures/referti/ (invented values, a
plainly fictitious clinic, no real person). From them this writes, next
to each .txt, the file an owner would actually upload:

- a text PDF for the reports listed in PDF_REPORTS;
- a JPEG "scan" (text rendered on a white page) for those in SCAN_REPORTS.

The generated files are committed, so the evaluation itself needs nothing
extra. Re-run only after editing a .txt (JPEG rendering needs Pillow):

    uv run --with pillow python scripts/eval/chat_quality/make_fixtures.py
"""

from __future__ import annotations

import io
from pathlib import Path

REPORTS_DIR = Path(__file__).resolve().parent / "fixtures" / "referti"

PDF_REPORTS = (
    "biochimico_renale",
    "emocromo",
    "ecografia_addome",
    "esami_nella_norma",
    "visita_rene_terapia",
)
SCAN_REPORTS = ("urine", "coprologico")


def _assemble(objects: list[bytes]) -> bytes:
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


def text_pdf(lines: list[str]) -> bytes:
    """One A4 page with a real text layer, in a fixed-width font so the
    columns of a lab report stay aligned."""
    commands = ["BT", "/F1 9 Tf", "40 800 Td"]
    for line in lines:
        escaped = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        commands += [f"({escaped}) Tj", "0 -13 Td"]
    commands.append("ET")
    content = "\n".join(commands).encode("latin-1")
    stream = f"<< /Length {len(content)} >>\nstream\n".encode() + content + b"\nendstream"
    return _assemble(
        [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
            b"/Resources << /Font << /F1 5 0 R >> >> >>",
            stream,
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>",
        ]
    )


def scan_jpeg(lines: list[str]) -> bytes:
    """The report as a photographed/scanned page: no text layer at all."""
    from PIL import Image, ImageDraw, ImageFont

    try:
        font = ImageFont.truetype("cour.ttf", 22)
    except OSError:
        font = ImageFont.load_default(size=22)
    width, line_height, margin = 1500, 34, 60
    image = Image.new("RGB", (width, margin * 2 + line_height * len(lines)), "white")
    draw = ImageDraw.Draw(image)
    for index, line in enumerate(lines):
        draw.text((margin, margin + index * line_height), line, fill=(20, 20, 20), font=font)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=80)
    return buffer.getvalue()


def main() -> None:
    for name in PDF_REPORTS:
        lines = (REPORTS_DIR / f"{name}.txt").read_text(encoding="utf-8").splitlines()
        (REPORTS_DIR / f"{name}.pdf").write_bytes(text_pdf(lines))
        print(f"scritto {name}.pdf")
    for name in SCAN_REPORTS:
        lines = (REPORTS_DIR / f"{name}.txt").read_text(encoding="utf-8").splitlines()
        (REPORTS_DIR / f"{name}.jpg").write_bytes(scan_jpeg(lines))
        print(f"scritto {name}.jpg")


if __name__ == "__main__":
    main()
