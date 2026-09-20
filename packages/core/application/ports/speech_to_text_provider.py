from typing import Protocol


class SpeechToTextProvider(Protocol):
    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str: ...
