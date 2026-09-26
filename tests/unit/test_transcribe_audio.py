from packages.core.application.services.transcribe_audio import (
    TranscribeAudioInput,
    TranscribeAudioService,
)
from packages.infrastructure.speech.echo_speech_to_text_provider import (
    EchoSpeechToTextProvider,
)


def test_transcribe_audio_returns_the_providers_text() -> None:
    service = TranscribeAudioService(EchoSpeechToTextProvider())

    result = service.execute(
        TranscribeAudioInput(
            audio_bytes=b"fake-audio-bytes",
            filename="domanda.m4a",
            content_type="audio/m4a",
        )
    )

    assert "domanda.m4a" in result.text
    assert "16 bytes" in result.text
