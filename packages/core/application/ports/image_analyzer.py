from typing import Protocol


class ImageAnalyzer(Protocol):
    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str: ...
