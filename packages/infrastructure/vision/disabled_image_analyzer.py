"""Photo reading switched off: no service reads the photos (owner decision
2026-11-25).

Nothing is sent anywhere and nothing is invented: every call fails as a
provider error, so the upload keeps the file with no analysis, and the chat,
told that photos are off, says honestly that it cannot see them.
"""

from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.shared.errors.base import ProviderError


class PhotoReadingOff(ProviderError):
    """The photo was not read because reading is switched off."""


class DisabledImageAnalyzer(ImageAnalyzer):
    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        raise PhotoReadingOff("photo reading is switched off")
