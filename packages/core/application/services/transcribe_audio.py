from pydantic import BaseModel

from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider


class TranscribeAudioInput(BaseModel):
    audio_bytes: bytes
    filename: str
    content_type: str


class TranscribeAudioOutput(BaseModel):
    text: str


class TranscribeAudioService:
    """Voice dictation (spec: user dictates a question instead of typing
    it) — a standalone utility, not part of ChatOrchestrator: the
    transcribed text is handed back to the client to populate the message
    field, then sent through the normal /chat flow like any typed
    message, rather than being a distinct chat input path of its own.
    """

    def __init__(self, provider: SpeechToTextProvider) -> None:
        self._provider = provider

    def execute(self, data: TranscribeAudioInput) -> TranscribeAudioOutput:
        text = self._provider.transcribe(data.audio_bytes, data.filename, data.content_type)
        return TranscribeAudioOutput(text=text)
