"""Photo reading switched off (VISION_PROVIDER=off, or a vision model outside
Groq's production list: docs/compliance/19, 2026-11-16).

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
