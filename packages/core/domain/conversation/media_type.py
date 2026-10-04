"""What an uploaded file really is, decided from its first bytes.

The declared multipart content type can't be trusted either way: the
mobile app sends every file as `application/octet-stream` (Dart's
`MultipartFile.fromBytes` default), and a renamed file can claim to be
anything. The file's own signature is the only reliable answer.
"""

JPEG = "image/jpeg"
PNG = "image/png"
WEBP = "image/webp"
PDF = "application/pdf"

IMAGE_TYPES = frozenset({JPEG, PNG, WEBP})

# A PDF's "%PDF-" header may legally be preceded by a little junk.
_PDF_HEADER_SEARCH_WINDOW = 1024


def detect_media_type(content: bytes) -> str | None:
    """Returns the media type for the supported formats, else None."""
    if content.startswith(b"\xff\xd8\xff"):
        return JPEG
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return PNG
    if content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return WEBP
    if b"%PDF-" in content[:_PDF_HEADER_SEARCH_WINDOW]:
        return PDF
    return None
