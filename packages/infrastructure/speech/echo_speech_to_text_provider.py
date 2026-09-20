from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider


class EchoSpeechToTextProvider(SpeechToTextProvider):
    """Zero-cost demo/test double — mirrors EchoLLMClient's role for the
    chat LLM: lets the API contract and Flutter integration be exercised
    without a real Groq call or a real audio file.
    """

    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str:
        return f"[demo transcript of {filename}, {len(audio_bytes)} bytes, {content_type}]"
