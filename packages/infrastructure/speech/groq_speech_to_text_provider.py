import json
import re
import uuid
from urllib import error, request

from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# Extension by content type, so the part sent upstream carries a name we
# chose rather than whatever the client typed.
_EXTENSIONS = {
    "audio/webm": "webm",
    "audio/ogg": "ogg",
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/x-m4a": "m4a",
    "audio/aac": "aac",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/flac": "flac",
    "video/webm": "webm",
}
_TOKEN = re.compile(r"^[a-z0-9][a-z0-9.+/-]*$")


def safe_multipart_values(filename: str, content_type: str) -> tuple[str, str]:
    """A (filename, content type) pair that cannot break out of a
    multipart header: both are rebuilt from an allowlist, so a value with
    CR/LF or quotes (which would let the client add form fields such as
    `model` or `prompt`) is simply replaced."""
    normalized = content_type.split(";", 1)[0].strip().lower()
    if not _TOKEN.match(normalized) or "\r" in normalized or "\n" in normalized:
        normalized = "application/octet-stream"
    extension = _EXTENSIONS.get(normalized)
    if extension is None:
        suffix = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        extension = suffix if re.fullmatch(r"[a-z0-9]{1,5}", suffix) else "bin"
    return f"audio.{extension}", normalized


class GroqSpeechToTextProvider(SpeechToTextProvider):
    """Groq's OpenAI-compatible Whisper transcription endpoint — the same
    account/base URL family GroqLLMClient already uses for chat
    completions, so voice dictation needs no new vendor relationship or
    API key. Built on stdlib `urllib` (multipart/form-data assembled by
    hand) to match GroqLLMClient's own dependency-free approach, rather
    than adding an HTTP client library for this one call.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str:
        boundary = uuid.uuid4().hex
        body = self._build_multipart_body(boundary, audio_bytes, filename, content_type)
        http_request = request.Request(
            url=f"{self._settings.llm_base_url.rstrip('/')}/audio/transcriptions",
            data=body,
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "Authorization": f"Bearer {self._settings.llm_api_key}",
                # See GroqLLMClient for why: Cloudflare blocks urllib's
                # default user agent outright.
                "User-Agent": "VetApp/1.0",
            },
            method="POST",
        )

        try:
            with request.urlopen(
                http_request, timeout=self._settings.llm_timeout_seconds
            ) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            raise ProviderError(
                f"Groq transcription failed with status {exc.code}: {detail}"
            ) from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Groq API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError("Groq transcription request timed out") from exc

        text = payload.get("text")
        if not isinstance(text, str) or not text.strip():
            raise ProviderError("Groq transcription response did not contain text")
        return text.strip()

    def _build_multipart_body(
        self, boundary: str, audio_bytes: bytes, filename: str, content_type: str
    ) -> bytes:
        filename, content_type = safe_multipart_values(filename, content_type)
        parts: list[bytes] = [
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="model"\r\n\r\n',
            f"{self._settings.stt_model}\r\n".encode(),
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode(),
            f"Content-Type: {content_type}\r\n\r\n".encode(),
            audio_bytes,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
        return b"".join(parts)
