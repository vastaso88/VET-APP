"""Collaudo: dictating silence came back as "Thank you." (a phrase the recogniser invents).
A recording with no speech must give "I heard nothing", never a text, in the five languages.
Everything here uses canned provider answers: no audio, no network."""

from __future__ import annotations

import io
import json
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.transcribe_audio import (
    TranscribeAudioInput,
    TranscribeAudioService,
)
from packages.core.domain.localization import SupportedLocale
from packages.infrastructure.speech import groq_speech_to_text_provider as groq_module
from packages.infrastructure.speech.groq_speech_to_text_provider import GroqSpeechToTextProvider
from packages.infrastructure.speech.transcription_filter import INVENTED_PHRASES, spoken_text
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

LANGUAGES: tuple[SupportedLocale, ...] = ("it", "en", "es", "de", "fr")
INVENTED = {
    "en": "Thank you.",
    "it": "Grazie.",
    "es": "Gracias.",
    "de": "Vielen Dank.",
    "fr": "Merci d'avoir regardé cette vidéo.",
}


def _segment(text: str, **signals: float) -> dict[str, Any]:
    return {"text": f" {text}", "start": 0.0, "end": 1.0, **signals}


# --- the provider's own signals -----------------------------------------------------


def test_silence_that_the_provider_marks_as_no_speech_is_dropped_even_for_a_long_clip() -> None:
    payload = {
        "text": " Thank you.",
        "duration": 12.0,
        "segments": [_segment("Thank you.", no_speech_prob=0.93, avg_logprob=-1.6)],
    }

    assert spoken_text(payload, audio_size=200_000) == ""


def test_real_speech_with_a_low_no_speech_probability_is_kept() -> None:
    payload = {
        "text": " Il mio cane mangia poco da due giorni.",
        "duration": 4.0,
        "segments": [
            _segment(
                "Il mio cane mangia poco da due giorni.", no_speech_prob=0.02, avg_logprob=-0.2
            )
        ],
    }

    assert spoken_text(payload, 60_000) == "Il mio cane mangia poco da due giorni."


def test_only_the_silent_segments_are_dropped_from_a_mixed_recording() -> None:
    payload = {
        "text": "ignored when there are segments",
        "duration": 9.0,
        "segments": [
            _segment("Il gatto vomita.", no_speech_prob=0.05, avg_logprob=-0.3),
            _segment("Thank you.", no_speech_prob=0.9, avg_logprob=-1.4),
        ],
    }

    assert spoken_text(payload, 90_000) == "Il gatto vomita."


def test_a_repetition_loop_is_not_speech() -> None:
    payload = {
        "text": "you you you you",
        "duration": 8.0,
        "segments": [_segment("you you you you", compression_ratio=3.1)],
    }

    assert spoken_text(payload, 100_000) == ""


def test_a_doubtful_probability_alone_does_not_drop_real_words() -> None:
    payload = {
        "text": " Mangia pochissimo",
        "duration": 5.0,
        "segments": [_segment("Mangia pochissimo", no_speech_prob=0.5, avg_logprob=-0.4)],
    }

    assert spoken_text(payload, 70_000) == "Mangia pochissimo"


# --- the filter on typical phrases, only for very short clips --------------------


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_typical_invented_phrase_of_each_language_in_a_very_short_clip_is_silence(
    language: str,
) -> None:
    short_with_duration = {"text": INVENTED[language], "duration": 1.4}
    short_without_duration = {"text": INVENTED[language]}

    assert spoken_text(short_with_duration, audio_size=90_000) == ""
    assert spoken_text(short_without_duration, audio_size=9_000) == ""


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_same_phrase_in_a_long_clip_without_doubt_is_kept(language: str) -> None:
    payload = {"text": INVENTED[language], "duration": 8.0}

    assert spoken_text(payload, audio_size=120_000) == INVENTED[language].strip()


def test_a_phrase_that_is_part_of_a_real_sentence_is_never_filtered() -> None:
    payload = {"text": "Grazie, il cane ha vomitato due volte", "duration": 2.0}

    assert spoken_text(payload, 9_000) == "Grazie, il cane ha vomitato due volte"


def test_nothing_or_blank_is_silence_and_the_phrase_list_is_normalised() -> None:
    assert spoken_text({"text": ""}, 1_000) == ""
    assert spoken_text({"text": "  ...  "}, 1_000) == ""
    assert spoken_text({"segments": []}, 1_000) == ""
    assert all(phrase == phrase.lower() and "." not in phrase for phrase in INVENTED_PHRASES)


# --- the Groq provider, with canned answers ---------------------------------------


class _Response:
    def __init__(self, payload: object) -> None:
        self._raw = json.dumps(payload).encode()

    def __enter__(self) -> _Response:
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        return self._raw


def _provider_answering(
    monkeypatch: pytest.MonkeyPatch, payload: object, sent: list[bytes] | None = None
) -> GroqSpeechToTextProvider:
    def fake_urlopen(http_request: Any, timeout: float) -> _Response:
        if sent is not None:
            sent.append(http_request.data)
        return _Response(payload)

    monkeypatch.setattr(groq_module.request, "urlopen", fake_urlopen)
    return GroqSpeechToTextProvider(Settings(_env_file=None))  # type: ignore[call-arg]


def test_the_provider_asks_for_the_per_segment_signals(monkeypatch: pytest.MonkeyPatch) -> None:
    sent: list[bytes] = []
    provider = _provider_answering(monkeypatch, {"text": "ciao a tutti", "duration": 5.0}, sent)

    provider.transcribe(b"x" * 1000, "chat-voice-message.m4a", "audio/mp4")

    assert b'name="response_format"\r\n\r\nverbose_json\r\n' in sent[0]
    assert b'name="model"' in sent[0] and b'name="file"' in sent[0]


def test_the_provider_returns_empty_for_silence_and_the_words_for_speech(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    silence = {
        "text": " Thank you.",
        "duration": 6.0,
        "segments": [_segment("Thank you.", no_speech_prob=0.95, avg_logprob=-1.8)],
    }
    speech = {
        "text": " Il cane zoppica.",
        "duration": 6.0,
        "segments": [_segment("Il cane zoppica.", no_speech_prob=0.01, avg_logprob=-0.2)],
    }

    assert _provider_answering(monkeypatch, silence).transcribe(b"x", "a.m4a", "audio/mp4") == ""
    assert (
        _provider_answering(monkeypatch, speech).transcribe(b"x", "a.m4a", "audio/mp4")
        == "Il cane zoppica."
    )


def test_a_malformed_provider_answer_is_still_an_error(monkeypatch: pytest.MonkeyPatch) -> None:
    provider = _provider_answering(monkeypatch, {"unexpected": True})

    with pytest.raises(ProviderError):
        provider.transcribe(b"x", "a.m4a", "audio/mp4")


# --- the service and the route ----------------------------------------------------


class _Silent:
    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str:
        return ""


class _Says:
    def transcribe(self, audio_bytes: bytes, filename: str, content_type: str) -> str:
        return "Il cane zoppica"


def _input(language: str) -> TranscribeAudioInput:
    return TranscribeAudioInput(
        audio_bytes=b"audio", filename="a.m4a", content_type="audio/mp4", language=language
    )


def test_silence_gives_i_heard_nothing_in_each_of_the_five_languages() -> None:
    messages = set()
    for language in LANGUAGES:
        result = TranscribeAudioService(_Silent()).execute(_input(language))
        assert result.text == "" and result.heard_nothing is True
        assert result.message
        messages.add(result.message)

    assert len(messages) == 5  # each language has its own sentence
    assert "Non ho sentito nulla" in TranscribeAudioService(_Silent()).execute(_input("it")).message  # type: ignore[operator]


def test_speech_is_returned_as_before() -> None:
    result = TranscribeAudioService(_Says()).execute(_input("it"))

    assert result.model_dump() == {
        "text": "Il cane zoppica",
        "heard_nothing": False,
        "message": None,
    }


@pytest.mark.parametrize("language", LANGUAGES)
def test_the_route_tells_the_owner_in_the_language_of_the_request(
    monkeypatch: pytest.MonkeyPatch, language: str
) -> None:
    monkeypatch.setattr(get_container(), "speech_to_text_provider", _Silent())

    response = TestClient(app).post(
        "/speech-to-text",
        files={"file": ("chat-voice-message.m4a", io.BytesIO(b"x" * 500), "audio/mp4")},
        headers={"Accept-Language": language},
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["text"] == "" and body["heard_nothing"] is True
    assert body["message"] == TranscribeAudioService(_Silent()).execute(_input(language)).message


def test_the_route_still_returns_speech(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_container(), "speech_to_text_provider", _Says())

    response = TestClient(app).post(
        "/speech-to-text",
        files={"file": ("chat-voice-message.m4a", io.BytesIO(b"x" * 500), "audio/mp4")},
    )

    assert response.status_code == 200
    assert (
        response.json()["text"] == "Il cane zoppica" and response.json()["heard_nothing"] is False
    )
